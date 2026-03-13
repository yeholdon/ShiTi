import { BadRequestException, Body, Controller, NotFoundException, Param, Patch, Post, Req, UseGuards } from '@nestjs/common';
import type { Request } from 'express';
import { AuditLogService } from '../../../src/common/audit/audit-log.service';
import { UuidIdParamDto } from '../../../src/common/dto/uuid-id-param.dto';
import { PrismaService } from '../../../src/prisma/prisma.service';
import { requireTenantId, requireTenantRole, requireUserId } from '../../../src/tenant/tenant-guards';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { JoinTenantDto } from './dto/join-tenant.dto';
import { UpdateTenantMemberRoleDto } from './dto/update-tenant-member-role.dto';

@Controller('tenant-members')
@UseGuards(JwtAuthGuard)
export class TenantMembersController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditLogService
  ) {}

  @Post()
  async join(@Req() req: Request, @Body() body: JoinTenantDto) {
    const userId = requireUserId(req);

    const tenant = await this.prisma.tenant.findUnique({ where: { code: body.tenantCode } });
    if (!tenant) throw new NotFoundException('Tenant not found');

    const role = body.role || 'member';
    const existingMembers = await this.prisma.withTenant(tenant.id, (tx) => tx.tenantMember.count({ where: { tenantId: tenant.id } }));
    const currentMembership = await this.prisma.withTenant(tenant.id, (tx) =>
      tx.tenantMember.findUnique({
        where: {
          tenantId_userId: {
            tenantId: tenant.id,
            userId
          }
        }
      })
    );

    if (existingMembers > 0 && role !== 'member') {
      const currentRole = currentMembership?.status === 'active' ? currentMembership.role : null;
      if (currentRole !== 'owner') {
        throw new BadRequestException('Only tenant owners can grant admin or owner roles');
      }
    }

    const membership = await this.prisma.withTenant(tenant.id, (tx) =>
      tx.tenantMember.upsert({
        where: {
          tenantId_userId: {
            tenantId: tenant.id,
            userId
          }
        },
        update: {
          role,
          status: 'active'
        },
        create: {
          tenantId: tenant.id,
          userId,
          role,
          status: 'active'
        }
      })
    );

    await this.audit.record({
      tenantId: tenant.id,
      userId,
      action: 'tenant_member.joined',
      targetType: 'tenant_member',
      targetId: membership.userId,
      details: { role: membership.role }
    });

    return { membership };
  }

  @Patch(':id/role')
  async updateRole(@Req() req: Request, @Param() params: UuidIdParamDto, @Body() body: UpdateTenantMemberRoleDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['owner']);

    const membership = await this.prisma.withTenant(tenantId, (tx) =>
      tx.tenantMember.findUnique({ where: { tenantId_id: { tenantId, id: params.id } } })
    );
    if (!membership) throw new NotFoundException('Tenant member not found');
    if (membership.userId === userId && membership.role === 'owner' && body.role !== 'owner') {
      throw new BadRequestException('Owners cannot demote themselves');
    }

    if (membership.role === 'owner' && body.role !== 'owner') {
      const activeOwners = await this.prisma.withTenant(tenantId, (tx) =>
        tx.tenantMember.count({ where: { tenantId, status: 'active', role: 'owner' } })
      );
      if (activeOwners <= 1) {
        throw new BadRequestException('Cannot demote the last tenant owner');
      }
    }

    const updated = await this.prisma.withTenant(tenantId, (tx) =>
      tx.tenantMember.update({
        where: { tenantId_id: { tenantId, id: params.id } },
        data: { role: body.role }
      })
    );

    await this.audit.record({
      tenantId,
      userId,
      action: 'tenant_member.role_updated',
      targetType: 'tenant_member',
      targetId: updated.id,
      details: {
        targetUserId: updated.userId,
        role: updated.role
      }
    });

    return { membership: updated };
  }
}

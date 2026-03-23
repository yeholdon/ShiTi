import { BadRequestException, Body, Controller, Delete, ForbiddenException, Get, NotFoundException, Param, Patch, Post, Req, UseGuards } from '@nestjs/common';
import type { Request } from 'express';
import { AuditLogService } from '../../../src/common/audit/audit-log.service';
import { UuidIdParamDto } from '../../../src/common/dto/uuid-id-param.dto';
import { PrismaService } from '../../../src/prisma/prisma.service';
import { requireTenantId, requireTenantRole, requireUserId } from '../../../src/tenant/tenant-guards';
import { ensureOrganizationMembershipCapacity } from '../../../src/domain/tenants/organization-membership-limits';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { JoinTenantDto } from './dto/join-tenant.dto';
import { UpdateTenantMemberRoleDto } from './dto/update-tenant-member-role.dto';
import { UpdateTenantMemberStatusDto } from './dto/update-tenant-member-status.dto';

@Controller('tenant-members')
@UseGuards(JwtAuthGuard)
export class TenantMembersController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditLogService
  ) {}

  @Get()
  async list(@Req() req: Request) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    const members = await this.prisma.withTenant(tenantId, (tx) =>
      tx.tenantMember.findMany({
        where: { tenantId },
        include: { user: true },
        orderBy: { createdAt: 'asc' }
      })
    );

    return {
      members: members.map((member) => this.serializeMembership(member))
    };
  }

  @Post()
  async join(@Req() req: Request, @Body() body: JoinTenantDto) {
    const userId = requireUserId(req);

    const tenant = await this.prisma.tenant.findUnique({ where: { code: body.tenantCode } });
    if (!tenant) throw new NotFoundException('Tenant not found');

    const requestedRole = body.role || 'member';
    const requestedStatus = body.status || 'active';
    const requestedUsername = body.username?.trim();
    let targetUserId = userId;
    const existingMembers = await this.prisma.withTenant(tenant.id, (tx) => tx.tenantMember.count({ where: { tenantId: tenant.id } }));
    const actorMembership = await this.prisma.withTenant(tenant.id, (tx) =>
      tx.tenantMember.findUnique({
        where: {
          tenantId_userId: {
            tenantId: tenant.id,
            userId
          }
        }
      })
    );

    if (requestedUsername) {
      const activeActorMembership = await requireTenantRole(this.prisma, tenant.id, userId, ['admin', 'owner']);
      if (requestedRole !== 'member' && activeActorMembership.role !== 'owner') {
        throw new ForbiddenException('Only tenant owners can grant admin or owner roles');
      }

      const targetUser = await this.prisma.user.findUnique({
        where: { username: requestedUsername }
      });
      if (!targetUser) {
        throw new NotFoundException('User not found');
      }
      targetUserId = targetUser.id;
    }

    if (tenant.kind === 'personal') {
      if (!tenant.personalOwnerUserId) {
        throw new BadRequestException('Personal tenant is missing owner');
      }
      if (targetUserId !== tenant.personalOwnerUserId) {
        throw new BadRequestException('Personal workspaces do not support additional members');
      }
    }

    const role = tenant.kind === 'personal' ? 'owner' : requestedRole;
    const finalStatus = tenant.kind === 'personal' ? 'active' : requestedStatus;
    const activatesMembership = finalStatus === 'active';

    const targetMembership =
      targetUserId === userId
        ? actorMembership
        : await this.prisma.withTenant(tenant.id, (tx) =>
            tx.tenantMember.findUnique({
              where: {
                tenantId_userId: {
                  tenantId: tenant.id,
                  userId: targetUserId,
                },
              },
            })
          );

    if (!requestedUsername && existingMembers > 0 && role !== 'member') {
      const currentRole = actorMembership?.status === 'active' ? actorMembership.role : null;
      if (currentRole !== 'owner') {
        throw new BadRequestException('Only tenant owners can grant admin or owner roles');
      }
    }

    if (
      tenant.kind === 'organization' &&
      activatesMembership &&
      targetMembership?.status !== 'active'
    ) {
      await ensureOrganizationMembershipCapacity(this.prisma, targetUserId, tenant.id);
    }

    let membership = null;
    try {
      membership = await this.prisma.withTenant(tenant.id, (tx) =>
        tx.tenantMember.upsert({
          where: {
            tenantId_userId: {
              tenantId: tenant.id,
              userId: targetUserId
            }
          },
          update: {
            role,
            status: requestedUsername ? finalStatus : 'active'
          },
          create: {
            tenantId: tenant.id,
            userId: targetUserId,
            role,
            status: requestedUsername ? finalStatus : 'active'
          },
          include: { user: true }
        })
      );
    } catch (error) {
      membership = await this.prisma.withTenant(tenant.id, (tx) =>
        tx.tenantMember.findUnique({
          where: {
            tenantId_userId: {
              tenantId: tenant.id,
              userId: targetUserId
            }
          },
          include: { user: true }
        })
      );
      if (!membership) {
        throw error;
      }
    }

    await this.audit.record({
      tenantId: tenant.id,
      userId,
      action: 'tenant_member.joined',
      targetType: 'tenant_member',
      targetId: membership.userId,
      details: {
        role: membership.role,
        username: membership.user.username,
        invitedByUserId: requestedUsername ? userId : null,
        status: membership.status
      }
    });

    return {
      membership: this.serializeMembership(membership)
    };
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
        data: { role: body.role },
        include: { user: true }
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

    return {
      membership: this.serializeMembership(updated)
    };
  }

  @Patch(':id/status')
  async updateStatus(@Req() req: Request, @Param() params: UuidIdParamDto, @Body() body: UpdateTenantMemberStatusDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    const actorMembership = await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);
    const tenant = await this.prisma.tenant.findUnique({ where: { id: tenantId } });
    if (!tenant) throw new NotFoundException('Tenant not found');

    const membership = await this.prisma.withTenant(tenantId, (tx) =>
      tx.tenantMember.findUnique({
        where: { tenantId_id: { tenantId, id: params.id } },
        include: { user: true }
      })
    );
    if (!membership) throw new NotFoundException('Tenant member not found');

    if (membership.role !== 'member' && actorMembership.role !== 'owner') {
      throw new ForbiddenException('Only tenant owners can update admin or owner member status');
    }

    if (membership.userId === userId && body.status !== 'active') {
      throw new BadRequestException('Members cannot disable themselves');
    }

    if (membership.role === 'owner' && body.status !== 'active') {
      const activeOwners = await this.prisma.withTenant(tenantId, (tx) =>
        tx.tenantMember.count({ where: { tenantId, status: 'active', role: 'owner' } })
      );
      if (activeOwners <= 1) {
        throw new BadRequestException('Cannot disable the last tenant owner');
      }
    }

    if (
      tenant.kind === 'organization' &&
      body.status === 'active' &&
      membership.status !== 'active'
    ) {
      await ensureOrganizationMembershipCapacity(this.prisma, membership.userId, tenantId);
    }

    const updated = await this.prisma.withTenant(tenantId, (tx) =>
      tx.tenantMember.update({
        where: { tenantId_id: { tenantId, id: params.id } },
        data: { status: body.status },
        include: { user: true }
      })
    );

    await this.audit.record({
      tenantId,
      userId,
      action: 'tenant_member.status_updated',
      targetType: 'tenant_member',
      targetId: updated.id,
      details: {
        targetUserId: updated.userId,
        username: updated.user.username,
        status: updated.status
      }
    });

    return {
      membership: this.serializeMembership(updated)
    };
  }

  @Post(':id/resend-invite')
  async resendInvite(@Req() req: Request, @Param() params: UuidIdParamDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    const actorMembership = await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    const membership = await this.prisma.withTenant(tenantId, (tx) =>
      tx.tenantMember.findUnique({
        where: { tenantId_id: { tenantId, id: params.id } },
        include: { user: true }
      })
    );
    if (!membership) throw new NotFoundException('Tenant member not found');
    if (membership.status !== 'invited') {
      throw new BadRequestException('Only invited tenant members can be resent invitations');
    }
    if (membership.role !== 'member' && actorMembership.role !== 'owner') {
      throw new ForbiddenException('Only tenant owners can resend invitations for admin or owner members');
    }

    const resent = await this.prisma.withTenant(tenantId, (tx) =>
      tx.tenantMember.update({
        where: { tenantId_id: { tenantId, id: params.id } },
        data: { status: 'invited' },
        include: { user: true }
      })
    );

    await this.audit.record({
      tenantId,
      userId,
      action: 'tenant_member.invitation_resent',
      targetType: 'tenant_member',
      targetId: resent.id,
      details: {
        targetUserId: resent.userId,
        username: resent.user.username,
        role: resent.role,
        status: resent.status
      }
    });

    return {
      membership: this.serializeMembership(resent),
      resent: true
    };
  }

  @Delete(':id')
  async remove(@Req() req: Request, @Param() params: UuidIdParamDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    const actorMembership = await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    const membership = await this.prisma.withTenant(tenantId, (tx) =>
      tx.tenantMember.findUnique({
        where: { tenantId_id: { tenantId, id: params.id } },
        include: { user: true }
      })
    );
    if (!membership) throw new NotFoundException('Tenant member not found');

    if (membership.role !== 'member' && actorMembership.role !== 'owner') {
      throw new ForbiddenException('Only tenant owners can remove admin or owner members');
    }

    if (membership.userId === userId) {
      throw new BadRequestException('Members cannot remove themselves');
    }

    if (membership.role === 'owner') {
      const activeOwners = await this.prisma.withTenant(tenantId, (tx) =>
        tx.tenantMember.count({ where: { tenantId, status: 'active', role: 'owner' } })
      );
      if (activeOwners <= 1) {
        throw new BadRequestException('Cannot remove the last tenant owner');
      }
    }

    await this.prisma.withTenant(tenantId, (tx) =>
      tx.tenantMember.delete({
        where: { tenantId_id: { tenantId, id: params.id } }
      })
    );

    await this.audit.record({
      tenantId,
      userId,
      action: 'tenant_member.removed',
      targetType: 'tenant_member',
      targetId: membership.id,
      details: {
        targetUserId: membership.userId,
        username: membership.user.username,
        role: membership.role
      }
    });

    return {
      removed: true,
      membershipId: membership.id
    };
  }

  private serializeMembership(membership: {
    id: string;
    tenantId: string;
    userId: string;
    role: string;
    status: string;
    createdAt: Date;
    updatedAt: Date;
    user: { username: string };
  }) {
    const invitationExpiresAt =
      membership.status === 'invited'
        ? new Date(membership.updatedAt.getTime() + 7 * 24 * 60 * 60 * 1000).toISOString()
        : null;
    return {
      id: membership.id,
      tenantId: membership.tenantId,
      userId: membership.userId,
      username: membership.user.username,
      role: membership.role,
      status: membership.status,
      createdAt: membership.createdAt.toISOString(),
      updatedAt: membership.updatedAt.toISOString(),
      createdAtLabel: membership.createdAt.toISOString().slice(0, 10),
      invitationExpiresAt
    };
  }
}

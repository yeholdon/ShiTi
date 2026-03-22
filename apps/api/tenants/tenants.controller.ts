import { Body, ConflictException, Controller, Get, Headers, Post, Req, UseGuards } from '@nestjs/common';
import type { Request } from 'express';
import { PrismaService } from '../../../src/prisma/prisma.service';
import { requireUserId } from '../../../src/tenant/tenant-guards';
import { ensureDefaultCloudQuestionBank } from '../../../src/domain/questions/question-bank-access';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { OptionalJwtAuthGuard } from '../auth/optional-jwt-auth.guard';
import { CreateTenantDto } from './dto/create-tenant.dto';

@Controller('tenants')
export class TenantsController {
  constructor(private readonly prisma: PrismaService) {}

  @Post()
  @UseGuards(OptionalJwtAuthGuard)
  async createTenant(@Req() req: Request, @Body() body: CreateTenantDto) {
    const userId = await this.resolveCreatorUserId(req, body);
    const existing = await this.prisma.tenant.findUnique({ where: { code: body.code } });
    if (existing) {
      if (!userId) {
        return { tenant: existing };
      }

      const membership = await this.prisma.withTenant(existing.id, (tx) =>
        tx.tenantMember.findUnique({
          where: {
            tenantId_userId: {
              tenantId: existing.id,
              userId,
            },
          },
        })
      );

      if (membership?.status === 'active') {
        return {
          tenant: {
            ...existing,
            role: membership.role,
          },
        };
      }

      const existingMembers = await this.prisma.withTenant(existing.id, (tx) =>
        tx.tenantMember.count({ where: { tenantId: existing.id } })
      );

      if (existingMembers == 0) {
        await this.prisma.withTenant(existing.id, (tx) =>
          tx.tenantMember.create({
            data: {
              tenantId: existing.id,
              userId,
              role: 'owner',
              status: 'active',
            },
          })
        );
        return {
          tenant: {
            ...existing,
            role: 'owner',
          },
        };
      }

      throw new ConflictException('Tenant code already exists');
    }

    const tenant = await this.prisma.tenant.create({
      data: { code: body.code, name: body.name }
    });

    if (!userId) {
      return { tenant };
    }

    await this.prisma.withTenant(tenant.id, (tx) =>
      tx.tenantMember.create({
        data: {
          tenantId: tenant.id,
          userId,
          role: 'owner',
          status: 'active',
        },
      })
    );

    await ensureDefaultCloudQuestionBank(this.prisma, tenant.id, userId);

    return {
      tenant: {
        ...tenant,
        role: 'owner',
      },
    };
  }

  @Get()
  @UseGuards(JwtAuthGuard)
  async listTenants(@Req() req: Request) {
    const userId = requireUserId(req);
    const tenants = await this.prisma.tenant.findMany({
      orderBy: {
        createdAt: 'asc'
      }
    });
    const batchSize = 8;
    const memberships: Array<{
      tenant: (typeof tenants)[number];
      role: string;
    }> = [];

    for (let index = 0; index < tenants.length; index += batchSize) {
      const batch = tenants.slice(index, index + batchSize);
      const resolved = await Promise.all(
        batch.map(async (tenant) => {
          const membership = await this.prisma.withTenant(tenant.id, (tx) =>
            tx.tenantMember.findUnique({
              where: {
                tenantId_userId: {
                  tenantId: tenant.id,
                  userId
                }
              }
            })
          );
          if (!membership || membership.status !== 'active') {
            return null;
          }
          return {
            tenant,
            role: membership.role
          };
        })
      );
      for (const membership of resolved) {
        if (!membership) {
          continue;
        }
        memberships.push(membership);
      }
    }

    return {
      tenants: memberships.map((membership) => ({
        id: membership.tenant.id,
        code: membership.tenant.code,
        name: membership.tenant.name,
        role: membership.role
      }))
    };
  }

  @Get('resolve')
  async resolve(@Headers('x-tenant-code') tenantCode: string) {
    if (!tenantCode) return { tenant: null };
    const tenant = await this.prisma.tenant.findUnique({ where: { code: tenantCode } });
    return { tenant };
  }

  private async resolveCreatorUserId(req: Request, body: CreateTenantDto) {
    const authedUserId = (req as any).auth?.userId as string | undefined;
    if (authedUserId) {
      return authedUserId;
    }

    const creatorUserId = body.creatorUserId?.trim();
    if (creatorUserId) {
      const user = await this.prisma.user.findUnique({
        where: { id: creatorUserId },
        select: { id: true },
      });
      if (user?.id) {
        return user.id;
      }
    }

    const creatorUsername = body.creatorUsername?.trim();
    if (creatorUsername) {
      const user = await this.prisma.user.findUnique({
        where: { username: creatorUsername },
        select: { id: true },
      });
      if (user?.id) {
        return user.id;
      }
    }

    return undefined;
  }
}

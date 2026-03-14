import { Body, Controller, Get, Headers, Post, Req, UseGuards } from '@nestjs/common';
import type { Request } from 'express';
import { PrismaService } from '../../../src/prisma/prisma.service';
import { requireUserId } from '../../../src/tenant/tenant-guards';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreateTenantDto } from './dto/create-tenant.dto';

@Controller('tenants')
export class TenantsController {
  constructor(private readonly prisma: PrismaService) {}

  @Post()
  async createTenant(@Body() body: CreateTenantDto) {
    const existing = await this.prisma.tenant.findUnique({ where: { code: body.code } });
    if (existing) return { tenant: existing };

    const tenant = await this.prisma.tenant.create({
      data: { code: body.code, name: body.name }
    });
    return { tenant };
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
}

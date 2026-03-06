import { BadRequestException, Body, Controller, NotFoundException, Post, Req, UseGuards } from '@nestjs/common';
import type { Request } from 'express';
import { PrismaService } from '../../prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@Controller('tenant-members')
@UseGuards(JwtAuthGuard)
export class TenantMembersController {
  constructor(private readonly prisma: PrismaService) {}

  @Post()
  async join(@Req() req: Request, @Body() body: { tenantCode: string; role?: 'member' | 'admin' | 'owner' }) {
    const tenantCode = (body.tenantCode || '').trim();
    if (!tenantCode) throw new BadRequestException('Missing tenantCode');

    const userId = (req as any).auth?.userId as string | undefined;
    if (!userId) throw new BadRequestException('Missing auth user');

    const tenant = await this.prisma.tenant.findUnique({ where: { code: tenantCode } });
    if (!tenant) throw new NotFoundException('Tenant not found');

    const role = body.role || 'member';

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

    return { membership };
  }
}

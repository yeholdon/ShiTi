import { Body, Controller, Get, Post, Req, UseGuards } from '@nestjs/common';
import type { Request } from 'express';
import { PrismaService } from '../../prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { requireActiveTenantMember, requireTenantId, requireUserId } from '../../tenant/tenant-guards';

@Controller('subjects')
@UseGuards(JwtAuthGuard)
export class SubjectsController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async list(@Req() req: Request) {
    const tenantId = (req as any).tenant?.tenantId as string | null;

    const systemSubjects = await this.prisma.subject.findMany({
      where: { tenantId: null },
      orderBy: { createdAt: 'asc' }
    });

    if (!tenantId) return { subjects: systemSubjects };

    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    const tenantSubjects = await this.prisma.withTenant(tenantId, (tx) =>
      tx.subject.findMany({ where: { tenantId }, orderBy: { createdAt: 'asc' } })
    );

    return { subjects: [...systemSubjects, ...tenantSubjects] };
  }

  @Post()
  async create(@Req() req: Request, @Body() body: { name?: string }) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    const name = (body?.name || '').trim();
    if (!name) throw new Error('Missing name');

    const subject = await this.prisma.withTenant(tenantId, (tx) =>
      tx.subject.create({
        data: {
          tenantId,
          name,
          isSystem: false
        }
      })
    );

    return { subject };
  }
}

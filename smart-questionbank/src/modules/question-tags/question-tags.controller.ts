import { Body, Controller, Delete, Get, NotFoundException, Param, Post, Req, UseGuards } from '@nestjs/common';
import type { Request } from 'express';
import { PrismaService } from '../../prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { requireActiveTenantMember, requireTenantId, requireUserId } from '../../tenant/tenant-guards';

@Controller('question-tags')
@UseGuards(JwtAuthGuard)
export class QuestionTagsController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async list(@Req() req: Request) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    const tags = await this.prisma.withTenant(tenantId, (tx) =>
      tx.questionTag.findMany({ orderBy: { createdAt: 'asc' } })
    );

    return { tags };
  }

  @Post()
  async create(@Req() req: Request, @Body() body: { name?: string }) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    const name = (body?.name || '').trim();
    if (!name) throw new Error('Missing name');

    const tag = await this.prisma.withTenant(tenantId, (tx) =>
      tx.questionTag.create({
        data: {
          tenantId,
          name
        }
      })
    );

    return { tag };
  }

  @Delete(':id')
  async remove(@Req() req: Request, @Param('id') id: string) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    const ok = await this.prisma.withTenant(tenantId, async (tx) => {
      const exists = await tx.questionTag.findUnique({ where: { tenantId_id: { tenantId, id } } });
      if (!exists) return false;

      await tx.questionTag.delete({ where: { tenantId_id: { tenantId, id } } });
      return true;
    });

    if (!ok) throw new NotFoundException('QuestionTag not found');

    return { ok: true };
  }
}

import { Body, Controller, Delete, Get, NotFoundException, Param, Post, Req, UseGuards } from '@nestjs/common';
import type { Request } from 'express';
import { AuditLogService } from '../../common/audit/audit-log.service';
import { PrismaService } from '../../prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { requireActiveTenantMember, requireTenantId, requireTenantRole, requireUserId } from '../../tenant/tenant-guards';
import { CreateQuestionTagDto } from './dto/create-question-tag.dto';

@Controller('question-tags')
@UseGuards(JwtAuthGuard)
export class QuestionTagsController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditLogService
  ) {}

  @Get()
  async list(@Req() req: Request) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    const query = (req as any)?.query || {};
    const offsetRaw = typeof query.offset === 'string' && query.offset.trim() ? Number(query.offset.trim()) : 0;
    const limitRaw = typeof query.limit === 'string' && query.limit.trim() ? Number(query.limit.trim()) : 50;
    const sortByRaw = typeof query.sortBy === 'string' && query.sortBy.trim() ? query.sortBy.trim() : 'createdAt';
    const sortOrderRaw = typeof query.sortOrder === 'string' && query.sortOrder.trim() ? query.sortOrder.trim() : 'asc';
    const offset = Number.isFinite(offsetRaw) ? Math.max(Math.trunc(offsetRaw), 0) : 0;
    const take = Number.isFinite(limitRaw) ? Math.min(Math.max(Math.trunc(limitRaw), 1), 100) : 50;
    const sortBy = ['createdAt', 'name'].includes(sortByRaw) ? sortByRaw : 'createdAt';
    const sortOrder = sortOrderRaw === 'desc' ? 'desc' : 'asc';

    const total = await this.prisma.withTenant(tenantId, (tx) => tx.questionTag.count({ where: { tenantId } }));
    const tags = await this.prisma.withTenant(tenantId, (tx) =>
      tx.questionTag.findMany({
        where: { tenantId },
        skip: offset,
        take,
        orderBy: { [sortBy]: sortOrder }
      })
    );

    return {
      tags,
      meta: {
        limit: take,
        offset,
        returned: tags.length,
        total,
        hasMore: offset + tags.length < total,
        sortBy,
        sortOrder
      }
    };
  }

  @Post()
  async create(@Req() req: Request, @Body() body: CreateQuestionTagDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    const tag = await this.prisma.withTenant(tenantId, (tx) =>
      tx.questionTag.create({
        data: {
          tenantId,
          name: body.name
        }
      })
    );

    await this.audit.record({
      tenantId,
      userId,
      action: 'question_tag.created',
      targetType: 'question_tag',
      targetId: tag.id,
      details: { name: tag.name }
    });

    return { tag };
  }

  @Delete(':id')
  async remove(@Req() req: Request, @Param('id') id: string) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    const ok = await this.prisma.withTenant(tenantId, async (tx) => {
      const exists = await tx.questionTag.findUnique({ where: { tenantId_id: { tenantId, id } } });
      if (!exists) return false;

      await tx.questionTag.delete({ where: { tenantId_id: { tenantId, id } } });
      return true;
    });

    if (!ok) throw new NotFoundException('QuestionTag not found');

    await this.audit.record({
      tenantId,
      userId,
      action: 'question_tag.deleted',
      targetType: 'question_tag',
      targetId: id
    });

    return { ok: true };
  }
}

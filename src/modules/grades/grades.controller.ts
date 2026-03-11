import { Body, Controller, Get, NotFoundException, Post, Query, Req, UseGuards } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import type { Request } from 'express';
import { PrismaService } from '../../prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { requireActiveTenantMember, requireTenantId, requireTenantRole, requireUserId } from '../../tenant/tenant-guards';
import { parseListQuery, sortAndPaginate } from '../taxonomy/list-response';
import { CreateGradeDto } from './dto/create-grade.dto';

@Controller('grades')
@UseGuards(JwtAuthGuard)
export class GradesController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async list(@Req() req: Request, @Query('stageId') stageId?: string) {
    const tenantId = (req as any).tenant?.tenantId as string | null;
    const normalizedStageId = stageId?.trim();
    const query = parseListQuery((req as any)?.query || {}, { sortBy: 'order', sortOrder: 'asc' }, [
      'order',
      'createdAt',
      'code',
      'name'
    ]);

    if (!tenantId) {
      const grades = await this.prisma.grade.findMany({
        where: normalizedStageId ? { tenantId: null, stageId: normalizedStageId } : { tenantId: null }
      });
      const result = sortAndPaginate(grades, query);
      return { grades: result.items, meta: result.meta };
    }

    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    if (normalizedStageId) {
      await this.requireAccessibleStage(tenantId, normalizedStageId);
    }

    const systemGrades = await this.prisma.grade.findMany({
      where: normalizedStageId ? { tenantId: null, stageId: normalizedStageId } : { tenantId: null }
    });

    const tenantGrades = await this.prisma.withTenant(tenantId, (tx) =>
      tx.grade.findMany({
        where: normalizedStageId ? { tenantId, stageId: normalizedStageId } : { tenantId }
      })
    );

    const result = sortAndPaginate([...systemGrades, ...tenantGrades], query);
    return { grades: result.items, meta: result.meta };
  }

  @Post()
  async create(@Req() req: Request, @Body() body: CreateGradeDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    await this.requireAccessibleStage(tenantId, body.stageId);

    const grade = await this.prisma.withTenant(tenantId, (tx) =>
      tx.grade.create({
        data: {
          id: randomUUID(),
          tenantId,
          stageId: body.stageId,
          code: body.code,
          name: body.name,
          order: body.order ?? 0,
          isSystem: false
        }
      })
    );

    return { grade };
  }

  private async requireAccessibleStage(tenantId: string, stageId: string) {
    const systemStage = await this.prisma.stage.findFirst({
      where: { id: stageId, tenantId: null }
    });
    if (systemStage) return systemStage;

    const tenantStage = await this.prisma.withTenant(tenantId, (tx) =>
      tx.stage.findFirst({ where: { id: stageId, tenantId } })
    );
    if (tenantStage) return tenantStage;

    throw new NotFoundException('Stage not found');
  }
}

import { Body, Controller, Get, Post, Req, UseGuards } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import type { Request } from 'express';
import { PrismaService } from '../../../src/prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import {
  requireActiveTenantMember,
  requireTenantId,
  requireTenantRole,
  requireUserId
} from '../../../src/tenant/tenant-guards';
import { parseListQuery, sortAndPaginate } from '../../../src/domain/taxonomy/list-response';
import { CreateStageDto } from './dto/create-stage.dto';

@Controller('stages')
@UseGuards(JwtAuthGuard)
export class StagesController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async list(@Req() req: Request) {
    const tenantId = (req as any).tenant?.tenantId as string | null;
    const query = parseListQuery((req as any)?.query || {}, { sortBy: 'order', sortOrder: 'asc' }, [
      'order',
      'createdAt',
      'code',
      'name'
    ]);

    const systemStages = await this.prisma.stage.findMany({
      where: { tenantId: null }
    });

    if (!tenantId) {
      const result = sortAndPaginate(systemStages, query);
      return { stages: result.items, meta: result.meta };
    }

    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    const tenantStages = await this.prisma.withTenant(tenantId, (tx) =>
      tx.stage.findMany({
        where: { tenantId }
      })
    );

    const result = sortAndPaginate([...systemStages, ...tenantStages], query);
    return { stages: result.items, meta: result.meta };
  }

  @Post()
  async create(@Req() req: Request, @Body() body: CreateStageDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    const stage = await this.prisma.withTenant(tenantId, (tx) =>
      tx.stage.create({
        data: {
          id: randomUUID(),
          tenantId,
          code: body.code,
          name: body.name,
          order: body.order ?? 0,
          isSystem: false
        }
      })
    );

    return { stage };
  }
}

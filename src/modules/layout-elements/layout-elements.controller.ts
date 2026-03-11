import { BadRequestException, Body, Controller, Delete, Get, NotFoundException, Param, Patch, Post, Req, UseGuards } from '@nestjs/common';
import type { Request } from 'express';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { requireActiveTenantMember, requireTenantId, requireTenantRole, requireUserId } from '../../tenant/tenant-guards';
import { UuidIdParamDto } from '../../common/dto/uuid-id-param.dto';
import { validateAssetReferences } from '../assets/asset-reference-validation';
import { UpsertLayoutElementDto } from './dto/upsert-layout-element.dto';

@Controller('layout-elements')
@UseGuards(JwtAuthGuard)
export class LayoutElementsController {
  constructor(private readonly prisma: PrismaService) {}

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
    const sortBy = ['createdAt', 'updatedAt'].includes(sortByRaw) ? sortByRaw : 'createdAt';
    const sortOrder = sortOrderRaw === 'desc' ? 'desc' : 'asc';

    const total = await this.prisma.withTenant(tenantId, (tx) => tx.layoutElement.count({ where: { tenantId } }));
    const layoutElements = await this.prisma.withTenant(tenantId, (tx) =>
      tx.layoutElement.findMany({
        where: { tenantId },
        skip: offset,
        take,
        orderBy: { [sortBy]: sortOrder }
      })
    );

    return {
      layoutElements,
      meta: {
        limit: take,
        offset,
        returned: layoutElements.length,
        total,
        hasMore: offset + layoutElements.length < total,
        sortBy,
        sortOrder
      }
    };
  }

  @Get(':id')
  async getOne(@Req() req: Request, @Param() params: UuidIdParamDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    const layoutElement = await this.prisma.withTenant(tenantId, (tx) =>
      tx.layoutElement.findUnique({ where: { tenantId_id: { tenantId, id: params.id } } })
    );
    if (!layoutElement) throw new NotFoundException('LayoutElement not found');

    return { layoutElement };
  }

  @Post()
  async create(@Req() req: Request, @Body() body: UpsertLayoutElementDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    const blocks = body.blocks as Prisma.InputJsonValue;
    await validateAssetReferences(this.prisma, tenantId, blocks);

    const layoutElement = await this.prisma.withTenant(tenantId, (tx) =>
      tx.layoutElement.create({
        data: {
          tenantId,
          blocks
        }
      })
    );

    return { layoutElement };
  }

  @Patch(':id')
  async update(@Req() req: Request, @Param() params: UuidIdParamDto, @Body() body: UpsertLayoutElementDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    const blocks = body.blocks as Prisma.InputJsonValue;
    await validateAssetReferences(this.prisma, tenantId, blocks);

    const layoutElement = await this.prisma.withTenant(tenantId, async (tx) => {
      const existing = await tx.layoutElement.findUnique({ where: { tenantId_id: { tenantId, id: params.id } } });
      if (!existing) throw new NotFoundException('LayoutElement not found');

      return tx.layoutElement.update({
        where: { tenantId_id: { tenantId, id: params.id } },
        data: { blocks }
      });
    });

    return { layoutElement };
  }

  @Delete(':id')
  async remove(@Req() req: Request, @Param() params: UuidIdParamDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    await this.prisma.withTenant(tenantId, async (tx) => {
      const existing = await tx.layoutElement.findUnique({ where: { tenantId_id: { tenantId, id: params.id } } });
      if (!existing) throw new NotFoundException('LayoutElement not found');

      const inUse = await tx.documentItem.findFirst({ where: { tenantId, layoutElementId: params.id } });
      if (inUse) throw new BadRequestException('LayoutElement is still used by a document');

      await tx.layoutElement.delete({ where: { tenantId_id: { tenantId, id: params.id } } });
    });

    return { ok: true };
  }
}

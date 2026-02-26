import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  NotFoundException,
  Param,
  Patch,
  Post,
  Req,
  UseGuards
} from '@nestjs/common';
import type { Request } from 'express';
import { PrismaService } from '../../prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { requireActiveTenantMember, requireTenantId, requireUserId } from '../../tenant/tenant-guards';

@Controller('documents')
@UseGuards(JwtAuthGuard)
export class DocumentsController {
  constructor(private readonly prisma: PrismaService) {}

  @Post()
  async create(@Req() req: Request, @Body() body: { name?: string; kind?: 'paper' | 'handout' }) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    const name = (body?.name || '').trim();
    if (!name) throw new BadRequestException('Missing name');

    const kind = body.kind || 'paper';

    const document = await this.prisma.withTenant(tenantId, (tx) =>
      tx.document.create({
        data: {
          tenantId,
          kind,
          name,
          createdByUserId: userId
        }
      })
    );

    return { document };
  }

  @Get()
  async list(@Req() req: Request) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    const documents = await this.prisma.withTenant(tenantId, (tx) =>
      tx.document.findMany({ take: 50, orderBy: { createdAt: 'desc' } })
    );

    return { documents };
  }

  @Get(':id')
  async getOne(@Req() req: Request, @Param('id') id: string) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    if (!id) throw new BadRequestException('Missing id');

    const document = await this.prisma.withTenant(tenantId, (tx) =>
      tx.document.findUnique({ where: { tenantId_id: { tenantId, id } } })
    );
    if (!document) throw new NotFoundException('Document not found');

    const items = await this.prisma.withTenant(tenantId, (tx) =>
      tx.documentItem.findMany({ where: { tenantId, documentId: id }, orderBy: { orderIndex: 'asc' } })
    );

    return { document, items };
  }

  @Patch(':id')
  async update(@Req() req: Request, @Param('id') id: string, @Body() body: { name?: string }) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    if (!id) throw new BadRequestException('Missing id');

    const data: any = {};
    if (typeof body?.name === 'string') data.name = body.name.trim();

    const document = await this.prisma.withTenant(tenantId, (tx) =>
      tx.document.update({ where: { tenantId_id: { tenantId, id } }, data })
    );

    return { document };
  }

  @Post(':id/items')
  async addItem(
    @Req() req: Request,
    @Param('id') id: string,
    @Body()
    body: {
      itemType?: 'question' | 'layout_element';
      questionId?: string | null;
      layoutElementId?: string | null;
      scoreOverride?: string | number | null;
    }
  ) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    if (!id) throw new BadRequestException('Missing id');

    const itemType = body?.itemType;
    if (!itemType) throw new BadRequestException('Missing itemType');

    const documentItem = await this.prisma.withTenant(tenantId, async (tx) => {
      const doc = await tx.document.findUnique({ where: { tenantId_id: { tenantId, id } } });
      if (!doc) throw new NotFoundException('Document not found');

      if (itemType === 'question') {
        if (!body.questionId) throw new BadRequestException('Missing questionId');
        const question = await tx.question.findUnique({ where: { tenantId_id: { tenantId, id: body.questionId } } });
        if (!question) throw new BadRequestException('Question not found');
      }

      if (itemType === 'layout_element') {
        if (!body.layoutElementId) throw new BadRequestException('Missing layoutElementId');
        const layout = await tx.layoutElement.findUnique({ where: { tenantId_id: { tenantId, id: body.layoutElementId } } });
        if (!layout) throw new BadRequestException('LayoutElement not found');
      }

      const last = await tx.documentItem.findFirst({
        where: { tenantId, documentId: id },
        orderBy: { orderIndex: 'desc' }
      });
      const orderIndex = (last?.orderIndex ?? -1) + 1;

      return tx.documentItem.create({
        data: {
          tenantId,
          documentId: id,
          orderIndex,
          itemType,
          questionId: itemType === 'question' ? (body.questionId as string) : null,
          layoutElementId: itemType === 'layout_element' ? (body.layoutElementId as string) : null,
          scoreOverride: body?.scoreOverride != null ? (body.scoreOverride as any) : null
        }
      });
    });

    return { item: documentItem };
  }

  @Patch(':id/items/reorder')
  async reorderItems(
    @Req() req: Request,
    @Param('id') id: string,
    @Body() body: { items: { id: string; orderIndex: number }[] }
  ) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    if (!id) throw new BadRequestException('Missing id');
    if (!Array.isArray(body?.items)) throw new BadRequestException('Missing items');

    const items = body.items;
    if (items.some((it) => !it?.id || typeof it.orderIndex !== 'number')) {
      throw new BadRequestException('Invalid items');
    }

    await this.prisma.withTenant(tenantId, async (tx) => {
      const doc = await tx.document.findUnique({ where: { tenantId_id: { tenantId, id } } });
      if (!doc) throw new NotFoundException('Document not found');

      const found = await tx.documentItem.findMany({
        where: { tenantId, documentId: id, id: { in: items.map((i) => i.id) } }
      });

      if (found.length !== items.length) {
        throw new BadRequestException('Some items not found');
      }

      await Promise.all(
        items.map((item) =>
          tx.documentItem.update({
            where: { tenantId_id: { tenantId, id: item.id } },
            data: { orderIndex: item.orderIndex }
          })
        )
      );
    });

    return { ok: true };
  }

  @Delete(':id')
  async remove(@Req() req: Request, @Param('id') id: string) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    if (!id) throw new BadRequestException('Missing id');

    await this.prisma.withTenant(tenantId, (tx) => tx.document.delete({ where: { tenantId_id: { tenantId, id } } }));

    return { ok: true };
  }
}

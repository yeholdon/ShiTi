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
import { AuditLogService } from '../../../src/common/audit/audit-log.service';
import { UuidIdParamDto } from '../../../src/common/dto/uuid-id-param.dto';
import { PrismaService } from '../../../src/prisma/prisma.service';
import { requireActiveTenantMember, requireTenantId, requireTenantRole, requireUserId } from '../../../src/tenant/tenant-guards';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AddDocumentItemDto } from './dto/add-document-item.dto';
import { AddDocumentItemsBulkDto } from './dto/add-document-items-bulk.dto';
import { CreateDocumentDto } from './dto/create-document.dto';
import { DocumentItemParamsDto } from './dto/document-item-params.dto';
import { ReorderDocumentItemsDto } from './dto/reorder-document-items.dto';
import { UpdateDocumentDto } from './dto/update-document.dto';

@Controller('documents')
@UseGuards(JwtAuthGuard)
export class DocumentsController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditLogService
  ) {}

  @Post()
  async create(@Req() req: Request, @Body() body: CreateDocumentDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    const document = await this.prisma.withTenant(tenantId, (tx) =>
      tx.document.create({
        data: {
          tenantId,
          kind: body.kind || 'paper',
          name: body.name,
          createdByUserId: userId
        }
      })
    );

    await this.audit.record({
      tenantId,
      userId,
      action: 'document.created',
      targetType: 'document',
      targetId: document.id,
      details: { kind: document.kind }
    });

    return { document };
  }

  @Get()
  async list(@Req() req: Request) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    const query = (req as any)?.query || {};
    const q = typeof query.q === 'string' && query.q.trim() ? query.q.trim() : undefined;
    const kind = typeof query.kind === 'string' && query.kind.trim() ? query.kind.trim() : undefined;
    const offsetRaw = typeof query.offset === 'string' && query.offset.trim() ? Number(query.offset.trim()) : 0;
    const limitRaw = typeof query.limit === 'string' && query.limit.trim() ? Number(query.limit.trim()) : 50;
    const sortByRaw = typeof query.sortBy === 'string' && query.sortBy.trim() ? query.sortBy.trim() : 'createdAt';
    const sortOrderRaw = typeof query.sortOrder === 'string' && query.sortOrder.trim() ? query.sortOrder.trim() : 'desc';
    const offset = Number.isFinite(offsetRaw) ? Math.max(Math.trunc(offsetRaw), 0) : 0;
    const take = Number.isFinite(limitRaw) ? Math.min(Math.max(Math.trunc(limitRaw), 1), 100) : 50;
    const sortBy = ['createdAt', 'updatedAt', 'name'].includes(sortByRaw) ? sortByRaw : 'createdAt';
    const sortOrder = sortOrderRaw === 'asc' ? 'asc' : 'desc';

    const where: any = { tenantId };
    if (q) where.name = { contains: q, mode: 'insensitive' };
    if (kind) where.kind = kind;

    const total = await this.prisma.withTenant(tenantId, (tx) => tx.document.count({ where }));
    const documents = await this.prisma.withTenant(tenantId, (tx) =>
      tx.document.findMany({
        where,
        skip: offset,
        take,
        orderBy: { [sortBy]: sortOrder }
      })
    );

    const documentsWithStats = await this.attachStats(tenantId, documents);

    return {
      documents: documentsWithStats,
      meta: {
        limit: take,
        offset,
        returned: documentsWithStats.length,
        total,
        hasMore: offset + documentsWithStats.length < total,
        sortBy,
        sortOrder
      }
    };
  }

  @Get(':id')
  async getOne(@Req() req: Request, @Param() params: UuidIdParamDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    const document = await this.prisma.withTenant(tenantId, (tx) =>
      tx.document.findUnique({ where: { tenantId_id: { tenantId, id: params.id } } })
    );
    if (!document) throw new NotFoundException('Document not found');

    const items = await this.prisma.withTenant(tenantId, (tx) =>
      tx.documentItem.findMany({ where: { tenantId, documentId: params.id }, orderBy: { orderIndex: 'asc' } })
    );

    const [documentWithStats] = await this.attachStats(tenantId, [document]);

    return { document: documentWithStats, items };
  }

  @Patch(':id')
  async update(@Req() req: Request, @Param() params: UuidIdParamDto, @Body() body: UpdateDocumentDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    const data: any = {};
    if (typeof body?.name === 'string') data.name = body.name;

    const document = await this.prisma.withTenant(tenantId, (tx) =>
      tx.document.update({ where: { tenantId_id: { tenantId, id: params.id } }, data })
    );

    await this.audit.record({
      tenantId,
      userId,
      action: 'document.updated',
      targetType: 'document',
      targetId: document.id,
      details: { fields: Object.keys(data) }
    });

    return { document };
  }

  @Post(':id/items')
  async addItem(@Req() req: Request, @Param() params: UuidIdParamDto, @Body() body: AddDocumentItemDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);
    const documentItem = await this.addDocumentItemInternal({ tenantId, documentId: params.id, item: body });

    await this.audit.record({
      tenantId,
      userId,
      action: 'document_item.added',
      targetType: 'document',
      targetId: params.id,
      details: { itemType: documentItem.itemType, itemId: documentItem.id }
    });

    return { item: documentItem };
  }

  @Post(':id/items/bulk')
  async addItemsBulk(@Req() req: Request, @Param() params: UuidIdParamDto, @Body() body: AddDocumentItemsBulkDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    const items = [];
    for (const item of body.items) {
      items.push(await this.addDocumentItemInternal({ tenantId, documentId: params.id, item }));
    }

    await this.audit.record({
      tenantId,
      userId,
      action: 'document_items.bulk_added',
      targetType: 'document',
      targetId: params.id,
      details: { count: items.length }
    });

    return { items };
  }

  @Patch(':id/items/reorder')
  async reorderItems(@Req() req: Request, @Param() params: UuidIdParamDto, @Body() body: ReorderDocumentItemsDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    const items = body.items;

    await this.prisma.withTenant(tenantId, async (tx) => {
      const doc = await tx.document.findUnique({ where: { tenantId_id: { tenantId, id: params.id } } });
      if (!doc) throw new NotFoundException('Document not found');

      const found = await tx.documentItem.findMany({
        where: { tenantId, documentId: params.id, id: { in: items.map((i) => i.id) } }
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

    await this.audit.record({
      tenantId,
      userId,
      action: 'document_items.reordered',
      targetType: 'document',
      targetId: params.id,
      details: { count: items.length }
    });

    return { ok: true };
  }

  @Delete(':id/items/:itemId')
  async removeItem(@Req() req: Request, @Param() params: DocumentItemParamsDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    await this.prisma.withTenant(tenantId, async (tx) => {
      const doc = await tx.document.findUnique({ where: { tenantId_id: { tenantId, id: params.id } } });
      if (!doc) throw new NotFoundException('Document not found');

      const item = await tx.documentItem.findUnique({ where: { tenantId_id: { tenantId, id: params.itemId } } });
      if (!item || item.documentId !== params.id) throw new NotFoundException('Document item not found');

      await tx.documentItem.delete({ where: { tenantId_id: { tenantId, id: params.itemId } } });

      const remaining = await tx.documentItem.findMany({
        where: { tenantId, documentId: params.id },
        orderBy: { orderIndex: 'asc' }
      });

      await Promise.all(
        remaining.map((remainingItem, index) =>
          tx.documentItem.update({
            where: { tenantId_id: { tenantId, id: remainingItem.id } },
            data: { orderIndex: index }
          })
        )
      );
    });

    await this.audit.record({
      tenantId,
      userId,
      action: 'document_item.removed',
      targetType: 'document',
      targetId: params.id,
      details: { itemId: params.itemId }
    });

    return { ok: true };
  }

  @Delete(':id')
  async remove(@Req() req: Request, @Param() params: UuidIdParamDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    await this.prisma.withTenant(tenantId, (tx) =>
      tx.document.delete({ where: { tenantId_id: { tenantId, id: params.id } } })
    );

    await this.audit.record({
      tenantId,
      userId,
      action: 'document.deleted',
      targetType: 'document',
      targetId: params.id
    });

    return { ok: true };
  }

  private async attachStats(tenantId: string, documents: any[]) {
    if (documents.length === 0) return documents;

    const documentIds = documents.map((document) => document.id);
    const allItems = await this.prisma.withTenant(tenantId, (tx) =>
      tx.documentItem.findMany({
        where: {
          tenantId,
          documentId: { in: documentIds }
        }
      })
    );
    const questionItems = allItems.filter((item) => item.itemType === 'question' && item.questionId);
    const exportJobs = await this.prisma.withTenant(tenantId, (tx) =>
      tx.exportJob.findMany({
        where: { tenantId, documentId: { in: documentIds } },
        orderBy: [{ createdAt: 'desc' }]
      })
    );
    const items = await this.prisma.withTenant(tenantId, (tx) =>
      tx.documentItem.findMany({
        where: {
          tenantId,
          documentId: { in: documentIds },
          itemType: 'question',
          questionId: { not: null }
        }
      })
    );

    const questionIds = [...new Set(questionItems.map((item) => item.questionId).filter(Boolean))] as string[];
    const questions = questionIds.length
      ? await this.prisma.withTenant(tenantId, (tx) =>
          tx.question.findMany({
            where: { tenantId, id: { in: questionIds } },
            select: { id: true, difficulty: true, type: true }
          })
        )
      : [];

    const questionsById = new Map(questions.map((question) => [question.id, question]));
    const statsByDocumentId = new Map<string, { totalQuestions: number; avgDifficulty: number | null; perTypeCounts: Record<string, number> }>();
    const latestExportJobByDocumentId = new Map<string, any>();
    for (const job of exportJobs) {
      if (!latestExportJobByDocumentId.has(job.documentId)) {
        latestExportJobByDocumentId.set(job.documentId, job);
      }
    }

    for (const document of documents) {
      const currentQuestionItems = items.filter((item) => item.documentId === document.id);
      const currentAllItems = allItems.filter((item) => item.documentId === document.id);
      const perTypeCounts: Record<string, number> = {};
      let difficultySum = 0;
      let difficultyCount = 0;

      for (const item of currentQuestionItems) {
        const question = item.questionId ? questionsById.get(item.questionId) : null;
        if (!question) continue;

        perTypeCounts[question.type] = (perTypeCounts[question.type] || 0) + 1;
        difficultySum += question.difficulty;
        difficultyCount += 1;
      }

      statsByDocumentId.set(document.id, {
        totalQuestions: difficultyCount,
        avgDifficulty: difficultyCount ? Number((difficultySum / difficultyCount).toFixed(2)) : null,
        perTypeCounts
      });

      const layoutCount = currentAllItems.filter((item) => item.itemType === 'layout_element').length;
      const questionCount = currentAllItems.filter((item) => item.itemType === 'question').length;
      const latestExportJob = latestExportJobByDocumentId.get(document.id) || null;

      (document as any).summary = {
        totalItems: currentAllItems.length,
        questionItems: questionCount,
        layoutItems: layoutCount,
        latestExportJob: latestExportJob
          ? {
              id: latestExportJob.id,
              status: latestExportJob.status,
              kind: latestExportJob.kind,
              createdAt: latestExportJob.createdAt
            }
          : null
      };
    }

    return documents.map((document) => ({
      ...document,
      stats:
        statsByDocumentId.get(document.id) || {
          totalQuestions: 0,
          avgDifficulty: null,
          perTypeCounts: {}
        }
    }));
  }

  private async addDocumentItemInternal(args: {
    tenantId: string;
    documentId: string;
    item: AddDocumentItemDto;
  }) {
    const { tenantId, documentId, item } = args;

    return this.prisma.withTenant(tenantId, async (tx) => {
      const doc = await tx.document.findUnique({ where: { tenantId_id: { tenantId, id: documentId } } });
      if (!doc) throw new NotFoundException('Document not found');

      if (item.itemType === 'question') {
        const question = await tx.question.findUnique({
          where: { tenantId_id: { tenantId, id: item.questionId as string } }
        });
        if (!question) throw new BadRequestException('Question not found');
      }

      if (item.itemType === 'layout_element') {
        if (doc.kind === 'paper') {
          throw new BadRequestException('Paper documents cannot include layout elements');
        }
        const layout = await tx.layoutElement.findUnique({
          where: { tenantId_id: { tenantId, id: item.layoutElementId as string } }
        });
        if (!layout) throw new BadRequestException('LayoutElement not found');
      }

      const last = await tx.documentItem.findFirst({
        where: { tenantId, documentId },
        orderBy: { orderIndex: 'desc' }
      });
      const orderIndex = (last?.orderIndex ?? -1) + 1;

      return tx.documentItem.create({
        data: {
          tenantId,
          documentId,
          orderIndex,
          itemType: item.itemType,
          questionId: item.itemType === 'question' ? (item.questionId as string) : null,
          layoutElementId: item.itemType === 'layout_element' ? (item.layoutElementId as string) : null,
          scoreOverride: item.scoreOverride != null ? (item.scoreOverride as any) : null
        }
      });
    });
  }
}

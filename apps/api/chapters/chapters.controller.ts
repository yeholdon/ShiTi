import { BadRequestException, Body, Controller, Get, NotFoundException, Post, Query, Req, UseGuards } from '@nestjs/common';
import type { Request } from 'express';
import { PrismaService } from '../../../src/prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import {
  requireActiveTenantMember,
  requireTenantId,
  requireTenantRole,
  requireUserId
} from '../../../src/tenant/tenant-guards';
import { parseListQuery } from '../../../src/domain/taxonomy/list-response';
import { CreateChapterDto } from './dto/create-chapter.dto';

@Controller('chapters')
@UseGuards(JwtAuthGuard)
export class ChaptersController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async list(@Req() req: Request, @Query('textbookId') textbookId?: string) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);
    const query = parseListQuery((req as any)?.query || {}, { sortBy: 'createdAt', sortOrder: 'asc' }, [
      'createdAt',
      'name'
    ]);

    const normalizedTextbookId = textbookId?.trim();
    if (normalizedTextbookId) {
      await this.requireAccessibleTextbook(tenantId, normalizedTextbookId);
    }

    const where = normalizedTextbookId ? { tenantId, textbookId: normalizedTextbookId } : { tenantId };
    const total = await this.prisma.withTenant(tenantId, (tx) => tx.chapter.count({ where }));
    const chapters = await this.prisma.withTenant(tenantId, (tx) =>
      tx.chapter.findMany({
        where,
        skip: query.offset,
        take: query.take,
        orderBy: { [query.sortBy]: query.sortOrder }
      })
    );

    return {
      chapters,
      meta: {
        limit: query.take,
        offset: query.offset,
        returned: chapters.length,
        total,
        hasMore: query.offset + chapters.length < total,
        sortBy: query.sortBy,
        sortOrder: query.sortOrder
      }
    };
  }

  @Post()
  async create(@Req() req: Request, @Body() body: CreateChapterDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    const parentId = body.parentId ?? null;
    await this.requireAccessibleTextbook(tenantId, body.textbookId);

    if (parentId) {
      const parent = await this.prisma.withTenant(tenantId, (tx) =>
        tx.chapter.findUnique({ where: { tenantId_id: { tenantId, id: parentId } } })
      );
      if (!parent) throw new NotFoundException('Parent chapter not found');
      if (parent.textbookId !== body.textbookId) {
        throw new BadRequestException('Parent chapter must belong to the same textbook');
      }
    }

    const chapter = await this.prisma.withTenant(tenantId, (tx) =>
      tx.chapter.create({
        data: {
          tenantId,
          textbookId: body.textbookId,
          parentId,
          name: body.name
        }
      })
    );

    return { chapter };
  }

  private async requireAccessibleTextbook(tenantId: string, textbookId: string) {
    const systemTextbook = await this.prisma.textbook.findFirst({
      where: { id: textbookId, tenantId: null }
    });
    if (systemTextbook) return systemTextbook;

    const tenantTextbook = await this.prisma.withTenant(tenantId, (tx) =>
      tx.textbook.findFirst({ where: { id: textbookId, tenantId } })
    );
    if (tenantTextbook) return tenantTextbook;

    throw new NotFoundException('Textbook not found');
  }
}

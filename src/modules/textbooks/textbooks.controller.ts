import { Body, Controller, Get, Post, Req, UseGuards } from '@nestjs/common';
import type { Request } from 'express';
import { PrismaService } from '../../prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { requireActiveTenantMember, requireTenantId, requireTenantRole, requireUserId } from '../../tenant/tenant-guards';
import { parseListQuery, sortAndPaginate } from '../taxonomy/list-response';
import { CreateTextbookDto } from './dto/create-textbook.dto';

@Controller('textbooks')
@UseGuards(JwtAuthGuard)
export class TextbooksController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async list(@Req() req: Request) {
    const tenantId = (req as any).tenant?.tenantId as string | null;
    const query = parseListQuery((req as any)?.query || {}, { sortBy: 'createdAt', sortOrder: 'asc' }, [
      'createdAt',
      'name'
    ]);

    const systemTextbooks = await this.prisma.textbook.findMany({
      where: { tenantId: null }
    });

    if (!tenantId) {
      const result = sortAndPaginate(systemTextbooks, query);
      return { textbooks: result.items, meta: result.meta };
    }

    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    const tenantTextbooks = await this.prisma.withTenant(tenantId, (tx) =>
      tx.textbook.findMany({ where: { tenantId } })
    );

    const result = sortAndPaginate([...systemTextbooks, ...tenantTextbooks], query);
    return { textbooks: result.items, meta: result.meta };
  }

  @Post()
  async create(@Req() req: Request, @Body() body: CreateTextbookDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    const textbook = await this.prisma.withTenant(tenantId, (tx) =>
      tx.textbook.create({
        data: {
          tenantId,
          name: body.name,
          isSystem: false
        }
      })
    );

    return { textbook };
  }
}

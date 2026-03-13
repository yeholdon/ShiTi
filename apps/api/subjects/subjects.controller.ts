import { Body, Controller, Get, Post, Req, UseGuards } from '@nestjs/common';
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
import { CreateSubjectDto } from './dto/create-subject.dto';

@Controller('subjects')
@UseGuards(JwtAuthGuard)
export class SubjectsController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async list(@Req() req: Request) {
    const tenantId = (req as any).tenant?.tenantId as string | null;
    const query = parseListQuery((req as any)?.query || {}, { sortBy: 'createdAt', sortOrder: 'asc' }, [
      'createdAt',
      'name'
    ]);

    const systemSubjects = await this.prisma.subject.findMany({
      where: { tenantId: null }
    });

    if (!tenantId) {
      const result = sortAndPaginate(systemSubjects, query);
      return { subjects: result.items, meta: result.meta };
    }

    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    const tenantSubjects = await this.prisma.withTenant(tenantId, (tx) =>
      tx.subject.findMany({ where: { tenantId } })
    );

    const result = sortAndPaginate([...systemSubjects, ...tenantSubjects], query);
    return { subjects: result.items, meta: result.meta };
  }

  @Post()
  async create(@Req() req: Request, @Body() body: CreateSubjectDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    const subject = await this.prisma.withTenant(tenantId, (tx) =>
      tx.subject.create({
        data: {
          tenantId,
          name: body.name,
          isSystem: false
        }
      })
    );

    return { subject };
  }
}

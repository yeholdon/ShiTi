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

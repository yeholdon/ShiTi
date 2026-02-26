import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Inject,
  NotFoundException,
  Param,
  Post,
  Req,
  UseGuards
} from '@nestjs/common';
import type { Request } from 'express';
import { Queue } from 'bullmq';
import { PrismaService } from '../../prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { requireActiveTenantMember, requireTenantId, requireUserId } from '../../tenant/tenant-guards';
import { EXPORT_JOBS_QUEUE, QUEUE_CONNECTION } from '../../queue/queue.constants';

@Controller('export-jobs')
@UseGuards(JwtAuthGuard)
export class ExportJobsController {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(QUEUE_CONNECTION) private readonly connection: any
  ) {}

  @Post()
  async create(@Req() req: Request, @Body() body: { documentId?: string; kind?: 'pdf' }) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    const documentId = (body?.documentId || '').trim();
    if (!documentId) throw new BadRequestException('Missing documentId');

    const kind = body?.kind || 'pdf';
    if (kind !== 'pdf') throw new BadRequestException('Unsupported kind');

    const job = await this.prisma.withTenant(tenantId, async (tx) => {
      const doc = await tx.document.findUnique({ where: { tenantId_id: { tenantId, id: documentId } } });
      if (!doc) throw new BadRequestException('Document not found');

      return tx.exportJob.create({
        data: {
          tenantId,
          kind: 'document_pdf',
          documentId,
          status: 'pending'
        }
      });
    });

    const queue = new Queue(EXPORT_JOBS_QUEUE, { connection: this.connection });
    await queue.add('export', { tenantId, exportJobId: job.id });
    await queue.close();

    return { job };
  }

  @Get(':id')
  async getOne(@Req() req: Request, @Param('id') id: string) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    if (!id) throw new BadRequestException('Missing id');

    const job = await this.prisma.withTenant(tenantId, (tx) =>
      tx.exportJob.findUnique({ where: { tenantId_id: { tenantId, id } } })
    );

    if (!job) throw new NotFoundException('ExportJob not found');

    return { job };
  }
}

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
  Res,
  UseGuards
} from '@nestjs/common';
import type { Request, Response } from 'express';
import { Queue } from 'bullmq';
import * as fs from 'node:fs/promises';
import { Client as MinioClient } from 'minio';
import { PrismaService } from '../../prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { requireActiveTenantMember, requireTenantId, requireUserId } from '../../tenant/tenant-guards';
import { EXPORT_JOBS_QUEUE, QUEUE_CONNECTION } from '../../queue/queue.constants';

function envRequired(name: string): string {
  const v = (process.env[name] || '').trim();
  if (!v) throw new Error(`Missing env var: ${name}`);
  return v;
}

function makeMinioClientFromEnv(): { client: MinioClient; bucket: string } {
  const endPoint = envRequired('MINIO_ENDPOINT');
  const port = Number(process.env.MINIO_PORT || '9000');
  const useSSL = (process.env.MINIO_USE_SSL || 'false') === 'true';
  const accessKey = envRequired('MINIO_ACCESS_KEY');
  const secretKey = envRequired('MINIO_SECRET_KEY');
  const bucket = envRequired('MINIO_BUCKET');

  const client = new MinioClient({ endPoint, port, useSSL, accessKey, secretKey });
  return { client, bucket };
}

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

  @Get(':id/result')
  async getResult(@Req() req: Request, @Res() res: Response, @Param('id') id: string) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    if (!id) throw new BadRequestException('Missing id');

    const job = await this.prisma.withTenant(tenantId, (tx) =>
      tx.exportJob.findUnique({ where: { tenantId_id: { tenantId, id } } })
    );
    if (!job) throw new NotFoundException('ExportJob not found');

    if (job.status !== 'succeeded' || !job.resultAssetId) {
      throw new BadRequestException('Export result not ready');
    }

    const asset = await this.prisma.withTenant(tenantId, (tx) =>
      tx.asset.findUnique({ where: { tenantId_id: { tenantId, id: job.resultAssetId! } } })
    );
    if (!asset) throw new NotFoundException('Asset not found');

    // Worker may store as local file path (fallback) or a MinIO object key.
    if (asset.storageKey.startsWith('/')) {
      const buf = await fs.readFile(asset.storageKey);
      res.setHeader('Content-Type', asset.mime || 'application/pdf');
      res.setHeader('Content-Length', String(buf.length));
      res.status(200).send(buf);
      return;
    }

    const { client, bucket } = makeMinioClientFromEnv();

    try {
      const stream = await client.getObject(bucket, asset.storageKey);
      res.setHeader('Content-Type', asset.mime || 'application/pdf');
      res.status(200);
      stream.on('error', (e) => {
        // If the stream errors mid-flight, there's not much to do besides abort.
        res.destroy(e);
      });
      stream.pipe(res);
    } catch (e: any) {
      throw new BadRequestException(`Failed to fetch export asset: ${String(e?.message || e)}`);
    }
  }
}

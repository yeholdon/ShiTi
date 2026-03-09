import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Inject,
  NotFoundException,
  Param,
  Post,
  Query,
  Req,
  Res,
  ServiceUnavailableException,
  UseGuards
} from '@nestjs/common';
import type { Request, Response } from 'express';
import { Queue } from 'bullmq';
import * as fs from 'node:fs/promises';
import { Client as MinioClient } from 'minio';
import { PrismaService } from '../../prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { requireActiveTenantMember, requireTenantId, requireTenantRole, requireUserId } from '../../tenant/tenant-guards';
import { EXPORT_JOBS_QUEUE, QUEUE_CONNECTION } from '../../queue/queue.constants';
import { UuidIdParamDto } from '../../common/dto/uuid-id-param.dto';
import { AuditLogService } from '../../common/audit/audit-log.service';
import { RateLimit } from '../../common/rate-limit/rate-limit.decorator';
import { RateLimitGuard } from '../../common/rate-limit/rate-limit.guard';
import { hasTestFault } from '../../common/test-faults';
import { CreateExportJobDto } from './dto/create-export-job.dto';
import { CleanupExportJobsDto } from './dto/cleanup-export-jobs.dto';

const EXPORT_JOB_STATUSES = new Set(['pending', 'running', 'succeeded', 'failed', 'canceled']);

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
    @Inject(QUEUE_CONNECTION) private readonly connection: any,
    private readonly audit: AuditLogService
  ) {}

  private async openQueue(req?: Request) {
    if (req && hasTestFault(req, 'queue_unavailable')) {
      throw new Error('test fault: queue unavailable');
    }
    return new Queue(EXPORT_JOBS_QUEUE, { connection: this.connection });
  }

  private async openQueueOrThrow(req: Request, action: string) {
    try {
      return await this.openQueue(req);
    } catch (error: any) {
      throw new ServiceUnavailableException(`Export queue unavailable during ${action}: ${String(error?.message || error)}`);
    }
  }

  private async enqueueExportJob(req: Request, tenantId: string, exportJobId: string) {
    let queue: Queue | undefined;
    try {
      queue = await this.openQueue(req);
      await queue.add('export', { tenantId, exportJobId }, { jobId: exportJobId });
    } catch (error: any) {
      await this.prisma.withTenant(tenantId, (tx) =>
        tx.exportJob.update({
          where: { tenantId_id: { tenantId, id: exportJobId } },
          data: {
            status: 'failed',
            errorMessage: `Queue enqueue failed: ${String(error?.message || error)}`
          }
        })
      );
      throw new ServiceUnavailableException('Export job could not be queued');
    } finally {
      await queue?.close().catch(() => undefined);
    }
  }

  private async deleteExportAsset(asset: {
    storageKey: string;
    mime: string;
  }) {
    if (asset.storageKey.startsWith('/')) {
      await fs.unlink(asset.storageKey).catch(() => undefined);
      return;
    }

    try {
      const { client, bucket } = makeMinioClientFromEnv();
      await client.removeObject(bucket, asset.storageKey);
    } catch {
      // If MinIO is unavailable during cleanup, keep moving and let DB cleanup continue.
    }
  }

  @Post()
  @UseGuards(RateLimitGuard)
  @RateLimit({ limit: 10, windowMs: 60_000, keyPrefix: 'export-create' })
  async create(@Req() req: Request, @Body() body: CreateExportJobDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    const job = await this.prisma.withTenant(tenantId, async (tx) => {
      const doc = await tx.document.findUnique({ where: { tenantId_id: { tenantId, id: body.documentId } } });
      if (!doc) throw new BadRequestException('Document not found');

      return tx.exportJob.create({
        data: {
          tenantId,
          kind: 'document_pdf',
          documentId: body.documentId,
          status: 'pending'
        }
      });
    });

    await this.enqueueExportJob(req, tenantId, job.id);

    await this.audit.record({
      tenantId,
      userId,
      action: 'export_job.created',
      targetType: 'export_job',
      targetId: job.id,
      details: { documentId: body.documentId }
    });

    return { job };
  }

  @Get()
  async list(
    @Req() req: Request,
    @Query('status') status?: string,
    @Query('documentId') documentId?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
    @Query('sortBy') sortBy?: string,
    @Query('sortOrder') sortOrder?: string
  ) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    const normalizedStatus = typeof status === 'string' && status.trim() ? status.trim() : undefined;
    const normalizedDocumentId = typeof documentId === 'string' && documentId.trim() ? documentId.trim() : undefined;
    if (normalizedStatus && !EXPORT_JOB_STATUSES.has(normalizedStatus)) {
      throw new BadRequestException('Invalid status');
    }
    const take = Math.min(Math.max(Number(limit || '20') || 20, 1), 100);
    const skip = Math.max(Number(offset || '0') || 0, 0);
    const normalizedSortBy = sortBy?.trim() === 'updatedAt' ? 'updatedAt' : 'createdAt';
    const normalizedSortOrder = sortOrder?.trim() === 'asc' ? 'asc' : 'desc';

    const [jobs, total] = await this.prisma.withTenant(tenantId, async (tx) =>
      Promise.all([
        tx.exportJob.findMany({
          where: {
            tenantId,
            ...(normalizedStatus ? { status: normalizedStatus as any } : {}),
            ...(normalizedDocumentId ? { documentId: normalizedDocumentId } : {})
          },
          orderBy: { [normalizedSortBy]: normalizedSortOrder },
          take,
          skip
        }),
        tx.exportJob.count({
          where: {
            tenantId,
            ...(normalizedStatus ? { status: normalizedStatus as any } : {}),
            ...(normalizedDocumentId ? { documentId: normalizedDocumentId } : {})
          }
        })
      ])
    );

    return {
      jobs,
      meta: {
        returned: jobs.length,
        total,
        limit: take,
        offset: skip,
        hasMore: skip + jobs.length < total,
        sortBy: normalizedSortBy,
        sortOrder: normalizedSortOrder,
        status: normalizedStatus || null,
        documentId: normalizedDocumentId || null
      }
    };
  }

  @Get(':id')
  async getOne(@Req() req: Request, @Param() params: UuidIdParamDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    const job = await this.prisma.withTenant(tenantId, (tx) =>
      tx.exportJob.findUnique({ where: { tenantId_id: { tenantId, id: params.id } } })
    );

    if (!job) throw new NotFoundException('ExportJob not found');

    return { job };
  }

  @Post(':id/cancel')
  async cancel(@Req() req: Request, @Param() params: UuidIdParamDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    const job = await this.prisma.withTenant(tenantId, (tx) =>
      tx.exportJob.findUnique({ where: { tenantId_id: { tenantId, id: params.id } } })
    );
    if (!job) throw new NotFoundException('ExportJob not found');
    if (job.status === 'succeeded') throw new BadRequestException('Cannot cancel a completed export job');
    if (job.status === 'failed' || job.status === 'canceled') throw new BadRequestException('Export job is not cancelable');
    if (job.status === 'running') throw new BadRequestException('Running export job cannot be canceled');

    const queue = await this.openQueueOrThrow(req, 'cancel');
    try {
      const queueJob = await queue.getJob(job.id);
      if (queueJob) {
        await queueJob.remove();
      }
    } finally {
      await queue.close().catch(() => undefined);
    }

    const canceled = await this.prisma.withTenant(tenantId, (tx) =>
      tx.exportJob.update({
        where: { tenantId_id: { tenantId, id: job.id } },
        data: { status: 'canceled', errorMessage: 'Canceled by user' }
      })
    );

    await this.audit.record({
      tenantId,
      userId,
      action: 'export_job.canceled',
      targetType: 'export_job',
      targetId: job.id
    });

    return { job: canceled };
  }

  @Post(':id/retry')
  async retry(@Req() req: Request, @Param() params: UuidIdParamDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    const job = await this.prisma.withTenant(tenantId, (tx) =>
      tx.exportJob.findUnique({ where: { tenantId_id: { tenantId, id: params.id } } })
    );
    if (!job) throw new NotFoundException('ExportJob not found');
    if (job.status === 'pending' || job.status === 'running') {
      throw new BadRequestException('Export job is already active');
    }
    if (job.status === 'succeeded') {
      throw new BadRequestException('Completed export job does not need retry');
    }

    const retried = await this.prisma.withTenant(tenantId, (tx) =>
      tx.exportJob.update({
        where: { tenantId_id: { tenantId, id: job.id } },
        data: { status: 'pending', errorMessage: null, resultAssetId: null }
      })
    );

    const queue = await this.openQueueOrThrow(req, 'retry');
    try {
      const existingQueueJob = await queue.getJob(job.id);
      if (existingQueueJob) {
        await existingQueueJob.remove();
      }
    } finally {
      await queue.close().catch(() => undefined);
    }

    await this.enqueueExportJob(req, tenantId, job.id);

    await this.audit.record({
      tenantId,
      userId,
      action: 'export_job.retried',
      targetType: 'export_job',
      targetId: job.id
    });

    return { job: retried };
  }

  @Post('cleanup')
  async cleanup(@Req() req: Request, @Body() body: CleanupExportJobsDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['owner']);

    const staleHours = body.staleHours ?? 24;
    const retainHours = body.retainHours ?? 24 * 7;
    const staleBefore = new Date(Date.now() - staleHours * 60 * 60 * 1000);
    const retainBefore = new Date(Date.now() - retainHours * 60 * 60 * 1000);

    const queue = await this.openQueueOrThrow(req, 'cleanup');
    const staleJobs = await this.prisma.withTenant(tenantId, (tx) =>
      tx.exportJob.findMany({
        where: {
          tenantId,
          status: { in: ['pending', 'running'] },
          updatedAt: { lte: staleBefore }
        }
      })
    );

    for (const job of staleJobs) {
      const queueJob = await queue.getJob(job.id);
      if (queueJob) {
        await queueJob.remove().catch(() => undefined);
      }
    }

    const staleResult = staleJobs.length
      ? await this.prisma.withTenant(tenantId, (tx) =>
          tx.exportJob.updateMany({
            where: {
              tenantId,
              id: { in: staleJobs.map((job) => job.id) }
            },
            data: {
              status: 'failed',
              errorMessage: 'Marked stale by cleanup'
            }
          })
        )
      : { count: 0 };

    const expiredJobs = await this.prisma.withTenant(tenantId, (tx) =>
      tx.exportJob.findMany({
        where: {
          tenantId,
          status: { in: ['succeeded', 'failed', 'canceled'] },
          updatedAt: { lte: retainBefore }
        }
      })
    );

    const expiredAssetIds = expiredJobs.map((job) => job.resultAssetId).filter(Boolean) as string[];
    const expiredAssets =
      expiredAssetIds.length > 0
        ? await this.prisma.withTenant(tenantId, (tx) =>
            tx.asset.findMany({
              where: {
                tenantId,
                id: { in: expiredAssetIds }
              }
            })
          )
        : [];

    for (const asset of expiredAssets) {
      await this.deleteExportAsset(asset);
    }

    if (expiredAssets.length > 0) {
      await this.prisma.withTenant(tenantId, (tx) =>
        tx.asset.deleteMany({
          where: {
            tenantId,
            id: { in: expiredAssets.map((asset) => asset.id) }
          }
        })
      );
    }

    const deletedJobs = expiredJobs.length
      ? await this.prisma.withTenant(tenantId, (tx) =>
          tx.exportJob.deleteMany({
            where: {
              tenantId,
              id: { in: expiredJobs.map((job) => job.id) }
            }
          })
        )
      : { count: 0 };

    await queue.close().catch(() => undefined);

    await this.audit.record({
      tenantId,
      userId,
      action: 'export_job.cleanup_run',
      targetType: 'export_job',
      details: {
        staleMarked: staleResult.count,
        deletedJobs: deletedJobs.count,
        deletedAssets: expiredAssets.length,
        staleHours,
        retainHours
      }
    });

    return {
      cleanup: {
        staleMarked: staleResult.count,
        deletedJobs: deletedJobs.count,
        deletedAssets: expiredAssets.length,
        staleHours,
        retainHours
      }
    };
  }

  @Get(':id/result')
  async getResult(@Req() req: Request, @Res() res: Response, @Param() params: UuidIdParamDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    const job = await this.prisma.withTenant(tenantId, (tx) =>
      tx.exportJob.findUnique({ where: { tenantId_id: { tenantId, id: params.id } } })
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
      let buf: Buffer;
      try {
        buf = await fs.readFile(asset.storageKey);
      } catch (e: any) {
        throw new ServiceUnavailableException(`Failed to read export asset: ${String(e?.message || e)}`);
      }
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
      throw new ServiceUnavailableException(`Failed to fetch export asset: ${String(e?.message || e)}`);
    }
  }
}

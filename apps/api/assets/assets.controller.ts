import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  NotFoundException,
  Param,
  Post,
  Req,
  ServiceUnavailableException,
  UseGuards
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import * as fs from 'node:fs/promises';
import { extname } from 'node:path';
import type { Request } from 'express';
import { Client as MinioClient } from 'minio';
import { PrismaService } from '../../../src/prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import {
  requireActiveTenantMember,
  requireTenantId,
  requireTenantRole,
  requireUserId
} from '../../../src/tenant/tenant-guards';
import { UuidIdParamDto } from '../../../src/common/dto/uuid-id-param.dto';
import { AuditLogService } from '../../../src/common/audit/audit-log.service';
import { RateLimit } from '../../../src/common/rate-limit/rate-limit.decorator';
import { RateLimitGuard } from '../../../src/common/rate-limit/rate-limit.guard';
import { valueContainsAssetId } from '../../../src/domain/assets/asset-reference-validation';
import { CleanupAssetsDto } from './dto/cleanup-assets.dto';
import { CreateAssetUploadDto } from './dto/create-asset-upload.dto';

@Controller('assets')
@UseGuards(JwtAuthGuard)
export class AssetsController {
  private readonly minio = new MinioClient({
    endPoint: process.env.MINIO_ENDPOINT || 'localhost',
    port: Number(process.env.MINIO_PORT || 9000),
    useSSL: String(process.env.MINIO_USE_SSL || 'false') === 'true',
    accessKey: process.env.MINIO_ACCESS_KEY || 'minioadmin',
    secretKey: process.env.MINIO_SECRET_KEY || 'minioadmin'
  });

  private readonly bucket = process.env.MINIO_BUCKET || 'questionbank';
  private bucketReady: Promise<void> | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditLogService
  ) {}

  @Get()
  async list(@Req() req: Request) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    const query = (req as any)?.query || {};
    const offsetRaw = typeof query.offset === 'string' && query.offset.trim() ? Number(query.offset.trim()) : 0;
    const limitRaw = typeof query.limit === 'string' && query.limit.trim() ? Number(query.limit.trim()) : 50;
    const sortByRaw = typeof query.sortBy === 'string' && query.sortBy.trim() ? query.sortBy.trim() : 'createdAt';
    const sortOrderRaw = typeof query.sortOrder === 'string' && query.sortOrder.trim() ? query.sortOrder.trim() : 'desc';
    const offset = Number.isFinite(offsetRaw) ? Math.max(Math.trunc(offsetRaw), 0) : 0;
    const take = Number.isFinite(limitRaw) ? Math.min(Math.max(Math.trunc(limitRaw), 1), 100) : 50;
    const sortBy = ['createdAt', 'size', 'kind'].includes(sortByRaw) ? sortByRaw : 'createdAt';
    const sortOrder = sortOrderRaw === 'asc' ? 'asc' : 'desc';

    const total = await this.prisma.withTenant(tenantId, (tx) => tx.asset.count({ where: { tenantId } }));
    const assets = await this.prisma.withTenant(tenantId, (tx) =>
      tx.asset.findMany({
        where: { tenantId },
        skip: offset,
        take,
        orderBy: { [sortBy]: sortOrder }
      })
    );

    return {
      assets,
      meta: {
        limit: take,
        offset,
        returned: assets.length,
        total,
        hasMore: offset + assets.length < total,
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

    const asset = await this.prisma.withTenant(tenantId, (tx) =>
      tx.asset.findUnique({ where: { tenantId_id: { tenantId, id: params.id } } })
    );
    if (!asset) throw new NotFoundException('Asset not found');

    return { asset };
  }

  @Delete(':id')
  async remove(@Req() req: Request, @Param() params: UuidIdParamDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    const asset = await this.prisma.withTenant(tenantId, (tx) =>
      tx.asset.findUnique({ where: { tenantId_id: { tenantId, id: params.id } } })
    );
    if (!asset) throw new NotFoundException('Asset not found');

    const [contents, explanations, choiceAnswers, solutionAnswers, layoutElements, exportJobs] = await this.prisma.withTenant(
      tenantId,
      (tx) =>
        Promise.all([
          tx.questionContent.findMany({ where: { tenantId }, select: { questionId: true, stemBlocks: true } }),
          tx.questionExplanation.findMany({
            where: { tenantId },
            select: { questionId: true, overviewBlocks: true, stepsBlocks: true, commentaryBlocks: true }
          }),
          tx.questionAnswerChoice.findMany({ where: { tenantId }, select: { questionId: true, optionsBlocks: true } }),
          tx.questionAnswerSolution.findMany({
            where: { tenantId },
            select: { questionId: true, referenceAnswerBlocks: true, scoringPointsBlocks: true }
          }),
          tx.layoutElement.findMany({ where: { tenantId }, select: { id: true, blocks: true } }),
          tx.exportJob.findMany({ where: { tenantId, resultAssetId: params.id }, select: { id: true } })
        ])
    );

    const referencedByQuestionContent = contents.find((item) => valueContainsAssetId(item.stemBlocks, params.id));
    if (referencedByQuestionContent) {
      throw new BadRequestException(`Asset is referenced by question content: ${referencedByQuestionContent.questionId}`);
    }

    const referencedByExplanation = explanations.find(
      (item) =>
        valueContainsAssetId(item.overviewBlocks, params.id) ||
        valueContainsAssetId(item.stepsBlocks, params.id) ||
        valueContainsAssetId(item.commentaryBlocks, params.id)
    );
    if (referencedByExplanation) {
      throw new BadRequestException(`Asset is referenced by question explanation: ${referencedByExplanation.questionId}`);
    }

    const referencedByChoiceAnswer = choiceAnswers.find((item) => valueContainsAssetId(item.optionsBlocks, params.id));
    if (referencedByChoiceAnswer) {
      throw new BadRequestException(`Asset is referenced by question choice answer: ${referencedByChoiceAnswer.questionId}`);
    }

    const referencedBySolutionAnswer = solutionAnswers.find(
      (item) =>
        valueContainsAssetId(item.referenceAnswerBlocks, params.id) ||
        valueContainsAssetId(item.scoringPointsBlocks, params.id)
    );
    if (referencedBySolutionAnswer) {
      throw new BadRequestException(`Asset is referenced by question solution answer: ${referencedBySolutionAnswer.questionId}`);
    }

    const referencedByLayout = layoutElements.find((item) => valueContainsAssetId(item.blocks, params.id));
    if (referencedByLayout) {
      throw new BadRequestException(`Asset is referenced by layout element: ${referencedByLayout.id}`);
    }

    if (exportJobs.length > 0) {
      throw new BadRequestException(`Asset is referenced by export job: ${exportJobs[0].id}`);
    }

    await this.ensureBucket();
    await this.minio.removeObject(this.bucket, asset.storageKey);
    await this.prisma.withTenant(tenantId, (tx) =>
      tx.asset.delete({ where: { tenantId_id: { tenantId, id: params.id } } })
    );

    await this.audit.record({
      tenantId,
      userId,
      action: 'asset.deleted',
      targetType: 'asset',
      targetId: params.id
    });

    return { ok: true };
  }

  @Post('cleanup')
  async cleanup(@Req() req: Request, @Body() body: CleanupAssetsDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['owner']);

    const staleHours = body.staleHours ?? 24 * 7;
    const staleBefore = new Date(Date.now() - staleHours * 60 * 60 * 1000);

    const [assets, contents, explanations, choiceAnswers, solutionAnswers, layoutElements, exportJobs] = await this.prisma.withTenant(
      tenantId,
      (tx) =>
        Promise.all([
          tx.asset.findMany({ where: { tenantId, createdAt: { lte: staleBefore } } }),
          tx.questionContent.findMany({ where: { tenantId }, select: { stemBlocks: true } }),
          tx.questionExplanation.findMany({
            where: { tenantId },
            select: { overviewBlocks: true, stepsBlocks: true, commentaryBlocks: true }
          }),
          tx.questionAnswerChoice.findMany({ where: { tenantId }, select: { optionsBlocks: true } }),
          tx.questionAnswerSolution.findMany({
            where: { tenantId },
            select: { referenceAnswerBlocks: true, scoringPointsBlocks: true }
          }),
          tx.layoutElement.findMany({ where: { tenantId }, select: { blocks: true } }),
          tx.exportJob.findMany({ where: { tenantId, resultAssetId: { not: null } }, select: { resultAssetId: true } })
        ])
    );

    const referencedAssetIds = new Set<string>();
    for (const asset of assets) {
      if (exportJobs.some((job) => job.resultAssetId === asset.id)) {
        referencedAssetIds.add(asset.id);
        continue;
      }

      if (contents.some((item) => valueContainsAssetId(item.stemBlocks, asset.id))) {
        referencedAssetIds.add(asset.id);
        continue;
      }

      if (
        explanations.some(
          (item) =>
            valueContainsAssetId(item.overviewBlocks, asset.id) ||
            valueContainsAssetId(item.stepsBlocks, asset.id) ||
            valueContainsAssetId(item.commentaryBlocks, asset.id)
        )
      ) {
        referencedAssetIds.add(asset.id);
        continue;
      }

      if (choiceAnswers.some((item) => valueContainsAssetId(item.optionsBlocks, asset.id))) {
        referencedAssetIds.add(asset.id);
        continue;
      }

      if (
        solutionAnswers.some(
          (item) =>
            valueContainsAssetId(item.referenceAnswerBlocks, asset.id) ||
            valueContainsAssetId(item.scoringPointsBlocks, asset.id)
        )
      ) {
        referencedAssetIds.add(asset.id);
        continue;
      }

      if (layoutElements.some((item) => valueContainsAssetId(item.blocks, asset.id))) {
        referencedAssetIds.add(asset.id);
      }
    }

    const orphanedAssets = assets.filter((asset) => !referencedAssetIds.has(asset.id));
    if (orphanedAssets.length > 0) {
      await this.ensureBucket();
      for (const asset of orphanedAssets) {
        if (asset.storageKey.startsWith('/')) {
          await fs.unlink(asset.storageKey).catch(() => undefined);
        } else {
          await this.minio.removeObject(this.bucket, asset.storageKey).catch(() => undefined);
        }
      }

      await this.prisma.withTenant(tenantId, (tx) =>
        tx.asset.deleteMany({
          where: {
            tenantId,
            id: { in: orphanedAssets.map((asset) => asset.id) }
          }
        })
      );
    }

    await this.audit.record({
      tenantId,
      userId,
      action: 'asset.cleanup_run',
      targetType: 'asset',
      details: {
        staleHours,
        deletedAssets: orphanedAssets.length
      }
    });

    return {
      cleanup: {
        staleHours,
        deletedAssets: orphanedAssets.length
      }
    };
  }

  @Post('upload')
  @UseGuards(RateLimitGuard)
  @RateLimit({ limit: 10, windowMs: 60_000, keyPrefix: 'asset-upload' })
  async createUpload(@Req() req: Request, @Body() body: CreateAssetUploadDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    try {
      await this.ensureBucket();
    } catch (error: any) {
      await this.audit.record({
        tenantId,
        userId,
        action: 'asset.upload_failed',
        targetType: 'asset',
        details: {
          filename: body.filename,
          reason: `bucket_unavailable:${String(error?.message || error)}`
        }
      });
      throw new ServiceUnavailableException('Asset upload is temporarily unavailable');
    }

    const extension = extname(body.filename).toLowerCase();
    const storageKey = `${tenantId}/${Date.now()}-${randomUUID()}${extension}`;

    const asset = await this.prisma.withTenant(tenantId, (tx) =>
      tx.asset.create({
        data: {
          tenantId,
          kind: body.kind || 'image',
          originalFilename: body.filename,
          storageKey,
          mime: body.mime,
          size: body.size,
          width: typeof body.width === 'number' ? body.width : null,
          height: typeof body.height === 'number' ? body.height : null
        }
      })
    );

    let url: string;
    try {
      url = await this.minio.presignedPutObject(this.bucket, storageKey, 60 * 15);
    } catch (error: any) {
      await this.prisma.withTenant(tenantId, (tx) =>
        tx.asset.delete({ where: { tenantId_id: { tenantId, id: asset.id } } }).catch(() => undefined)
      );
      await this.audit.record({
        tenantId,
        userId,
        action: 'asset.upload_failed',
        targetType: 'asset',
        targetId: asset.id,
        details: {
          filename: body.filename,
          reason: `presign_failed:${String(error?.message || error)}`
        }
      });
      throw new ServiceUnavailableException('Asset upload is temporarily unavailable');
    }

    await this.audit.record({
      tenantId,
      userId,
      action: 'asset.upload_created',
      targetType: 'asset',
      targetId: asset.id,
      details: { kind: asset.kind, mime: asset.mime, originalFilename: asset.originalFilename }
    });

    return {
      asset,
      upload: {
        method: 'PUT',
        url
      }
    };
  }

  private async ensureBucket() {
    if (!this.bucketReady) {
      this.bucketReady = (async () => {
        const exists = await this.minio.bucketExists(this.bucket);
        if (!exists) {
          await this.minio.makeBucket(this.bucket);
        }
      })();
    }

    return this.bucketReady;
  }
}

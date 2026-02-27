import { Inject, Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { Worker } from 'bullmq';
import * as fs from 'node:fs/promises';
import * as path from 'node:path';
import PDFDocument from 'pdfkit';
import { Client as MinioClient } from 'minio';
import { PrismaService } from '../../prisma/prisma.service';
import { EXPORT_JOBS_QUEUE, QUEUE_CONNECTION } from '../../queue/queue.constants';

function envRequired(name: string): string {
  const v = (process.env[name] || '').trim();
  if (!v) throw new Error(`Missing env var: ${name}`);
  return v;
}

function blocksToPlainText(blocks: unknown): string {
  if (!Array.isArray(blocks)) return '';

  const parts: string[] = [];

  for (const b of blocks) {
    if (!b || typeof b !== 'object') continue;
    const type = (b as any).type;

    if (typeof (b as any).text === 'string') {
      const t = String((b as any).text).trim();
      if (t) parts.push(t);
      continue;
    }

    if (type === 'option') {
      const key = typeof (b as any).key === 'string' ? String((b as any).key).trim() : '';
      const text = typeof (b as any).text === 'string' ? String((b as any).text).trim() : '';
      const line = `${key ? key + '. ' : ''}${text}`.trim();
      if (line) parts.push(line);
      continue;
    }

    if (type === 'step') {
      const text = typeof (b as any).text === 'string' ? String((b as any).text).trim() : '';
      if (text) parts.push(text);
      continue;
    }

    if (typeof (b as any).latex === 'string') {
      const t = String((b as any).latex).trim();
      if (t) parts.push(t);
      continue;
    }

    if (typeof (b as any).content === 'string') {
      const t = String((b as any).content).trim();
      if (t) parts.push(t);
      continue;
    }
  }

  return parts.join('\n');
}

async function renderDocumentPdf(args: {
  tenantId: string;
  documentId: string;
  prisma: PrismaService;
}): Promise<Buffer> {
  const { tenantId, documentId, prisma } = args;

  const { doc, items } = await prisma.withTenant(tenantId, async (tx) => {
    const doc = await tx.document.findUnique({ where: { tenantId_id: { tenantId, id: documentId } } });
    if (!doc) throw new Error('Document not found');

    const items = await tx.documentItem.findMany({
      where: { tenantId, documentId },
      orderBy: { orderIndex: 'asc' }
    });

    return { doc, items };
  });

  const pdf = new PDFDocument({ size: 'A4', margin: 50 });
  const chunks: Buffer[] = [];

  pdf.on('data', (d) => chunks.push(Buffer.isBuffer(d) ? d : Buffer.from(d)));

  const done = new Promise<Buffer>((resolve, reject) => {
    pdf.on('end', () => resolve(Buffer.concat(chunks)));
    pdf.on('error', reject);
  });

  const marginLeft = pdf.page.margins.left;
  const marginRight = pdf.page.margins.right;
  const marginTop = pdf.page.margins.top;
  const marginBottom = pdf.page.margins.bottom;
  const contentWidth = pdf.page.width - marginLeft - marginRight;

  let pageNo = 1;
  const drawFooter = () => {
    const y = pdf.page.height - marginBottom + 15;
    pdf.save();
    pdf.fontSize(9).fillColor('#888').text(String(pageNo), marginLeft, y, {
      width: contentWidth,
      align: 'center'
    });
    pdf.restore();
  };

  const ensureSpace = (minSpace: number) => {
    const bottomLimit = pdf.page.height - marginBottom;
    if (pdf.y + minSpace <= bottomLimit) return;
    drawFooter();
    pdf.addPage();
    pageNo += 1;
    pdf.y = marginTop;
  };

  pdf.fontSize(18).text(doc.name || 'Untitled Document', { align: 'center' });
  pdf.moveDown(0.25);
  pdf.fontSize(10).fillColor('#666').text(`DocumentId: ${doc.id}`, { align: 'center' });
  pdf.fillColor('#000');
  pdf.moveDown(1);

  let qIndex = 0;
  for (const item of items) {
    if (item.itemType !== 'question' || !item.questionId) continue;

    qIndex += 1;
    ensureSpace(80);

    const q = await prisma.withTenant(tenantId, (tx) =>
      tx.question.findUnique({
        where: { tenantId_id: { tenantId, id: item.questionId! } },
        include: { content: true, choiceAnswer: true }
      })
    );

    if (!q) {
      pdf.fontSize(11).fillColor('#b00').text(`${qIndex}. [Missing question ${item.questionId}]`);
      pdf.fillColor('#000');
      pdf.moveDown(0.75);
      continue;
    }

    pdf.fontSize(12).fillColor('#000').text(`${qIndex}.`, { continued: true });
    pdf.fontSize(12).text(' ');

    const stemText = blocksToPlainText(q.content?.stemBlocks) || '[Empty stem]';
    pdf.fontSize(11).text(stemText, { width: contentWidth });

    const optionsText = blocksToPlainText(q.choiceAnswer?.optionsBlocks);
    if (optionsText) {
      pdf.moveDown(0.35);
      pdf.fontSize(11).text(optionsText, {
        width: contentWidth,
        indent: 12
      });
    }

    pdf.moveDown(0.85);
  }

  drawFooter();
  pdf.end();
  return done;
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

async function ensureBucket(client: MinioClient, bucket: string) {
  const exists = await client.bucketExists(bucket).catch(() => false);
  if (!exists) {
    await client.makeBucket(bucket, 'us-east-1');
  }
}

@Injectable()
export class ExportJobsWorker implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(ExportJobsWorker.name);
  private worker?: Worker;
  private minio?: { client: MinioClient; bucket: string };

  constructor(
    private readonly prisma: PrismaService,
    @Inject(QUEUE_CONNECTION) private readonly connection: any
  ) {}

  async onModuleInit() {
    if (process.env.EXPORT_JOBS_WORKER_ENABLED !== '1') {
      this.logger.log('Worker disabled (set EXPORT_JOBS_WORKER_ENABLED=1 to enable)');
      return;
    }

    try {
      this.minio = makeMinioClientFromEnv();
      await ensureBucket(this.minio.client, this.minio.bucket);
    } catch (e) {
      this.logger.warn(`MinIO init failed; falling back to local export files (${String((e as any)?.message || e)})`);
      this.minio = undefined;
    }

    this.worker = new Worker(
      EXPORT_JOBS_QUEUE,
      async (job) => {
        const { tenantId, exportJobId } = (job.data || {}) as { tenantId?: string; exportJobId?: string };
        if (!tenantId || !exportJobId) throw new Error('Missing tenantId/exportJobId');

        const existing = await this.prisma.withTenant(tenantId, (tx) =>
          tx.exportJob.findUnique({ where: { tenantId_id: { tenantId, id: exportJobId } } })
        );
        if (!existing) throw new Error('ExportJob not found');
        if (existing.status === 'succeeded') return;

        await this.prisma.withTenant(tenantId, (tx) =>
          tx.exportJob.update({
            where: { tenantId_id: { tenantId, id: exportJobId } },
            data: { status: 'running', errorMessage: null }
          })
        );

        const pdf = await renderDocumentPdf({ tenantId, documentId: existing.documentId, prisma: this.prisma });

        let storageKey: string;
        if (this.minio) {
          storageKey = `tenants/${tenantId}/exports/${exportJobId}.pdf`;
          await this.minio.client.putObject(this.minio.bucket, storageKey, pdf, pdf.length, {
            'Content-Type': 'application/pdf'
          });
        } else {
          const dir = path.join('/tmp', 'smart-questionbank', 'exports', tenantId);
          await fs.mkdir(dir, { recursive: true });
          const filePath = path.join(dir, `${exportJobId}.pdf`);
          await fs.writeFile(filePath, pdf);
          storageKey = filePath;
        }

        const asset = await this.prisma.withTenant(tenantId, (tx) =>
          tx.asset.create({
            data: {
              tenantId,
              kind: this.minio ? 'export_document_pdf_minio' : 'export_document_pdf_local',
              storageKey,
              mime: 'application/pdf',
              size: pdf.length
            }
          })
        );

        await this.prisma.withTenant(tenantId, (tx) =>
          tx.exportJob.update({
            where: { tenantId_id: { tenantId, id: exportJobId } },
            data: { status: 'succeeded', resultAssetId: asset.id }
          })
        );
      },
      {
        connection: this.connection,
        concurrency: 2
      }
    );

    this.worker.on('failed', async (job, err) => {
      try {
        const { tenantId, exportJobId } = (job?.data || {}) as { tenantId?: string; exportJobId?: string };
        if (tenantId && exportJobId) {
          await this.prisma.withTenant(tenantId, (tx) =>
            tx.exportJob.update({
              where: { tenantId_id: { tenantId, id: exportJobId } },
              data: { status: 'failed', errorMessage: String(err?.message || err) }
            })
          );
        }
      } catch (e) {
        this.logger.error('Failed to record job error', e);
      }
    });

    this.logger.log('Worker started');
  }

  async onModuleDestroy() {
    if (this.worker) {
      await this.worker.close();
    }
  }
}

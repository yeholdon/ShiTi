import { Inject, Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { Worker } from 'bullmq';
import PDFDocument from 'pdfkit';
import { Client as MinioClient } from 'minio';
import { PrismaService } from '../../prisma/prisma.service';
import { EXPORT_JOBS_QUEUE, QUEUE_CONNECTION } from '../../queue/queue.constants';

function envRequired(name: string): string {
  const v = (process.env[name] || '').trim();
  if (!v) throw new Error(`Missing env var: ${name}`);
  return v;
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

  pdf.fontSize(20).text(doc.name || 'Untitled Document', { align: 'left' });
  pdf.moveDown(0.5);
  pdf.fontSize(10).fillColor('#666').text(`DocumentId: ${doc.id}`);
  pdf.fillColor('#000');
  pdf.moveDown(1);

  for (let idx = 0; idx < items.length; idx++) {
    const item = items[idx];
    pdf.fontSize(12).text(`${idx + 1}. ${item.itemType}`);

    if (item.itemType === 'question' && item.questionId) {
      const q = await prisma.withTenant(tenantId, (tx) =>
        tx.question.findUnique({
          where: { tenantId_id: { tenantId, id: item.questionId! } },
          include: { content: true }
        })
      );

      if (q) {
        pdf.fontSize(10).fillColor('#333').text(`QuestionId: ${q.id}`);
        pdf.fillColor('#000');
        if (q.content) {
          pdf.fontSize(10).text(`Stem: ${JSON.stringify(q.content.stemBlocks)}`);
        }
      } else {
        pdf.fontSize(10).fillColor('#b00').text(`Missing question: ${item.questionId}`);
        pdf.fillColor('#000');
      }
    }

    pdf.moveDown(0.75);

    if (pdf.y > pdf.page.height - 80) pdf.addPage();
  }

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

    this.minio = makeMinioClientFromEnv();
    await ensureBucket(this.minio.client, this.minio.bucket);

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

        if (!this.minio) throw new Error('MinIO client not initialized');

        const pdf = await renderDocumentPdf({ tenantId, documentId: existing.documentId, prisma: this.prisma });

        const key = `tenants/${tenantId}/exports/${exportJobId}.pdf`;
        await this.minio.client.putObject(this.minio.bucket, key, pdf, pdf.length, {
          'Content-Type': 'application/pdf'
        });

        const asset = await this.prisma.withTenant(tenantId, (tx) =>
          tx.asset.create({
            data: {
              tenantId,
              kind: 'export_document_pdf',
              storageKey: key,
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

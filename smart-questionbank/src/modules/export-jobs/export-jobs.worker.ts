import { Inject, Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { Worker } from 'bullmq';
import { PrismaService } from '../../prisma/prisma.service';
import { EXPORT_JOBS_QUEUE, QUEUE_CONNECTION } from '../../queue/queue.constants';

@Injectable()
export class ExportJobsWorker implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(ExportJobsWorker.name);
  private worker?: Worker;

  constructor(
    private readonly prisma: PrismaService,
    @Inject(QUEUE_CONNECTION) private readonly connection: any
  ) {}

  onModuleInit() {
    if (process.env.EXPORT_JOBS_WORKER_ENABLED !== '1') {
      this.logger.log('Worker disabled (set EXPORT_JOBS_WORKER_ENABLED=1 to enable)');
      return;
    }

    this.worker = new Worker(
      EXPORT_JOBS_QUEUE,
      async (job) => {
        const { tenantId, exportJobId } = (job.data || {}) as { tenantId?: string; exportJobId?: string };
        if (!tenantId || !exportJobId) throw new Error('Missing tenantId/exportJobId');

        await this.prisma.withTenant(tenantId, async (tx) => {
          const existing = await tx.exportJob.findUnique({ where: { tenantId_id: { tenantId, id: exportJobId } } });
          if (!existing) throw new Error('ExportJob not found');

          if (existing.status === 'succeeded') return;

          await tx.exportJob.update({
            where: { tenantId_id: { tenantId, id: exportJobId } },
            data: { status: 'running', errorMessage: null }
          });

          // TODO: real export pipeline. For now: stub succeed.
          await tx.exportJob.update({
            where: { tenantId_id: { tenantId, id: exportJobId } },
            data: { status: 'succeeded' }
          });
        });
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

import { Module } from '@nestjs/common';
import { PrismaModule } from '../../src/prisma/prisma.module';
import { QueueModule } from '../../src/queue/queue.module';
import { ExportJobsWorker } from '../../src/domain/export-jobs/export-jobs.worker';

@Module({
  imports: [PrismaModule, QueueModule],
  providers: [ExportJobsWorker]
})
export class ExportJobsWorkerModule {}

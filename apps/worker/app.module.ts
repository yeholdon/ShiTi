import { Module } from '@nestjs/common';
import { PrismaModule } from '../../src/prisma/prisma.module';
import { QueueModule } from '../../src/queue/queue.module';
import { ExportJobsWorkerModule } from './export-jobs-worker.module';

@Module({
  imports: [PrismaModule, QueueModule, ExportJobsWorkerModule]
})
export class WorkerAppModule {}

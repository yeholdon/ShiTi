import { Module } from '@nestjs/common';
import { PrismaModule } from '../../prisma/prisma.module';
import { QueueModule } from '../../queue/queue.module';
import { ExportJobsController } from './export-jobs.controller';
import { ExportJobsWorker } from './export-jobs.worker';

@Module({
  imports: [PrismaModule, QueueModule],
  controllers: [ExportJobsController],
  providers: [ExportJobsWorker]
})
export class ExportJobsModule {}

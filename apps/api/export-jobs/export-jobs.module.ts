import { Module } from '@nestjs/common';
import { PrismaModule } from '../../../src/prisma/prisma.module';
import { QueueModule } from '../../../src/queue/queue.module';
import { ExportJobsController } from './export-jobs.controller';

@Module({
  imports: [PrismaModule, QueueModule],
  controllers: [ExportJobsController]
})
export class ExportJobsModule {}

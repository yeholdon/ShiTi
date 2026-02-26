import { Module } from '@nestjs/common';
import { PrismaModule } from '../../prisma/prisma.module';
import { ExportJobsController } from './export-jobs.controller';

@Module({
  imports: [PrismaModule],
  controllers: [ExportJobsController]
})
export class ExportJobsModule {}

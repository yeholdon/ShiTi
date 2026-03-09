import { Global, Module } from '@nestjs/common';
import { PrismaModule } from '../../prisma/prisma.module';
import { AuditLogsController } from './audit-logs.controller';
import { AuditLogService } from './audit-log.service';

@Global()
@Module({
  imports: [PrismaModule],
  controllers: [AuditLogsController],
  providers: [AuditLogService],
  exports: [AuditLogService]
})
export class AuditModule {}

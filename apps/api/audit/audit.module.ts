import { Global, Module } from '@nestjs/common';
import { PrismaModule } from '../../../src/prisma/prisma.module';
import { AuditLogService } from '../../../src/common/audit/audit-log.service';
import { AuditLogsController } from './audit-logs.controller';

@Global()
@Module({
  imports: [PrismaModule],
  controllers: [AuditLogsController],
  providers: [AuditLogService],
  exports: [AuditLogService]
})
export class AuditModule {}

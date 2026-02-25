import { Module } from '@nestjs/common';
import { TenantMembersController } from './tenant-members.controller';

@Module({
  controllers: [TenantMembersController]
})
export class TenantMembersModule {}

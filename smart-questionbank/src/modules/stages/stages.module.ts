import { Module } from '@nestjs/common';
import { StagesController } from './stages.controller';

@Module({
  controllers: [StagesController]
})
export class StagesModule {}

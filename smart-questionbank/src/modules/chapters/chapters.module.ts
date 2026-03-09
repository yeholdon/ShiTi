import { Module } from '@nestjs/common';
import { ChaptersController } from './chapters.controller';

@Module({
  controllers: [ChaptersController]
})
export class ChaptersModule {}

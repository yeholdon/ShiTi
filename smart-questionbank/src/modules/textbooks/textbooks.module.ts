import { Module } from '@nestjs/common';
import { TextbooksController } from './textbooks.controller';

@Module({
  controllers: [TextbooksController]
})
export class TextbooksModule {}

import { Module } from '@nestjs/common';
import { PrismaModule } from '../../../src/prisma/prisma.module';
import { QuestionTagsController } from './question-tags.controller';

@Module({
  imports: [PrismaModule],
  controllers: [QuestionTagsController]
})
export class QuestionTagsModule {}

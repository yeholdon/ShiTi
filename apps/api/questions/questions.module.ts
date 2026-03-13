import { Module } from '@nestjs/common';
import { QuestionsController } from './questions.controller';
import { QuestionsImportService } from '../../../src/domain/questions/questions-import.service';

@Module({
  controllers: [QuestionsController],
  providers: [QuestionsImportService],
  exports: [QuestionsImportService]
})
export class QuestionsModule {}

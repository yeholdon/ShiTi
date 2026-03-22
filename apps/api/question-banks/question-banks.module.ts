import { Module } from '@nestjs/common';
import { QuestionBanksController } from './question-banks.controller';

@Module({
  controllers: [QuestionBanksController],
})
export class QuestionBanksModule {}

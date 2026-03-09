import { IsDefined } from 'class-validator';

export class UpsertQuestionChoiceAnswerDto {
  @IsDefined({ message: 'Missing optionsBlocks' })
  optionsBlocks!: unknown;

  @IsDefined({ message: 'Missing correct' })
  correct!: unknown;
}

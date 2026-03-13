import { IsDefined } from 'class-validator';

export class UpsertQuestionBlankAnswerDto {
  @IsDefined({ message: 'Missing blanks' })
  blanks!: unknown;
}

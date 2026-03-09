import { IsDefined } from 'class-validator';

export class UpsertQuestionContentDto {
  @IsDefined({ message: 'Missing stemBlocks' })
  stemBlocks!: unknown;
}

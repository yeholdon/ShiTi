import { IsDefined, IsOptional, IsString } from 'class-validator';

export class UpsertQuestionSolutionAnswerDto {
  @IsOptional()
  @IsString({ message: 'Invalid finalAnswerLatex' })
  finalAnswerLatex?: string | null;

  @IsOptional()
  referenceAnswerBlocks?: unknown;

  @IsDefined({ message: 'Missing scoringPoints' })
  scoringPoints!: unknown;

  @IsOptional()
  scoringPointsBlocks?: unknown;
}

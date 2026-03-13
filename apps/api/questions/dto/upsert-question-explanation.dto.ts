import { IsDefined, IsOptional, IsString } from 'class-validator';

export class UpsertQuestionExplanationDto {
  @IsOptional()
  @IsString({ message: 'Invalid overviewLatex' })
  overviewLatex?: string | null;

  @IsOptional()
  overviewBlocks?: unknown;

  @IsDefined({ message: 'Missing stepsBlocks' })
  stepsBlocks!: unknown;

  @IsOptional()
  @IsString({ message: 'Invalid commentaryLatex' })
  commentaryLatex?: string | null;

  @IsOptional()
  commentaryBlocks?: unknown;
}

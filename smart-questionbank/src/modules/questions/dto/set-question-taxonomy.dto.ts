import { IsArray, IsOptional, IsString } from 'class-validator';

export class SetQuestionTaxonomyDto {
  @IsOptional()
  @IsArray({ message: 'Invalid stageIds' })
  @IsString({ each: true, message: 'Invalid stageIds' })
  stageIds?: string[];

  @IsOptional()
  @IsArray({ message: 'Invalid gradeIds' })
  @IsString({ each: true, message: 'Invalid gradeIds' })
  gradeIds?: string[];

  @IsOptional()
  @IsArray({ message: 'Invalid textbookIds' })
  @IsString({ each: true, message: 'Invalid textbookIds' })
  textbookIds?: string[];

  @IsOptional()
  @IsArray({ message: 'Invalid chapterIds' })
  @IsString({ each: true, message: 'Invalid chapterIds' })
  chapterIds?: string[];
}

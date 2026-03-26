import { IsArray, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateClassDto {
  @IsString({ message: 'Missing name' })
  @IsNotEmpty({ message: 'Missing name' })
  name!: string;

  @IsString({ message: 'Missing stageLabel' })
  @IsNotEmpty({ message: 'Missing stageLabel' })
  stageLabel!: string;

  @IsString({ message: 'Missing teacherLabel' })
  @IsNotEmpty({ message: 'Missing teacherLabel' })
  teacherLabel!: string;

  @IsString({ message: 'Missing textbookLabel' })
  @IsNotEmpty({ message: 'Missing textbookLabel' })
  textbookLabel!: string;

  @IsOptional()
  @IsString({ message: 'Invalid focusLabel' })
  focusLabel?: string;

  @IsOptional()
  @IsString({ message: 'Invalid focusStudentId' })
  focusStudentId?: string;

  @IsOptional()
  @IsString({ message: 'Invalid focusStudentName' })
  focusStudentName?: string;

  @IsOptional()
  @IsString({ message: 'Invalid lessonId' })
  lessonId?: string;

  @IsOptional()
  @IsString({ message: 'Invalid lessonFocusLabel' })
  lessonFocusLabel?: string;

  @IsOptional()
  @IsString({ message: 'Invalid documentId' })
  documentId?: string;

  @IsOptional()
  @IsString({ message: 'Invalid latestDocLabel' })
  latestDocLabel?: string;

  @IsOptional()
  @IsArray({ message: 'Invalid memberStudentIds' })
  @IsString({ each: true, message: 'Invalid memberStudentIds' })
  memberStudentIds?: string[];
}

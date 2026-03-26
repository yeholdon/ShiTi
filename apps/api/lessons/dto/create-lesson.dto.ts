import { IsArray, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateLessonDto {
  @IsString({ message: 'Missing title' })
  @IsNotEmpty({ message: 'Missing title' })
  title!: string;

  @IsString({ message: 'Missing teacherLabel' })
  @IsNotEmpty({ message: 'Missing teacherLabel' })
  teacherLabel!: string;

  @IsString({ message: 'Missing scheduleLabel' })
  @IsNotEmpty({ message: 'Missing scheduleLabel' })
  scheduleLabel!: string;

  @IsOptional()
  @IsString({ message: 'Invalid classScopeLabel' })
  classScopeLabel?: string;

  @IsOptional()
  @IsString({ message: 'Invalid focusStudentId' })
  focusStudentId?: string;

  @IsOptional()
  @IsString({ message: 'Invalid focusStudentName' })
  focusStudentName?: string;

  @IsOptional()
  @IsString({ message: 'Invalid classId' })
  classId?: string;

  @IsOptional()
  @IsString({ message: 'Invalid documentId' })
  documentId?: string;

  @IsOptional()
  @IsString({ message: 'Invalid documentFocus' })
  documentFocus?: string;

  @IsOptional()
  @IsArray({ message: 'Invalid feedbackStudentIds' })
  @IsString({ each: true, message: 'Invalid feedbackStudentIds' })
  feedbackStudentIds?: string[];
}

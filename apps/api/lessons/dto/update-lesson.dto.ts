import { IsOptional, IsString } from 'class-validator';

export class UpdateLessonDto {
  @IsOptional()
  @IsString({ message: 'Invalid title' })
  title?: string;

  @IsOptional()
  @IsString({ message: 'Invalid teacherLabel' })
  teacherLabel?: string;

  @IsOptional()
  @IsString({ message: 'Invalid scheduleLabel' })
  scheduleLabel?: string;

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
}

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
}

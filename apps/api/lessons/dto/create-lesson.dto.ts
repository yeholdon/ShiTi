import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

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
}

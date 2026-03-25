import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

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
}

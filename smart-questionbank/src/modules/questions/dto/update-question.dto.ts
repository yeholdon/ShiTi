import { Transform, Type } from 'class-transformer';
import { IsIn, IsInt, IsNotEmpty, IsOptional, IsString, IsUUID, Max, Min } from 'class-validator';

export class UpdateQuestionDto {
  @IsOptional()
  @IsString({ message: 'Invalid type' })
  @IsIn(['single_choice', 'fill_blank', 'solution'], { message: 'Invalid type' })
  type?: 'single_choice' | 'fill_blank' | 'solution';

  @IsOptional()
  @Type(() => Number)
  @IsInt({ message: 'Invalid difficulty' })
  @Min(1, { message: 'Invalid difficulty' })
  @Max(5, { message: 'Invalid difficulty' })
  difficulty?: number;

  @IsOptional()
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString({ message: 'Invalid defaultScore' })
  @IsNotEmpty({ message: 'Invalid defaultScore' })
  defaultScore?: string;

  @IsOptional()
  @Transform(({ value }) => {
    if (typeof value !== 'string') return value;
    const normalized = value.trim();
    return normalized || undefined;
  })
  @IsUUID('4', { message: 'Invalid subjectId' })
  subjectId?: string;

  @IsOptional()
  @IsString({ message: 'Invalid visibility' })
  @IsIn(['private', 'tenant_shared'], { message: 'Invalid visibility' })
  visibility?: 'private' | 'tenant_shared';
}

import { Transform, Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

export class UpsertQuestionSourceDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt({ message: 'Invalid year' })
  year?: number | null;

  @IsOptional()
  @Type(() => Number)
  @IsInt({ message: 'Invalid month' })
  @Min(1, { message: 'Invalid month' })
  @Max(12, { message: 'Invalid month' })
  month?: number | null;

  @IsOptional()
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString({ message: 'Invalid sourceText' })
  sourceText?: string | null;
}

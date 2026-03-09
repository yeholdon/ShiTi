import { Transform, Type } from 'class-transformer';
import { IsNotEmpty, IsNumber, IsOptional, IsString, Min } from 'class-validator';

export class CreateAssetUploadDto {
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString({ message: 'Missing filename' })
  @IsNotEmpty({ message: 'Missing filename' })
  filename!: string;

  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString({ message: 'Missing mime' })
  @IsNotEmpty({ message: 'Missing mime' })
  mime!: string;

  @Type(() => Number)
  @IsNumber({}, { message: 'Invalid size' })
  @Min(1, { message: 'Invalid size' })
  size!: number;

  @IsOptional()
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString({ message: 'Invalid kind' })
  @IsNotEmpty({ message: 'Invalid kind' })
  kind?: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber({}, { message: 'Invalid width' })
  @Min(1, { message: 'Invalid width' })
  width?: number | null;

  @IsOptional()
  @Type(() => Number)
  @IsNumber({}, { message: 'Invalid height' })
  @Min(1, { message: 'Invalid height' })
  height?: number | null;
}

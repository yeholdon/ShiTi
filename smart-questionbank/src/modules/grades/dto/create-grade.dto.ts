import { Transform } from 'class-transformer';
import { IsDefined, IsInt, IsNotEmpty, IsOptional, IsString, IsUUID } from 'class-validator';

export class CreateGradeDto {
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsDefined({ message: 'Missing stageId' })
  @IsUUID('4', { message: 'Invalid stageId' })
  stageId!: string;

  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString({ message: 'Missing code' })
  @IsNotEmpty({ message: 'Missing code' })
  code!: string;

  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString({ message: 'Missing name' })
  @IsNotEmpty({ message: 'Missing name' })
  name!: string;

  @IsOptional()
  @IsInt({ message: 'Invalid order' })
  order?: number;
}

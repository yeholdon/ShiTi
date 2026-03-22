import { Transform } from 'class-transformer';
import { IsIn, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateQuestionBankDto {
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString({ message: 'Missing name' })
  @IsNotEmpty({ message: 'Missing name' })
  name!: string;

  @IsOptional()
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString({ message: 'Invalid description' })
  description?: string;

  @IsOptional()
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsIn(['cloud', 'local'], { message: 'Invalid storageMode' })
  storageMode?: 'cloud' | 'local';
}

import { Transform } from 'class-transformer';
import { ArrayMaxSize, ArrayNotEmpty, IsArray, IsBoolean, IsDefined, IsOptional, IsUUID, ValidateIf } from 'class-validator';

export class ImportQuestionsDto {
  @IsOptional()
  @Transform(({ value }) => {
    if (typeof value !== 'string') return value;
    const normalized = value.trim();
    return normalized || undefined;
  })
  @IsUUID('4', { message: 'Invalid questionBankId' })
  questionBankId?: string;

  @IsOptional()
  @Transform(({ value }) => (typeof value === 'boolean' ? value : value === 'true'))
  @IsBoolean({ message: 'Invalid dryRun' })
  dryRun?: boolean;

  @IsDefined({ message: 'Missing items' })
  @IsArray({ message: 'Missing items' })
  @ValidateIf((_, value) => Array.isArray(value))
  @ArrayNotEmpty({ message: 'Missing items' })
  @ValidateIf((_, value) => Array.isArray(value))
  @ArrayMaxSize(200, { message: 'Too many items (max 200)' })
  items!: any[];
}

import { Transform } from 'class-transformer';
import { IsDefined, IsNotEmpty, IsOptional, IsString, IsUUID } from 'class-validator';

export class CreateChapterDto {
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsDefined({ message: 'Missing textbookId' })
  @IsUUID('4', { message: 'Invalid textbookId' })
  textbookId!: string;

  @Transform(({ value }) => {
    if (typeof value !== 'string') return value;
    const normalized = value.trim();
    return normalized || undefined;
  })
  @IsOptional()
  @IsUUID('4', { message: 'Invalid parentId' })
  parentId?: string;

  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString({ message: 'Missing name' })
  @IsNotEmpty({ message: 'Missing name' })
  name!: string;
}

import { Transform } from 'class-transformer';
import { IsUUID } from 'class-validator';

export class DocumentItemParamsDto {
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsUUID('4', { message: 'Invalid id' })
  id!: string;

  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsUUID('4', { message: 'Invalid itemId' })
  itemId!: string;
}

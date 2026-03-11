import { Transform } from 'class-transformer';
import { IsUUID } from 'class-validator';

export class UuidIdParamDto {
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsUUID('4', { message: 'Invalid id' })
  id!: string;
}

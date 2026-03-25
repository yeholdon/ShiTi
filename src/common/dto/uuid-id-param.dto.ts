import { Transform } from 'class-transformer';
import { Matches } from 'class-validator';

const uuidLikePattern =
  /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;

export class UuidIdParamDto {
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @Matches(uuidLikePattern, { message: 'Invalid id' })
  id!: string;
}

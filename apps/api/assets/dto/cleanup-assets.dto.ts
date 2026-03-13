import { Transform } from 'class-transformer';
import { IsInt, IsOptional, Min } from 'class-validator';

export class CleanupAssetsDto {
  @IsOptional()
  @Transform(({ value }) => (value === undefined || value === null || value === '' ? undefined : Number(value)))
  @IsInt({ message: 'Invalid staleHours' })
  @Min(0, { message: 'Invalid staleHours' })
  staleHours?: number;
}

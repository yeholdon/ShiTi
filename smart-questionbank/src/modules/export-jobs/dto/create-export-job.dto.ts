import { Transform } from 'class-transformer';
import { IsIn, IsOptional, IsUUID } from 'class-validator';

export class CreateExportJobDto {
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsUUID('4', { message: 'Invalid documentId' })
  documentId!: string;

  @IsOptional()
  @IsIn(['pdf'], { message: 'Unsupported kind' })
  kind?: 'pdf';
}

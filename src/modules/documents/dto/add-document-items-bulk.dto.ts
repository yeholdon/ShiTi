import { Type } from 'class-transformer';
import { ArrayMaxSize, ArrayMinSize, IsArray, ValidateNested } from 'class-validator';
import { AddDocumentItemDto } from './add-document-item.dto';

export class AddDocumentItemsBulkDto {
  @IsArray({ message: 'Missing items' })
  @ArrayMinSize(1, { message: 'Missing items' })
  @ArrayMaxSize(100, { message: 'Too many items (max 100)' })
  @ValidateNested({ each: true })
  @Type(() => AddDocumentItemDto)
  items!: AddDocumentItemDto[];
}

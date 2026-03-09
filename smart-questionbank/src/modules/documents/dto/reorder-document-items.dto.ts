import { Type } from 'class-transformer';
import { ArrayNotEmpty, IsArray, IsNotEmpty, IsNumber, IsString, ValidateNested } from 'class-validator';

export class ReorderDocumentItemDto {
  @IsString({ message: 'Invalid items' })
  @IsNotEmpty({ message: 'Invalid items' })
  id!: string;

  @Type(() => Number)
  @IsNumber({}, { message: 'Invalid items' })
  orderIndex!: number;
}

export class ReorderDocumentItemsDto {
  @IsArray({ message: 'Missing items' })
  @ArrayNotEmpty({ message: 'Missing items' })
  @ValidateNested({ each: true })
  @Type(() => ReorderDocumentItemDto)
  items!: ReorderDocumentItemDto[];
}

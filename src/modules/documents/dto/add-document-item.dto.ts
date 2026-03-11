import { IsIn, IsNotEmpty, IsOptional, IsString, ValidateIf } from 'class-validator';

export class AddDocumentItemDto {
  @IsString({ message: 'Missing itemType' })
  @IsIn(['question', 'layout_element'], { message: 'Invalid itemType' })
  itemType!: 'question' | 'layout_element';

  @ValidateIf((body: AddDocumentItemDto) => body.itemType === 'question')
  @IsString({ message: 'Missing questionId' })
  @IsNotEmpty({ message: 'Missing questionId' })
  questionId?: string | null;

  @ValidateIf((body: AddDocumentItemDto) => body.itemType === 'layout_element')
  @IsString({ message: 'Missing layoutElementId' })
  @IsNotEmpty({ message: 'Missing layoutElementId' })
  layoutElementId?: string | null;

  @IsOptional()
  scoreOverride?: string | number | null;
}

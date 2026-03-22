import { Transform } from 'class-transformer';
import { IsOptional, IsUUID } from 'class-validator';

export class CreateQuestionDto {
  @IsOptional()
  @Transform(({ value }) => {
    if (typeof value !== 'string') return value;
    const normalized = value.trim();
    return normalized || undefined;
  })
  @IsUUID('4', { message: 'Invalid questionBankId' })
  questionBankId?: string;

  @IsOptional()
  @Transform(({ value }) => {
    if (typeof value !== 'string') return value;
    const normalized = value.trim();
    return normalized || undefined;
  })
  @IsUUID('4', { message: 'Invalid subjectId' })
  subjectId?: string;
}

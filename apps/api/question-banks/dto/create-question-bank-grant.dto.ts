import { Transform } from 'class-transformer';
import { IsIn, IsNotEmpty, IsString, IsUUID } from 'class-validator';

export class CreateQuestionBankGrantDto {
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsUUID('4', { message: 'Invalid userId' })
  userId!: string;

  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString({ message: 'Missing accessLevel' })
  @IsNotEmpty({ message: 'Missing accessLevel' })
  @IsIn(['read', 'write'], { message: 'Invalid accessLevel' })
  accessLevel!: 'read' | 'write';
}

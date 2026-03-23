import { Transform } from 'class-transformer';
import { IsIn, IsNotEmpty, IsString } from 'class-validator';

export class UpdateQuestionBankGrantDto {
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString({ message: 'Missing accessLevel' })
  @IsNotEmpty({ message: 'Missing accessLevel' })
  @IsIn(['read', 'write'], { message: 'Invalid accessLevel' })
  accessLevel!: 'read' | 'write';
}

import { Transform } from 'class-transformer';
import { IsNotEmpty, IsString } from 'class-validator';

export class CreateQuestionTagDto {
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString({ message: 'Missing name' })
  @IsNotEmpty({ message: 'Missing name' })
  name!: string;
}

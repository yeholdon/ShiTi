import { Transform } from 'class-transformer';
import { IsIn, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateDocumentDto {
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString({ message: 'Missing name' })
  @IsNotEmpty({ message: 'Missing name' })
  name!: string;

  @IsOptional()
  @IsString({ message: 'Invalid kind' })
  @IsIn(['paper', 'handout'], { message: 'Invalid kind' })
  kind?: 'paper' | 'handout';
}

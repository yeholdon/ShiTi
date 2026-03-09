import { Transform } from 'class-transformer';
import { IsNotEmpty, IsString } from 'class-validator';

export class UsernameDto {
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString({ message: 'Missing username' })
  @IsNotEmpty({ message: 'Missing username' })
  username!: string;
}

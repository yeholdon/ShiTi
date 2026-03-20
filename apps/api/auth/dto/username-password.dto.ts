import { Transform } from 'class-transformer';
import { IsNotEmpty, IsString, MinLength } from 'class-validator';

export class UsernamePasswordDto {
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString({ message: 'Missing username' })
  @IsNotEmpty({ message: 'Missing username' })
  username!: string;

  @IsString({ message: 'Missing password' })
  @IsNotEmpty({ message: 'Missing password' })
  @MinLength(4, { message: 'Password too short' })
  password!: string;
}

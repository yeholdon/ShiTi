import { IsNotEmpty, IsString, MinLength } from 'class-validator';

export class ChangePasswordDto {
  @IsString({ message: 'Missing current password' })
  @IsNotEmpty({ message: 'Missing current password' })
  currentPassword!: string;

  @IsString({ message: 'Missing new password' })
  @IsNotEmpty({ message: 'Missing new password' })
  @MinLength(4, { message: 'Password too short' })
  newPassword!: string;
}

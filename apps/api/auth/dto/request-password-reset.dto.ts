import { IsIn, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class RequestPasswordResetDto {
  @IsString()
  @MinLength(3)
  @MaxLength(64)
  username!: string;

  @IsOptional()
  @IsString()
  @IsIn(['preview', 'console', 'email'])
  deliveryMode?: 'preview' | 'console' | 'email';
}

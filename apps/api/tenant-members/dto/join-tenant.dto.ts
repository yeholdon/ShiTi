import { Transform } from 'class-transformer';
import { IsIn, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class JoinTenantDto {
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString({ message: 'Missing tenantCode' })
  @IsNotEmpty({ message: 'Missing tenantCode' })
  tenantCode!: string;

  @IsOptional()
  @IsString({ message: 'Invalid role' })
  @IsIn(['member', 'admin', 'owner'], { message: 'Invalid role' })
  role?: 'member' | 'admin' | 'owner';
}

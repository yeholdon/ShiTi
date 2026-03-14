import { IsIn, IsString } from 'class-validator';

export class UpdateTenantMemberStatusDto {
  @IsString({ message: 'Invalid status' })
  @IsIn(['active', 'disabled'], { message: 'Invalid status' })
  status!: 'active' | 'disabled';
}

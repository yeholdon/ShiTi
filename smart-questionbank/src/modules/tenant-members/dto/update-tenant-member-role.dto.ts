import { IsIn, IsString } from 'class-validator';

export class UpdateTenantMemberRoleDto {
  @IsString({ message: 'Invalid role' })
  @IsIn(['member', 'admin', 'owner'], { message: 'Invalid role' })
  role!: 'member' | 'admin' | 'owner';
}

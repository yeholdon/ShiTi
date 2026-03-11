import { BadRequestException, ForbiddenException } from '@nestjs/common';
import type { Request } from 'express';
import type { PrismaService } from '../prisma/prisma.service';

export type TenantRole = 'member' | 'admin' | 'owner';

export function requireTenantId(req: Request): string {
  const tenantId = (req as any).tenant?.tenantId as string | null | undefined;
  if (!tenantId) throw new BadRequestException('Missing tenant');
  return tenantId;
}

export function requireUserId(req: Request): string {
  const userId = (req as any).auth?.userId as string | undefined;
  if (!userId) throw new BadRequestException('Missing auth user');
  return userId;
}

export async function requireActiveTenantMember(prisma: PrismaService, tenantId: string, userId: string) {
  const member = await prisma.withTenant(tenantId, (tx) =>
    tx.tenantMember.findFirst({ where: { tenantId, userId, status: 'active' } })
  );
  if (!member) throw new ForbiddenException('Not a tenant member');
  return member;
}

export async function requireTenantRole(
  prisma: PrismaService,
  tenantId: string,
  userId: string,
  allowedRoles: TenantRole[]
) {
  const member = await requireActiveTenantMember(prisma, tenantId, userId);
  if (!allowedRoles.includes(member.role as TenantRole)) {
    throw new ForbiddenException('Insufficient tenant role');
  }
  return member;
}

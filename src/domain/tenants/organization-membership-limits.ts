import { BadRequestException } from '@nestjs/common';
import type { PrismaService } from '../../prisma/prisma.service';

export const MAX_ORGANIZATION_MEMBERSHIPS = 5;

export async function ensureOrganizationMembershipCapacity(
  prisma: PrismaService,
  userId: string,
  excludeTenantId?: string,
) {
  const activeOrganizationMemberships = await prisma.tenantMember.findMany({
    where: {
      userId,
      status: 'active',
      ...(excludeTenantId ? { tenantId: { not: excludeTenantId } } : {}),
      tenant: {
        kind: 'organization',
      },
    },
    select: { tenantId: true },
  });

  if (activeOrganizationMemberships.length >= MAX_ORGANIZATION_MEMBERSHIPS) {
    throw new BadRequestException(
      `Organization membership limit reached (max ${MAX_ORGANIZATION_MEMBERSHIPS})`,
    );
  }
}

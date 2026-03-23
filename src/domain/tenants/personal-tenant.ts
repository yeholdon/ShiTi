import type { PrismaService } from '../../prisma/prisma.service';
import { ensureDefaultCloudQuestionBank } from '../questions/question-bank-access';

function personalTenantCode(userId: string) {
  return `personal-${userId}`;
}

function personalTenantName(username: string) {
  return `${username} 的个人工作区`;
}

export async function ensurePersonalTenant(
  prisma: PrismaService,
  userId: string,
  username: string,
) {
  let tenant = await prisma.tenant.findFirst({
    where: {
      kind: 'personal',
      personalOwnerUserId: userId,
    },
    select: {
      id: true,
      code: true,
      name: true,
      kind: true,
      personalOwnerUserId: true,
    },
  });

  if (!tenant) {
    tenant = await prisma.tenant.create({
      data: {
        code: personalTenantCode(userId),
        name: personalTenantName(username),
        kind: 'personal',
        personalOwnerUserId: userId,
      },
      select: {
        id: true,
        code: true,
        name: true,
        kind: true,
        personalOwnerUserId: true,
      },
    });
  }

  await prisma.withTenant(tenant.id, (tx) =>
    tx.tenantMember.upsert({
      where: {
        tenantId_userId: {
          tenantId: tenant.id,
          userId,
        },
      },
      update: {
        role: 'owner',
        status: 'active',
      },
      create: {
        tenantId: tenant.id,
        userId,
        role: 'owner',
        status: 'active',
      },
    }),
  );

  await ensureDefaultCloudQuestionBank(prisma, tenant.id, userId);

  return tenant;
}

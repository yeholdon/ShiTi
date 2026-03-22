import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import type { QuestionBank, TenantKind, TenantMemberRole } from '@prisma/client';
import type { PrismaService } from '../../prisma/prisma.service';

type WorkspaceTenant = {
  id: string;
  kind: TenantKind;
  personalOwnerUserId: string | null;
};

type ActiveMembership = {
  role: TenantMemberRole;
  status: 'active' | 'invited' | 'disabled';
};

async function getWorkspaceTenant(prisma: PrismaService, tenantId: string) {
  const tenant = await prisma.tenant.findUnique({
    where: { id: tenantId },
    select: { id: true, kind: true, personalOwnerUserId: true },
  });
  if (!tenant) {
    throw new NotFoundException('Tenant not found');
  }
  return tenant as WorkspaceTenant;
}

async function getActiveMembership(
  prisma: PrismaService,
  tenantId: string,
  userId: string,
) {
  const membership = await prisma.withTenant(tenantId, (tx) =>
    tx.tenantMember.findUnique({
      where: {
        tenantId_userId: { tenantId, userId },
      },
      select: { role: true, status: true },
    }),
  );
  if (!membership || membership.status !== 'active') {
    return null;
  }
  return membership as ActiveMembership;
}

async function getQuestionBank(
  prisma: PrismaService,
  tenantId: string,
  questionBankId: string,
) {
  const bank = await prisma.withTenant(tenantId, (tx) =>
    tx.questionBank.findUnique({
      where: { tenantId_id: { tenantId, id: questionBankId } },
    }),
  );
  if (!bank) {
    throw new NotFoundException('Question bank not found');
  }
  return bank;
}

async function getGrantLevel(
  prisma: PrismaService,
  tenantId: string,
  questionBankId: string,
  userId: string,
) {
  const grant = await prisma.withTenant(tenantId, (tx) =>
    tx.questionBankGrant.findUnique({
      where: {
        tenantId_questionBankId_userId: {
          tenantId,
          questionBankId,
          userId,
        },
      },
      select: { accessLevel: true },
    }),
  );
  return grant?.accessLevel ?? null;
}

function hasReadGrant(accessLevel: 'read' | 'write' | null) {
  return accessLevel === 'read' || accessLevel === 'write';
}

function hasWriteGrant(accessLevel: 'read' | 'write' | null) {
  return accessLevel === 'write';
}

function defaultQuestionBankName(kind: TenantKind) {
  return kind === 'personal' ? '我的云端题库' : '机构默认题库';
}

export async function ensureDefaultCloudQuestionBank(
  prisma: PrismaService,
  tenantId: string,
  actorUserId: string,
) {
  const tenant = await getWorkspaceTenant(prisma, tenantId);
  const existing = await prisma.withTenant(tenantId, (tx) =>
    tx.questionBank.findFirst({
      where: { tenantId, storageMode: 'cloud' },
      orderBy: { createdAt: 'asc' },
    }),
  );
  if (existing) {
    return existing;
  }

  let ownerUserId = actorUserId;
  if (tenant.kind === 'personal') {
    if (!tenant.personalOwnerUserId) {
      throw new BadRequestException('Personal tenant is missing owner');
    }
    ownerUserId = tenant.personalOwnerUserId;
  } else {
    const ownerMembership = await prisma.withTenant(tenantId, (tx) =>
      tx.tenantMember.findFirst({
        where: {
          tenantId,
          status: 'active',
          role: { in: ['owner', 'admin'] },
        },
        orderBy: { createdAt: 'asc' },
        select: { userId: true },
      }),
    );
    ownerUserId = ownerMembership?.userId ?? actorUserId;
  }

  return prisma.withTenant(tenantId, (tx) =>
    tx.questionBank.create({
      data: {
        tenantId,
        name: defaultQuestionBankName(tenant.kind),
        storageMode: 'cloud',
        ownerUserId,
      },
    }),
  );
}

export async function ensureReadableQuestionBank(
  prisma: PrismaService,
  tenantId: string,
  userId: string,
  questionBankId: string,
) {
  const tenant = await getWorkspaceTenant(prisma, tenantId);
  const bank = await getQuestionBank(prisma, tenantId, questionBankId);

  if (tenant.kind === 'personal') {
    if (bank.storageMode === 'local') {
      throw new ForbiddenException('Local question bank is not available through cloud API');
    }
    if (bank.ownerUserId === userId) {
      return bank;
    }
    if (hasReadGrant(await getGrantLevel(prisma, tenantId, questionBankId, userId))) {
      return bank;
    }
    throw new ForbiddenException('Question bank access denied');
  }

  const membership = await getActiveMembership(prisma, tenantId, userId);
  if (!membership) {
    throw new ForbiddenException('Not a tenant member');
  }
  if (membership.role === 'admin' || membership.role === 'owner') {
    return bank;
  }
  if (bank.ownerUserId === userId) {
    return bank;
  }
  if (hasReadGrant(await getGrantLevel(prisma, tenantId, questionBankId, userId))) {
    return bank;
  }
  throw new ForbiddenException('Question bank access denied');
}

export async function ensureWritableQuestionBank(
  prisma: PrismaService,
  tenantId: string,
  userId: string,
  questionBankId: string,
) {
  const tenant = await getWorkspaceTenant(prisma, tenantId);
  const bank = await getQuestionBank(prisma, tenantId, questionBankId);

  if (tenant.kind === 'personal') {
    if (bank.storageMode === 'local') {
      throw new ForbiddenException('Local question bank is not available through cloud API');
    }
    if (bank.ownerUserId === userId) {
      return bank;
    }
    if (hasWriteGrant(await getGrantLevel(prisma, tenantId, questionBankId, userId))) {
      return bank;
    }
    throw new ForbiddenException('Question bank write access denied');
  }

  const membership = await getActiveMembership(prisma, tenantId, userId);
  if (!membership) {
    throw new ForbiddenException('Not a tenant member');
  }
  if (membership.role === 'admin' || membership.role === 'owner') {
    return bank;
  }
  if (bank.ownerUserId === userId) {
    return bank;
  }
  if (hasWriteGrant(await getGrantLevel(prisma, tenantId, questionBankId, userId))) {
    return bank;
  }
  throw new ForbiddenException('Question bank write access denied');
}

export async function listAccessibleQuestionBanks(
  prisma: PrismaService,
  tenantId: string,
  userId: string,
) {
  const tenant = await getWorkspaceTenant(prisma, tenantId);

  if (tenant.kind === 'personal') {
    if (tenant.personalOwnerUserId === userId) {
      return prisma.withTenant(tenantId, (tx) =>
        tx.questionBank.findMany({
          where: { tenantId },
          orderBy: { createdAt: 'asc' },
        }),
      );
    }

    return prisma.withTenant(tenantId, (tx) =>
      tx.questionBank.findMany({
        where: {
          tenantId,
          storageMode: 'cloud',
          grants: { some: { userId } },
        },
        orderBy: { createdAt: 'asc' },
      }),
    );
  }

  const membership = await getActiveMembership(prisma, tenantId, userId);
  if (!membership) {
    throw new ForbiddenException('Not a tenant member');
  }
  if (membership.role === 'admin' || membership.role === 'owner') {
    return prisma.withTenant(tenantId, (tx) =>
      tx.questionBank.findMany({
        where: { tenantId },
        orderBy: { createdAt: 'asc' },
      }),
    );
  }

  return prisma.withTenant(tenantId, (tx) =>
    tx.questionBank.findMany({
      where: {
        tenantId,
        OR: [{ ownerUserId: userId }, { grants: { some: { userId } } }],
      },
      orderBy: { createdAt: 'asc' },
    }),
  );
}

export async function createCloudQuestionBank(
  prisma: PrismaService,
  tenantId: string,
  userId: string,
  data: {
    name: string;
    description?: string;
  },
) {
  const tenant = await getWorkspaceTenant(prisma, tenantId);

  if (tenant.kind === 'personal') {
    if (tenant.personalOwnerUserId !== userId) {
      throw new ForbiddenException('Only the personal workspace owner can create cloud banks');
    }
  } else {
    const membership = await getActiveMembership(prisma, tenantId, userId);
    if (!membership) {
      throw new ForbiddenException('Not a tenant member');
    }
    if (membership.role !== 'admin' && membership.role !== 'owner') {
      throw new ForbiddenException('Only institution admins can create organization question banks');
    }
  }

  return prisma.withTenant(tenantId, (tx) =>
    tx.questionBank.create({
      data: {
        tenantId,
        name: data.name,
        description: data.description,
        storageMode: 'cloud',
        ownerUserId: userId,
      },
    }),
  );
}

export type AccessibleQuestionBank = QuestionBank;

import {
  buildReadableQuestionWhere,
  ensureReadableQuestion,
  ensureWritableQuestion,
} from './question-bank-access';

function makePrisma(overrides: Partial<any> = {}) {
  return {
    tenant: {
      findUnique: jest.fn(),
    },
    user: {
      findUnique: jest.fn(),
    },
    withTenant: jest.fn(),
    ...overrides,
  } as any;
}

describe('question-bank-access', () => {
  it('allows organization members to read legacy questions plus granted banks', async () => {
    const prisma = makePrisma();
    prisma.tenant.findUnique.mockResolvedValue({
      id: 't1',
      kind: 'organization',
      personalOwnerUserId: null,
    });
    prisma.withTenant.mockImplementation(async (_tenantId: string, fn: any) =>
      fn({
        tenantMember: {
          findUnique: jest.fn().mockResolvedValue({
            role: 'member',
            status: 'active',
          }),
        },
        questionBank: {
          findMany: jest.fn().mockResolvedValue([{ id: 'bank-1' }]),
        },
      }),
    );

    await expect(
      buildReadableQuestionWhere(prisma, 't1', 'u1'),
    ).resolves.toEqual({
      tenantId: 't1',
      OR: [{ questionBankId: null }, { questionBankId: { in: ['bank-1'] } }],
    });
  });

  it('keeps organization admins scoped to owned or granted banks when listing readable questions', async () => {
    const prisma = makePrisma();
    prisma.tenant.findUnique.mockResolvedValue({
      id: 't1',
      kind: 'organization',
      personalOwnerUserId: null,
    });
    prisma.withTenant.mockImplementation(async (_tenantId: string, fn: any) =>
      fn({
        tenantMember: {
          findUnique: jest.fn().mockResolvedValue({
            role: 'admin',
            status: 'active',
          }),
        },
        questionBank: {
          findMany: jest.fn().mockResolvedValue([]),
        },
      }),
    );

    await expect(
      buildReadableQuestionWhere(prisma, 't1', 'admin-1'),
    ).resolves.toEqual({
      tenantId: 't1',
      questionBankId: null,
    });
  });

  it('allows granted users to read personal cloud bank questions', async () => {
    const prisma = makePrisma();
    prisma.tenant.findUnique.mockResolvedValue({
      id: 't1',
      kind: 'personal',
      personalOwnerUserId: 'owner-1',
    });
    prisma.withTenant.mockImplementation(async (_tenantId: string, fn: any) =>
      fn({
        question: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'q1',
            tenantId: 't1',
            questionBankId: 'bank-1',
          }),
        },
        questionBank: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'bank-1',
            tenantId: 't1',
            storageMode: 'cloud',
            ownerUserId: 'owner-1',
          }),
        },
        questionBankGrant: {
          findUnique: jest.fn().mockResolvedValue({ accessLevel: 'read' }),
        },
      }),
    );

    await expect(
      ensureReadableQuestion(prisma, 't1', 'guest-1', 'q1'),
    ).resolves.toEqual({
      id: 'q1',
      tenantId: 't1',
      questionBankId: 'bank-1',
    });
  });

  it('keeps legacy organization questions write-protected for non-admin members', async () => {
    const prisma = makePrisma();
    prisma.tenant.findUnique.mockResolvedValue({
      id: 't1',
      kind: 'organization',
      personalOwnerUserId: null,
    });
    prisma.withTenant.mockImplementation(async (_tenantId: string, fn: any) =>
      fn({
        question: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'q1',
            tenantId: 't1',
            questionBankId: null,
          }),
        },
        tenantMember: {
          findUnique: jest.fn().mockResolvedValue({
            role: 'member',
            status: 'active',
          }),
        },
      }),
    );

    await expect(
      ensureWritableQuestion(prisma, 't1', 'member-1', 'q1'),
    ).rejects.toThrow('Question write access denied');
  });

  it('denies organization admins reading bank questions without owner or grant access', async () => {
    const prisma = makePrisma();
    prisma.tenant.findUnique.mockResolvedValue({
      id: 't1',
      kind: 'organization',
      personalOwnerUserId: null,
    });
    prisma.withTenant.mockImplementation(async (_tenantId: string, fn: any) =>
      fn({
        question: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'q1',
            tenantId: 't1',
            questionBankId: 'bank-1',
          }),
        },
        questionBank: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'bank-1',
            tenantId: 't1',
            storageMode: 'cloud',
            ownerUserId: 'owner-1',
          }),
        },
        tenantMember: {
          findUnique: jest.fn().mockResolvedValue({
            role: 'admin',
            status: 'active',
          }),
        },
        questionBankGrant: {
          findUnique: jest.fn().mockResolvedValue(null),
        },
      }),
    );

    await expect(
      ensureReadableQuestion(prisma, 't1', 'admin-1', 'q1'),
    ).rejects.toThrow('Question bank access denied');
  });
});

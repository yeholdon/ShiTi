import { QuestionBanksController } from './question-banks.controller';

function makePrisma(overrides: Partial<any> = {}) {
  return {
    tenant: {
      findUnique: jest.fn(),
    },
    withTenant: jest.fn(),
    ...overrides,
  } as any;
}

describe('QuestionBanksController', () => {
  it('lists default cloud bank for personal tenant owner', async () => {
    const prisma = makePrisma();
    prisma.tenant.findUnique.mockResolvedValue({
      id: 't1',
      kind: 'personal',
      personalOwnerUserId: 'u1',
    });
    prisma.withTenant
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce({
        id: 'b1',
        tenantId: 't1',
        name: '我的云端题库',
        storageMode: 'cloud',
        ownerUserId: 'u1',
        description: null,
        createdAt: 'c',
        updatedAt: 'u',
      })
      .mockResolvedValueOnce([
        {
          id: 'b1',
          tenantId: 't1',
          name: '我的云端题库',
          storageMode: 'cloud',
          ownerUserId: 'u1',
          description: null,
          createdAt: 'c',
          updatedAt: 'u',
        },
      ]);

    const controller = new QuestionBanksController(prisma);
    const result = await controller.list({
      tenant: { tenantId: 't1' },
      auth: { userId: 'u1' },
    } as any);

    expect(result.questionBanks).toHaveLength(1);
    expect(result.questionBanks[0].name).toBe('我的云端题库');
  });

  it('rejects local bank creation through cloud API', async () => {
    const controller = new QuestionBanksController(makePrisma());

    await expect(
      controller.create(
        { tenant: { tenantId: 't1' }, auth: { userId: 'u1' } } as any,
        { name: '本地题库', storageMode: 'local' } as any,
      ),
    ).rejects.toThrow('Local question banks are desktop-local only');
  });

  it('creates question-bank grant for organization admin', async () => {
    const prisma = makePrisma({
      user: {
        findUnique: jest.fn().mockResolvedValue({ id: 'u2', username: 'reader' }),
      },
    });
    prisma.tenant.findUnique.mockResolvedValue({
      id: 't1',
      kind: 'organization',
      personalOwnerUserId: null,
    });
    prisma.withTenant.mockImplementation(async (_tenantId: string, fn: any) => {
      const tx = {
        questionBank: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'b1',
            tenantId: 't1',
            storageMode: 'cloud',
            ownerUserId: 'u1',
          }),
        },
        tenantMember: {
          findUnique: jest
            .fn()
            .mockResolvedValueOnce({ role: 'admin', status: 'active' })
            .mockResolvedValueOnce({ role: 'member', status: 'active' }),
        },
        questionBankGrant: {
          upsert: jest.fn().mockResolvedValue({
            tenantId: 't1',
            questionBankId: 'b1',
            userId: 'u2',
            accessLevel: 'read',
            grantedByUserId: 'u1',
            user: { id: 'u2', username: 'reader' },
            grantedBy: { id: 'u1', username: 'admin' },
          }),
        },
      };
      return fn(tx);
    });

    const controller = new QuestionBanksController(prisma);
    const result = await controller.createGrant(
      { tenant: { tenantId: 't1' }, auth: { userId: 'u1' } } as any,
      { id: 'b1' } as any,
      { userId: 'u2', accessLevel: 'read' } as any,
    );

    expect(result.grant.accessLevel).toBe('read');
    expect(result.grant.user.username).toBe('reader');
  });
});

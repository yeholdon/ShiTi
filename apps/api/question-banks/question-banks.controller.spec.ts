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
});

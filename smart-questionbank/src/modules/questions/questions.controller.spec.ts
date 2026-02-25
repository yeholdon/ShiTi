import { QuestionsController } from './questions.controller';

function makePrisma(overrides: Partial<any> = {}) {
  return {
    subject: {
      findFirst: jest.fn()
    },
    withTenant: jest.fn(),
    ...overrides
  } as any;
}

describe('QuestionsController', () => {
  it('throws Missing tenant when tenantId not present', async () => {
    const ctrl = new QuestionsController(makePrisma());

    await expect(ctrl.list({} as any)).rejects.toThrow('Missing tenant');
    await expect(ctrl.create({} as any, {} as any)).rejects.toThrow('Missing tenant');
  });

  it('creates question using provided subjectId without querying system subject', async () => {
    const prisma = makePrisma();
    prisma.withTenant.mockImplementation(async (_tenantId: string, fn: any) => {
      const tx = {
        tenantMember: { findFirst: jest.fn().mockResolvedValue({ id: 'm1' }) },
        question: { create: jest.fn().mockResolvedValue({ id: 'q1' }) }
      };
      return fn(tx);
    });

    const ctrl = new QuestionsController(prisma);
    const req: any = { tenant: { tenantId: 't1' }, auth: { userId: 'u1' } };

    const res = await ctrl.create(req, { subjectId: 'sub-123' });

    expect(prisma.subject.findFirst).not.toHaveBeenCalled();
    expect(prisma.withTenant).toHaveBeenCalledTimes(2);
    expect(res.question).toEqual({ id: 'q1' });
  });

  it('throws when no system subject found and subjectId not provided', async () => {
    const prisma = makePrisma();
    prisma.subject.findFirst.mockResolvedValue(null);
    prisma.withTenant.mockImplementation(async (_tenantId: string, fn: any) => {
      const tx = {
        tenantMember: { findFirst: jest.fn().mockResolvedValue({ id: 'm1' }) },
        question: { create: jest.fn().mockResolvedValue({ id: 'q1' }) }
      };
      return fn(tx);
    });

    const ctrl = new QuestionsController(prisma);
    const req: any = { tenant: { tenantId: 't1' }, auth: { userId: 'u1' } };

    await expect(ctrl.create(req, {} as any)).rejects.toThrow('No system subject found; run prisma seed');
  });
});

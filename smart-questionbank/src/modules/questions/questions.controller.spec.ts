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
  function makeImportService(overrides: Partial<any> = {}) {
    return {
      importQuestions: jest.fn(),
      ...overrides
    } as any;
  }

  it('throws Missing tenant when tenantId not present', async () => {
    const ctrl = new QuestionsController(makePrisma(), makeImportService());

    await expect(ctrl.list({} as any)).rejects.toThrow('Missing tenant');
    await expect(ctrl.create({} as any, {} as any)).rejects.toThrow('Missing tenant');
  });

  it('creates question using provided subjectId when it belongs to tenant/system subjects', async () => {
    const prisma = makePrisma();
    prisma.subject.findFirst.mockResolvedValue({ id: 'sub-123' });
    prisma.withTenant.mockImplementation(async (_tenantId: string, fn: any) => {
      const tx = {
        tenantMember: { findFirst: jest.fn().mockResolvedValue({ id: 'm1' }) },
        question: { create: jest.fn().mockResolvedValue({ id: 'q1' }) }
      };
      return fn(tx);
    });

    const ctrl = new QuestionsController(prisma, makeImportService());
    const req: any = { tenant: { tenantId: 't1' }, auth: { userId: 'u1' } };

    const res = await ctrl.create(req, { subjectId: 'sub-123' });

    expect(prisma.subject.findFirst).toHaveBeenCalledWith({
      where: {
        id: 'sub-123',
        OR: [{ tenantId: null, isSystem: true }, { tenantId: 't1' }]
      },
      select: { id: true }
    });
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

    const ctrl = new QuestionsController(prisma, makeImportService());
    const req: any = { tenant: { tenantId: 't1' }, auth: { userId: 'u1' } };

    await expect(ctrl.create(req, {} as any)).rejects.toThrow('No system subject found; run prisma seed');
  });
});

import { ensureTenantOrSystemSubject } from './subject-access';

function makePrisma(subject: { id: string } | null) {
  return {
    subject: {
      findFirst: jest.fn().mockResolvedValue(subject)
    }
  } as any;
}

describe('ensureTenantOrSystemSubject', () => {
  it('accepts a subject when it belongs to system or current tenant scope', async () => {
    const prisma = makePrisma({ id: 'sub-1' });

    await expect(ensureTenantOrSystemSubject(prisma, 'tenant-1', 'sub-1')).resolves.toBe('sub-1');

    expect(prisma.subject.findFirst).toHaveBeenCalledWith({
      where: {
        id: 'sub-1',
        OR: [{ tenantId: null, isSystem: true }, { tenantId: 'tenant-1' }]
      },
      select: { id: true }
    });
  });

  it('rejects missing subjectId', async () => {
    const prisma = makePrisma({ id: 'sub-1' });

    await expect(ensureTenantOrSystemSubject(prisma, 'tenant-1', '')).rejects.toThrow('Missing subjectId');
  });

  it('rejects subject outside current tenant scope', async () => {
    const prisma = makePrisma(null);

    await expect(ensureTenantOrSystemSubject(prisma, 'tenant-1', 'sub-x')).rejects.toThrow(
      'Invalid subjectId for current tenant'
    );
  });
});

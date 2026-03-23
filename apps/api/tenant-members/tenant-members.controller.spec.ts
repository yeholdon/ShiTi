import { TenantMembersController } from './tenant-members.controller';

function makePrisma(overrides: Partial<any> = {}) {
  return {
    tenant: {
      findUnique: jest.fn(),
    },
    tenantMember: {
      findMany: jest.fn().mockResolvedValue([]),
    },
    user: {
      findUnique: jest.fn(),
    },
    withTenant: jest.fn(),
    ...overrides,
  } as any;
}

function makeAudit(overrides: Partial<any> = {}) {
  return {
    record: jest.fn(),
    ...overrides,
  } as any;
}

describe('TenantMembersController', () => {
  it('rejects joining a sixth active organization membership', async () => {
    const prisma = makePrisma();
    prisma.tenant.findUnique.mockResolvedValue({
      id: 't1',
      code: 'org-1',
      kind: 'organization',
    });
    prisma.tenantMember.findMany.mockResolvedValue([
      { tenantId: 'o1' },
      { tenantId: 'o2' },
      { tenantId: 'o3' },
      { tenantId: 'o4' },
      { tenantId: 'o5' },
    ]);
    prisma.withTenant.mockImplementation(async (_tenantId: string, fn: any) =>
      fn({
        tenantMember: {
          count: jest.fn().mockResolvedValue(2),
          findUnique: jest.fn().mockResolvedValue(null),
          upsert: jest.fn(),
        },
      }),
    );

    const controller = new TenantMembersController(prisma, makeAudit());

    await expect(
      controller.join(
        { auth: { userId: 'u1' } } as any,
        { tenantCode: 'org-1' } as any,
      ),
    ).rejects.toThrow('Organization membership limit reached');
  });

  it('rejects re-activating a sixth active organization membership', async () => {
    const prisma = makePrisma();
    prisma.tenant.findUnique.mockResolvedValue({
      id: 't1',
      code: 'org-1',
      kind: 'organization',
    });
    prisma.tenantMember.findMany.mockResolvedValue([
      { tenantId: 'o1' },
      { tenantId: 'o2' },
      { tenantId: 'o3' },
      { tenantId: 'o4' },
      { tenantId: 'o5' },
    ]);
    prisma.withTenant.mockImplementation(async (_tenantId: string, fn: any) =>
      fn({
        tenantMember: {
          findFirst: jest.fn().mockResolvedValue({ role: 'owner', status: 'active' }),
          findUnique: jest.fn().mockResolvedValue({
            id: 'm1',
            tenantId: 't1',
            userId: 'u2',
            role: 'member',
            status: 'invited',
            createdAt: new Date('2026-03-01T00:00:00.000Z'),
            updatedAt: new Date('2026-03-02T00:00:00.000Z'),
            user: { username: 'reader' },
          }),
          count: jest.fn().mockResolvedValue(1),
          update: jest.fn(),
        },
      }),
    );

    const controller = new TenantMembersController(prisma, makeAudit());

    await expect(
      controller.updateStatus(
        {
          tenant: { tenantId: 't1' },
          auth: { userId: 'owner-1' },
        } as any,
        { id: 'm1' } as any,
        { status: 'active' } as any,
      ),
    ).rejects.toThrow('Organization membership limit reached');
  });
});

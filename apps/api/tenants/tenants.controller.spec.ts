import { TenantsController } from './tenants.controller';

function makePrisma(overrides: Partial<any> = {}) {
  return {
    tenant: {
      findUnique: jest.fn(),
      findMany: jest.fn(),
      create: jest.fn()
    },
    tenantMember: {
      findMany: jest.fn().mockResolvedValue([]),
    },
    withTenant: jest.fn(),
    ...overrides
  } as any;
}

describe('TenantsController', () => {
  it('createTenant returns existing tenant when code already exists', async () => {
    const prisma = makePrisma();
    prisma.tenant.findUnique.mockResolvedValue({ id: 't1', code: 'acme' });

    const ctrl = new TenantsController(prisma);
    const res = await ctrl.createTenant({} as any, { code: 'acme', name: 'ACME' });

    expect(prisma.tenant.create).not.toHaveBeenCalled();
    expect(res).toEqual({ tenant: { id: 't1', code: 'acme' } });
  });

  it('createTenant creates tenant when not exists and request is anonymous', async () => {
    const prisma = makePrisma();
    prisma.tenant.findUnique.mockResolvedValue(null);
    prisma.tenant.create.mockResolvedValue({ id: 't2', code: 'acme', name: 'ACME' });

    const ctrl = new TenantsController(prisma);
    const res = await ctrl.createTenant({} as any, { code: 'acme', name: 'ACME' });

    expect(prisma.tenant.create).toHaveBeenCalledWith({ data: { code: 'acme', name: 'ACME' } });
    expect(res.tenant.id).toBe('t2');
  });

  it('createTenant can bootstrap owner from creator username when auth is missing', async () => {
    const prisma = makePrisma({
      user: {
        findUnique: jest.fn().mockResolvedValue({ id: 'u1' }),
      },
    });
    prisma.tenant.findUnique
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce({
        id: 't2',
        kind: 'organization',
        personalOwnerUserId: null,
      });
    prisma.tenant.create.mockResolvedValue({ id: 't2', code: 'acme', name: 'ACME' });
    prisma.withTenant.mockImplementation(async (_tenantId: string, fn: any) => {
      const tx = {
        tenantMember: {
          create: jest.fn().mockResolvedValue({ id: 'm1', role: 'owner', status: 'active' }),
          findFirst: jest.fn().mockResolvedValue({ userId: 'u1' }),
        },
        questionBank: {
          findFirst: jest.fn().mockResolvedValue(null),
          create: jest.fn().mockResolvedValue({ id: 'b1', name: '机构默认题库' }),
        },
      };
      return fn(tx);
    });

    const ctrl = new TenantsController(prisma);
    const res = await ctrl.createTenant(
      {} as any,
      { code: 'acme', name: 'ACME', creatorUsername: 'teacher-demo' }
    );

    expect(prisma.user.findUnique).toHaveBeenCalledWith({
      where: { username: 'teacher-demo' },
      select: { id: true },
    });
    expect(res).toEqual({
      tenant: {
        id: 't2',
        code: 'acme',
        name: 'ACME',
        role: 'owner',
      },
    });
  });

  it('createTenant auto-joins the authenticated creator as owner', async () => {
    const prisma = makePrisma();
    prisma.tenant.findUnique
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce({
        id: 't2',
        kind: 'organization',
        personalOwnerUserId: null,
      });
    prisma.tenant.create.mockResolvedValue({ id: 't2', code: 'acme', name: 'ACME' });
    prisma.withTenant.mockImplementation(async (_tenantId: string, fn: any) => {
      const tx = {
        tenantMember: {
          create: jest.fn().mockResolvedValue({ id: 'm1', role: 'owner', status: 'active' }),
          findFirst: jest.fn().mockResolvedValue({ userId: 'u1' }),
        },
        questionBank: {
          findFirst: jest.fn().mockResolvedValue(null),
          create: jest.fn().mockResolvedValue({ id: 'b1', name: '机构默认题库' }),
        },
      };
      return fn(tx);
    });

    const ctrl = new TenantsController(prisma);
    const res = await ctrl.createTenant(
      { auth: { userId: 'u1' } } as any,
      { code: 'acme', name: 'ACME' }
    );

    expect(prisma.withTenant).toHaveBeenCalledTimes(4);
    expect(res).toEqual({
      tenant: {
        id: 't2',
        code: 'acme',
        name: 'ACME',
        role: 'owner',
      },
    });
  });

  it('createTenant auto-recovers owner membership for an empty existing tenant', async () => {
    const prisma = makePrisma();
    prisma.tenant.findUnique.mockResolvedValue({ id: 't1', code: 'acme', name: 'ACME' });
    prisma.withTenant
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce(0)
      .mockResolvedValueOnce({ id: 'm1', role: 'owner', status: 'active' });

    const ctrl = new TenantsController(prisma);
    const res = await ctrl.createTenant(
      { auth: { userId: 'u1' } } as any,
      { code: 'acme', name: 'ACME' }
    );

    expect(res).toEqual({
      tenant: {
        id: 't1',
        code: 'acme',
        name: 'ACME',
        role: 'owner',
      },
    });
  });

  it('createTenant rejects when creator already has 5 active organization memberships', async () => {
    const prisma = makePrisma();
    prisma.tenant.findUnique.mockResolvedValue(null);
    prisma.tenantMember.findMany.mockResolvedValue([
      { tenantId: 'o1' },
      { tenantId: 'o2' },
      { tenantId: 'o3' },
      { tenantId: 'o4' },
      { tenantId: 'o5' },
    ]);

    const ctrl = new TenantsController(prisma);

    await expect(
      ctrl.createTenant({ auth: { userId: 'u1' } } as any, {
        code: 'acme',
        name: 'ACME',
      }),
    ).rejects.toThrow('Organization membership limit reached');
    expect(prisma.tenant.create).not.toHaveBeenCalled();
  });

  it('resolve returns null when tenantCode missing', async () => {
    const prisma = makePrisma();
    const ctrl = new TenantsController(prisma);

    const res = await ctrl.resolve('' as any);

    expect(prisma.tenant.findUnique).not.toHaveBeenCalled();
    expect(res).toEqual({ tenant: null });
  });

  it('resolve queries tenant by code when provided', async () => {
    const prisma = makePrisma();
    prisma.tenant.findUnique.mockResolvedValue({ id: 't1', code: 'acme' });

    const ctrl = new TenantsController(prisma);
    const res = await ctrl.resolve('acme' as any);

    expect(prisma.tenant.findUnique).toHaveBeenCalledWith({ where: { code: 'acme' } });
    expect(res).toEqual({ tenant: { id: 't1', code: 'acme' } });
  });

  it('listTenants returns active memberships for the authenticated user', async () => {
    const prisma = makePrisma();
    prisma.tenant.findMany.mockResolvedValue([
      { id: 't1', code: 'acme', name: 'ACME' },
      { id: 't2', code: 'beta', name: 'Beta' },
      { id: 't3', code: 'gamma', name: 'Gamma' }
    ]);
    prisma.withTenant
      .mockResolvedValueOnce({ role: 'owner', status: 'active' })
      .mockResolvedValueOnce({ role: 'member', status: 'active' })
      .mockResolvedValueOnce({ role: 'member', status: 'disabled' });

    const ctrl = new TenantsController(prisma);
    const res = await ctrl.listTenants({ auth: { userId: 'u1' } } as any);

    expect(prisma.tenant.findMany).toHaveBeenCalledWith({
      orderBy: {
        createdAt: 'asc'
      }
    });
    expect(prisma.withTenant).toHaveBeenCalledTimes(3);
    expect(res).toEqual({
      tenants: [
        { id: 't1', code: 'acme', name: 'ACME', role: 'owner' },
        { id: 't2', code: 'beta', name: 'Beta', role: 'member' }
      ]
    });
  });
});

import { TenantsController } from './tenants.controller';

function makePrisma(overrides: Partial<any> = {}) {
  return {
    tenant: {
      findUnique: jest.fn(),
      findMany: jest.fn(),
      create: jest.fn()
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
    const res = await ctrl.createTenant({ code: 'acme', name: 'ACME' });

    expect(prisma.tenant.create).not.toHaveBeenCalled();
    expect(res).toEqual({ tenant: { id: 't1', code: 'acme' } });
  });

  it('createTenant creates tenant when not exists', async () => {
    const prisma = makePrisma();
    prisma.tenant.findUnique.mockResolvedValue(null);
    prisma.tenant.create.mockResolvedValue({ id: 't2', code: 'acme', name: 'ACME' });

    const ctrl = new TenantsController(prisma);
    const res = await ctrl.createTenant({ code: 'acme', name: 'ACME' });

    expect(prisma.tenant.create).toHaveBeenCalledWith({ data: { code: 'acme', name: 'ACME' } });
    expect(res.tenant.id).toBe('t2');
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
    const res = await ctrl.listTenants({ user: { userId: 'u1' } } as any);

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

import { TenantResolveMiddleware } from './tenant-resolve.middleware';

function makePrisma(tenantId: string | null) {
  return {
    tenant: {
      findUnique: jest.fn().mockResolvedValue(tenantId ? { id: tenantId } : null)
    }
  } as any;
}

function makeReq(headerValue: string | null) {
  return {
    header: jest.fn().mockImplementation((name: string) => {
      if (name === 'x-tenant-code' || name === 'X-Tenant-Code') return headerValue;
      return undefined;
    })
  } as any;
}

describe('TenantResolveMiddleware', () => {
  it('sets tenant to nulls when header missing', async () => {
    const mw = new TenantResolveMiddleware(makePrisma('t1'));
    const req: any = makeReq(null);
    const next = jest.fn();

    await mw.use(req, {} as any, next);

    expect(req.tenant).toEqual({ tenantCode: null, tenantId: null });
    expect(next).toHaveBeenCalledTimes(1);
  });

  it('trims header and resolves tenant id', async () => {
    const prisma = makePrisma('tenant-123');
    const mw = new TenantResolveMiddleware(prisma);
    const req: any = makeReq('  acme  ');
    const next = jest.fn();

    await mw.use(req, {} as any, next);

    expect(prisma.tenant.findUnique).toHaveBeenCalledWith({ where: { code: 'acme' } });
    expect(req.tenant).toEqual({ tenantCode: 'acme', tenantId: 'tenant-123' });
    expect(next).toHaveBeenCalledTimes(1);
  });

  it('keeps tenantId null when code not found', async () => {
    const prisma = makePrisma(null);
    const mw = new TenantResolveMiddleware(prisma);
    const req: any = makeReq('missing');
    const next = jest.fn();

    await mw.use(req, {} as any, next);

    expect(req.tenant).toEqual({ tenantCode: 'missing', tenantId: null });
    expect(next).toHaveBeenCalledTimes(1);
  });
});

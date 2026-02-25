import type { TenantContext } from './tenant.types';

describe('TenantContext type', () => {
  it('accepts null tenantId/tenantCode', () => {
    const ctx: TenantContext = { tenantId: null, tenantCode: null };
    expect(ctx.tenantId).toBeNull();
    expect(ctx.tenantCode).toBeNull();
  });
});

import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Tenant membership authorization (e2e)', () => {
  it('forbids accessing a tenant when user is not a member', async () => {
    const suffix = Date.now();
    const tenant = { code: `forbid-tenant-${suffix}`, name: 'Forbid Tenant' };

    await request(base).post('/tenants').send(tenant);

    const reg = await request(base).post('/auth/register').send({ username: `user-${suffix}` });
    const token = reg.body.accessToken;

    const res = await request(base)
      .get('/questions')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(403);
    expect(res.body.message).toContain('Not a tenant member');
    expect(res.body.statusCode).toBe(403);
    expect(res.body.error.code).toBe('forbidden');
    expect(res.body.path).toBe('/questions');
    expect(typeof res.body.requestId).toBe('string');
    expect(res.headers['x-request-id']).toBe(res.body.requestId);
  });
});

import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Auth (e2e)', () => {
  it('rejects /questions without Bearer token, then allows with token', async () => {
    const suffix = Date.now();
    const tenant = { code: `auth-tenant-${suffix}`, name: 'Auth Tenant' };

    await request(base).post('/tenants').send(tenant);

    const res401 = await request(base).get('/questions').set('X-Tenant-Code', tenant.code);
    expect([401, 403]).toContain(res401.status);

    const login = await request(base).post('/auth/register').send({ username: 'u1' });
    expect(login.status).toBe(201);
    expect(typeof login.body.accessToken).toBe('string');

    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${login.body.accessToken}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    const res200 = await request(base)
      .get('/questions')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${login.body.accessToken}`);

    expect(res200.status).toBe(200);
    expect(Array.isArray(res200.body.questions)).toBe(true);
  });
});

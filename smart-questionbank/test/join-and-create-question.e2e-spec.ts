import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Business flow (e2e)', () => {
  it('register -> join tenant -> create -> list', async () => {
    const suffix = Date.now();
    const tenant = { code: `flow-tenant-${suffix}`, name: 'Flow Tenant' };

    await request(base).post('/tenants').send(tenant);

    const reg = await request(base).post('/auth/register').send({ username: `user-${suffix}` });
    expect(reg.status).toBe(201);
    const token = reg.body.accessToken;
    expect(typeof token).toBe('string');

    const join = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    expect(join.status).toBe(201);

    const created = await request(base)
      .post('/questions')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(created.status).toBe(201);

    const list = await request(base)
      .get('/questions')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(list.status).toBe(200);
    expect(Array.isArray(list.body.questions)).toBe(true);
  });
});

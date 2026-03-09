import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Auth (e2e)', () => {
  it('rate limits register by client ip', async () => {
    const suffix = Date.now();
    const ip = `198.51.100.${(suffix % 200) + 1}`;

    for (let index = 0; index < 5; index += 1) {
      const res = await request(base)
        .post('/auth/register')
        .set('X-Test-Rate-Limit', 'on')
        .set('X-Forwarded-For', ip)
        .send({ username: `rate-limit-${suffix}-${index}` });

      expect(res.status).toBe(201);
    }

    const limited = await request(base)
      .post('/auth/register')
      .set('X-Test-Rate-Limit', 'on')
      .set('X-Forwarded-For', ip)
      .send({ username: `rate-limit-${suffix}-blocked` });

    expect(limited.status).toBe(429);
    expect(limited.body.error.code).toBe('too_many_requests');
    expect(String(limited.body.message)).toContain('Rate limit exceeded');
  });

  it('validates username on register', async () => {
    const res = await request(base).post('/auth/register').send({});

    expect(res.status).toBe(400);
    expect(res.body.message).toContain('Missing username');
    expect(res.body.error.code).toBe('validation_failed');
    expect(res.body.error.details[0].field).toBe('username');
  });

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

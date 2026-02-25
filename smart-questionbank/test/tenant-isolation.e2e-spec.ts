import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Tenant isolation (e2e)', () => {
  it('A tenant cannot see B tenant questions', async () => {
    const suffix = Date.now();
    const tenantA = { code: `tenant-a-${suffix}`, name: 'Tenant A' };
    const tenantB = { code: `tenant-b-${suffix}`, name: 'Tenant B' };

    const login = await request(base).post('/auth/register').send({ username: 'u-e2e' });
    const token = login.body.accessToken;
    expect(typeof token).toBe('string');

    await request(base).post('/tenants').send(tenantA);
    await request(base).post('/tenants').send(tenantB);

    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenantA.code, role: 'owner' });

    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenantB.code, role: 'owner' });

    const resA = await request(base).get('/tenants/resolve').set('X-Tenant-Code', tenantA.code);
    const resB = await request(base).get('/tenants/resolve').set('X-Tenant-Code', tenantB.code);

    expect(resA.body.tenant?.id).toBeTruthy();
    expect(resB.body.tenant?.id).toBeTruthy();

    // Create question in tenant A (subjectId will be auto-picked from system seed if omitted)
    await request(base)
      .post('/questions')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({});

    const listA = await request(base)
      .get('/questions')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`);
    const listB = await request(base)
      .get('/questions')
      .set('X-Tenant-Code', tenantB.code)
      .set('Authorization', `Bearer ${token}`);

    expect(Array.isArray(listA.body.questions)).toBe(true);
    expect(Array.isArray(listB.body.questions)).toBe(true);
    expect(listA.body.questions.length).toBeGreaterThan(0);
    expect(listB.body.questions.length).toBe(0);
  });
});

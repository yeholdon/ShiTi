import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Textbooks (e2e)', () => {
  it('lists system textbooks for everyone and tenant textbooks only within the tenant', async () => {
    const suffix = Date.now();
    const tenantA = { code: `textbooks-a-${suffix}`, name: 'Textbooks A' };
    const tenantB = { code: `textbooks-b-${suffix}`, name: 'Textbooks B' };

    const login = await request(base).post('/auth/register').send({ username: `textbooks-user-${suffix}` });
    expect(login.status).toBe(201);
    const token = login.body.accessToken as string;
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

    const systemList = await request(base).get('/textbooks').set('Authorization', `Bearer ${token}`);
    expect(systemList.status).toBe(200);
    expect(Array.isArray(systemList.body.textbooks)).toBe(true);
    expect(systemList.body.textbooks.length).toBeGreaterThan(0);

    const systemTextbookNames = new Set<string>(systemList.body.textbooks.map((textbook: any) => textbook.name));
    const tenantTextbookName = `Tenant Textbook ${suffix}`;

    const createTextbook = await request(base)
      .post('/textbooks')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ name: tenantTextbookName });

    expect(createTextbook.status).toBe(201);
    expect(createTextbook.body.textbook.name).toBe(tenantTextbookName);
    expect(createTextbook.body.textbook.tenantId).toBeTruthy();

    const tenantAList = await request(base)
      .get('/textbooks')
      .query({ sortBy: 'createdAt', sortOrder: 'desc', limit: 1 })
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`);

    expect(tenantAList.status).toBe(200);
    expect(tenantAList.body.meta.limit).toBe(1);
    expect(tenantAList.body.meta.sortBy).toBe('createdAt');
    expect(tenantAList.body.meta.total).toBe(systemList.body.textbooks.length + 1);
    expect(tenantAList.body.textbooks).toHaveLength(1);
    expect(tenantAList.body.textbooks[0].name).toBe(tenantTextbookName);

    const tenantBList = await request(base)
      .get('/textbooks')
      .query({ offset: 0, limit: 20 })
      .set('X-Tenant-Code', tenantB.code)
      .set('Authorization', `Bearer ${token}`);

    expect(tenantBList.status).toBe(200);
    expect(tenantBList.body.meta.total).toBe(systemList.body.textbooks.length);
    expect(tenantBList.body.textbooks.some((textbook: any) => textbook.name === tenantTextbookName)).toBe(false);
    expect(
      [...systemTextbookNames].every((name) => tenantBList.body.textbooks.some((textbook: any) => textbook.name === name))
    ).toBe(true);
  });

  it('validates create payloads', async () => {
    const suffix = Date.now();
    const tenant = { code: `textbooks-validation-${suffix}`, name: 'Textbooks Validation' };

    const login = await request(base).post('/auth/register').send({ username: `textbooks-validation-${suffix}` });
    const token = login.body.accessToken as string;

    await request(base).post('/tenants').send(tenant);
    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    const createTextbook = await request(base)
      .post('/textbooks')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(createTextbook.status).toBe(400);
    expect(createTextbook.body.error.code).toBe('validation_failed');
    expect(createTextbook.body.error.details).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ field: 'name', messages: expect.arrayContaining(['Missing name']) })
      ])
    );
  });
});

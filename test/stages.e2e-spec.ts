import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Stages (e2e)', () => {
  it('lists system stages for everyone and tenant stages only within the tenant', async () => {
    const suffix = Date.now();
    const tenantA = { code: `stages-a-${suffix}`, name: 'Stages A' };
    const tenantB = { code: `stages-b-${suffix}`, name: 'Stages B' };

    const login = await request(base).post('/auth/register').send({ username: `stages-user-${suffix}` });
    expect(login.status).toBe(201);
    const token = login.body.accessToken as string;

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

    const systemList = await request(base).get('/stages').set('Authorization', `Bearer ${token}`);
    expect(systemList.status).toBe(200);
    expect(systemList.body.stages.length).toBeGreaterThan(0);
    expect(systemList.body.stages.map((stage: any) => stage.name)).toEqual(
      expect.arrayContaining(['小学', '初中', '高中', '本科', '考研', '专升本'])
    );

    const createStage = await request(base)
      .post('/stages')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ code: `custom-${suffix}`, name: `Custom Stage ${suffix}`, order: 99 });

    expect(createStage.status).toBe(201);
    expect(createStage.body.stage.tenantId).toBeTruthy();

    const tenantAList = await request(base)
      .get('/stages')
      .query({ sortBy: 'order', sortOrder: 'desc', limit: 1 })
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`);

    expect(tenantAList.status).toBe(200);
    expect(tenantAList.body.meta.limit).toBe(1);
    expect(tenantAList.body.meta.sortBy).toBe('order');
    expect(tenantAList.body.meta.sortOrder).toBe('desc');
    expect(tenantAList.body.stages).toHaveLength(1);
    expect(tenantAList.body.stages[0].id).toBe(createStage.body.stage.id);

    const tenantBList = await request(base)
      .get('/stages')
      .query({ limit: 50 })
      .set('X-Tenant-Code', tenantB.code)
      .set('Authorization', `Bearer ${token}`);

    expect(tenantBList.status).toBe(200);
    expect(tenantBList.body.meta.total).toBe(systemList.body.stages.length);
    expect(tenantBList.body.stages.some((stage: any) => stage.id === createStage.body.stage.id)).toBe(false);
  });

  it('validates create payloads', async () => {
    const suffix = Date.now();
    const tenant = { code: `stages-validation-${suffix}`, name: 'Stages Validation' };

    const login = await request(base).post('/auth/register').send({ username: `stages-validation-${suffix}` });
    const token = login.body.accessToken as string;

    await request(base).post('/tenants').send(tenant);
    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    const createStage = await request(base)
      .post('/stages')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(createStage.status).toBe(400);
    expect(createStage.body.error.code).toBe('validation_failed');
    expect(createStage.body.error.details).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ field: 'code', messages: expect.arrayContaining(['Missing code']) }),
        expect.objectContaining({ field: 'name', messages: expect.arrayContaining(['Missing name']) })
      ])
    );
  });
});

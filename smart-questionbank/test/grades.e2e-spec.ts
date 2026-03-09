import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Grades (e2e)', () => {
  it('lists seeded grades and supports tenant grades on accessible stages only', async () => {
    const suffix = Date.now();
    const tenantA = { code: `grades-a-${suffix}`, name: 'Grades A' };
    const tenantB = { code: `grades-b-${suffix}`, name: 'Grades B' };

    const login = await request(base).post('/auth/register').send({ username: `grades-user-${suffix}` });
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

    const systemStages = await request(base).get('/stages').set('Authorization', `Bearer ${token}`);
    expect(systemStages.status).toBe(200);
    const primaryStage = systemStages.body.stages.find((stage: any) => stage.code === 'primary');
    expect(primaryStage).toBeTruthy();

    const systemGrades = await request(base)
      .get('/grades')
      .query({ stageId: primaryStage.id })
      .set('Authorization', `Bearer ${token}`);

    expect(systemGrades.status).toBe(200);
    expect(systemGrades.body.grades.length).toBeGreaterThan(0);

    const createTenantStage = await request(base)
      .post('/stages')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ code: `tenant-stage-${suffix}`, name: `Tenant Stage ${suffix}` });

    expect(createTenantStage.status).toBe(201);

    const createTenantGrade = await request(base)
      .post('/grades')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({
        stageId: createTenantStage.body.stage.id,
        code: `tenant-grade-${suffix}`,
        name: `Tenant Grade ${suffix}`,
        order: 7
      });

    expect(createTenantGrade.status).toBe(201);
    expect(createTenantGrade.body.grade.stageId).toBe(createTenantStage.body.stage.id);

    const createUnderSystemStage = await request(base)
      .post('/grades')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({
        stageId: primaryStage.id,
        code: `system-stage-grade-${suffix}`,
        name: `System Stage Grade ${suffix}`
      });

    expect(createUnderSystemStage.status).toBe(201);

    const tenantAList = await request(base)
      .get('/grades')
      .query({ stageId: createTenantStage.body.stage.id, sortBy: 'name', sortOrder: 'desc', limit: 1 })
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`);

    expect(tenantAList.status).toBe(200);
    expect(tenantAList.body.meta.limit).toBe(1);
    expect(tenantAList.body.meta.total).toBe(1);
    expect(tenantAList.body.grades[0].id).toBe(createTenantGrade.body.grade.id);

    const tenantBList = await request(base)
      .get('/grades')
      .query({ stageId: createTenantStage.body.stage.id })
      .set('X-Tenant-Code', tenantB.code)
      .set('Authorization', `Bearer ${token}`);

    expect(tenantBList.status).toBe(404);

    const crossTenantCreate = await request(base)
      .post('/grades')
      .set('X-Tenant-Code', tenantB.code)
      .set('Authorization', `Bearer ${token}`)
      .send({
        stageId: createTenantStage.body.stage.id,
        code: `cross-tenant-${suffix}`,
        name: `Cross Tenant ${suffix}`
      });

    expect(crossTenantCreate.status).toBe(404);

    const tenantAUnderSystemStage = await request(base)
      .get('/grades')
      .query({ stageId: primaryStage.id, offset: 0, limit: 100 })
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`);

    expect(tenantAUnderSystemStage.status).toBe(200);
    expect(tenantAUnderSystemStage.body.meta.total).toBeGreaterThan(systemGrades.body.grades.length);
    expect(tenantAUnderSystemStage.body.grades.some((grade: any) => grade.id === createUnderSystemStage.body.grade.id)).toBe(
      true
    );
  });

  it('validates create payloads', async () => {
    const suffix = Date.now();
    const tenant = { code: `grades-validation-${suffix}`, name: 'Grades Validation' };

    const login = await request(base).post('/auth/register').send({ username: `grades-validation-${suffix}` });
    const token = login.body.accessToken as string;

    await request(base).post('/tenants').send(tenant);
    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    const createGrade = await request(base)
      .post('/grades')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ code: `grade-${suffix}`, name: `Grade ${suffix}` });

    expect(createGrade.status).toBe(400);
    expect(createGrade.body.error.code).toBe('validation_failed');
    expect(createGrade.body.error.details).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ field: 'stageId', messages: expect.arrayContaining(['Missing stageId']) })
      ])
    );
  });
});

import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Chapters (e2e)', () => {
  it('creates and lists tenant chapters while enforcing textbook and parent constraints', async () => {
    const suffix = Date.now();
    const tenantA = { code: `chapters-a-${suffix}`, name: 'Chapters A' };
    const tenantB = { code: `chapters-b-${suffix}`, name: 'Chapters B' };

    const login = await request(base).post('/auth/register').send({ username: `chapters-user-${suffix}` });
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

    const createTenantTextbook = await request(base)
      .post('/textbooks')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ name: `Chapter Textbook ${suffix}` });

    expect(createTenantTextbook.status).toBe(201);
    const tenantTextbookId = createTenantTextbook.body.textbook.id as string;

    const systemTextbooks = await request(base)
      .get('/textbooks')
      .set('Authorization', `Bearer ${token}`);

    expect(systemTextbooks.status).toBe(200);
    const systemTextbookId = systemTextbooks.body.textbooks[0].id as string;

    const createRoot = await request(base)
      .post('/chapters')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ textbookId: systemTextbookId, name: `Root ${suffix}` });

    expect(createRoot.status).toBe(201);
    expect(createRoot.body.chapter.parentId).toBeNull();

    const createChild = await request(base)
      .post('/chapters')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({
        textbookId: systemTextbookId,
        parentId: createRoot.body.chapter.id,
        name: `Child ${suffix}`
      });

    expect(createChild.status).toBe(201);
    expect(createChild.body.chapter.parentId).toBe(createRoot.body.chapter.id);

    const wrongParentTextbook = await request(base)
      .post('/chapters')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({
        textbookId: tenantTextbookId,
        parentId: createRoot.body.chapter.id,
        name: `Wrong Parent ${suffix}`
      });

    expect(wrongParentTextbook.status).toBe(400);

    const tenantAList = await request(base)
      .get('/chapters')
      .query({ sortBy: 'name', sortOrder: 'asc', limit: 1 })
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`);

    expect(tenantAList.status).toBe(200);
    expect(tenantAList.body.meta.limit).toBe(1);
    expect(tenantAList.body.meta.total).toBe(2);
    expect(tenantAList.body.chapters).toHaveLength(1);
    expect([createRoot.body.chapter.id, createChild.body.chapter.id]).toContain(tenantAList.body.chapters[0].id);

    const filteredList = await request(base)
      .get('/chapters')
      .query({ textbookId: systemTextbookId, offset: 0, limit: 10 })
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`);

    expect(filteredList.status).toBe(200);
    expect(filteredList.body.meta.total).toBe(2);
    expect(filteredList.body.chapters.every((chapter: any) => chapter.textbookId === systemTextbookId)).toBe(true);

    const tenantBList = await request(base)
      .get('/chapters')
      .set('X-Tenant-Code', tenantB.code)
      .set('Authorization', `Bearer ${token}`);

    expect(tenantBList.status).toBe(200);
    expect(tenantBList.body.meta.total).toBe(0);
    expect(tenantBList.body.chapters.some((chapter: any) => chapter.id === createRoot.body.chapter.id)).toBe(false);

    const crossTenantTextbook = await request(base)
      .post('/chapters')
      .set('X-Tenant-Code', tenantB.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ textbookId: tenantTextbookId, name: `Cross Tenant ${suffix}` });

    expect(crossTenantTextbook.status).toBe(404);
  });

  it('validates create payloads', async () => {
    const suffix = Date.now();
    const tenant = { code: `chapters-validation-${suffix}`, name: 'Chapters Validation' };

    const login = await request(base).post('/auth/register').send({ username: `chapters-validation-${suffix}` });
    const token = login.body.accessToken as string;

    await request(base).post('/tenants').send(tenant);
    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    const createChapter = await request(base)
      .post('/chapters')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ name: `Chapter ${suffix}` });

    expect(createChapter.status).toBe(400);
    expect(createChapter.body.error.code).toBe('validation_failed');
    expect(createChapter.body.error.details).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ field: 'textbookId', messages: expect.arrayContaining(['Missing textbookId']) })
      ])
    );
  });
});

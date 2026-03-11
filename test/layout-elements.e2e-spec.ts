import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Layout elements (e2e)', () => {
  it('supports CRUD within a tenant and only handouts can include layout elements', async () => {
    const suffix = Date.now();
    const tenantA = { code: `layout-a-${suffix}`, name: 'Layout A' };
    const tenantB = { code: `layout-b-${suffix}`, name: 'Layout B' };

    const login = await request(base).post('/auth/register').send({ username: `layout-user-${suffix}` });
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

    const blocks = [{ type: 'paragraph', text: `Layout ${suffix}` }];

    const createLayout = await request(base)
      .post('/layout-elements')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ blocks });

    expect(createLayout.status).toBe(201);
    const layoutElementId = createLayout.body.layoutElement.id as string;

    const tenantAList = await request(base)
      .get('/layout-elements')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`);

    expect(tenantAList.status).toBe(200);
    expect(tenantAList.body.layoutElements.some((item: any) => item.id === layoutElementId)).toBe(true);
    expect(tenantAList.body.meta).toMatchObject({
      limit: 50,
      offset: 0,
      returned: 1,
      total: 1,
      hasMore: false,
      sortBy: 'createdAt',
      sortOrder: 'asc'
    });

    const tenantBList = await request(base)
      .get('/layout-elements')
      .set('X-Tenant-Code', tenantB.code)
      .set('Authorization', `Bearer ${token}`);

    expect(tenantBList.status).toBe(200);
    expect(tenantBList.body.layoutElements.some((item: any) => item.id === layoutElementId)).toBe(false);

    const getLayout = await request(base)
      .get(`/layout-elements/${layoutElementId}`)
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`);

    expect(getLayout.status).toBe(200);
    expect(getLayout.body.layoutElement.blocks).toEqual(blocks);

    const updatedBlocks = [{ type: 'paragraph', text: `Updated Layout ${suffix}` }];
    const updateLayout = await request(base)
      .patch(`/layout-elements/${layoutElementId}`)
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ blocks: updatedBlocks });

    expect(updateLayout.status).toBe(200);
    expect(updateLayout.body.layoutElement.blocks).toEqual(updatedBlocks);

    const createHandout = await request(base)
      .post('/documents')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ name: `Handout ${suffix}`, kind: 'handout' });

    expect(createHandout.status).toBe(201);

    const addLayoutToHandout = await request(base)
      .post(`/documents/${createHandout.body.document.id}/items`)
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ itemType: 'layout_element', layoutElementId });

    expect(addLayoutToHandout.status).toBe(201);

    const createPaper = await request(base)
      .post('/documents')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ name: `Paper ${suffix}`, kind: 'paper' });

    expect(createPaper.status).toBe(201);

    const addLayoutToPaper = await request(base)
      .post(`/documents/${createPaper.body.document.id}/items`)
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ itemType: 'layout_element', layoutElementId });

    expect(addLayoutToPaper.status).toBe(400);

    const deleteInUseLayout = await request(base)
      .delete(`/layout-elements/${layoutElementId}`)
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`);

    expect(deleteInUseLayout.status).toBe(400);

    const pagedLayouts = await request(base)
      .get('/layout-elements')
      .query({ sortBy: 'updatedAt', sortOrder: 'desc', offset: '0', limit: '1' })
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`);

    expect(pagedLayouts.status).toBe(200);
    expect(pagedLayouts.body.meta).toMatchObject({
      limit: 1,
      offset: 0,
      returned: 1,
      total: 1,
      hasMore: false,
      sortBy: 'updatedAt',
      sortOrder: 'desc'
    });
  });

  it('validates create and update payloads', async () => {
    const suffix = Date.now();
    const tenant = { code: `layout-validation-${suffix}`, name: 'Layout Validation' };

    const login = await request(base).post('/auth/register').send({ username: `layout-validation-${suffix}` });
    const token = login.body.accessToken as string;

    await request(base).post('/tenants').send(tenant);
    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    const createLayout = await request(base)
      .post('/layout-elements')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(createLayout.status).toBe(400);
    expect(createLayout.body.error.code).toBe('validation_failed');
    expect(createLayout.body.error.details).toEqual(
      expect.arrayContaining([expect.objectContaining({ field: 'blocks', messages: ['Missing blocks'] })])
    );

    const validLayout = await request(base)
      .post('/layout-elements')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ blocks: [{ type: 'paragraph', text: `Layout ${suffix}` }] });

    expect(validLayout.status).toBe(201);

    const updateLayout = await request(base)
      .patch(`/layout-elements/${validLayout.body.layoutElement.id}`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(updateLayout.status).toBe(400);
    expect(updateLayout.body.error.code).toBe('validation_failed');
    expect(updateLayout.body.error.details).toEqual(
      expect.arrayContaining([expect.objectContaining({ field: 'blocks', messages: ['Missing blocks'] })])
    );
  });

  it('validates id params', async () => {
    const suffix = Date.now();
    const tenant = { code: `layout-params-${suffix}`, name: 'Layout Params' };

    const login = await request(base).post('/auth/register').send({ username: `layout-params-${suffix}` });
    expect(login.status).toBe(201);
    const token = login.body.accessToken as string;

    await request(base).post('/tenants').send(tenant);
    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    const invalidGet = await request(base)
      .get('/layout-elements/not-a-uuid')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(invalidGet.status).toBe(400);
    expect(invalidGet.body.error.code).toBe('validation_failed');
    expect(invalidGet.body.error.details).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ field: 'id', messages: expect.arrayContaining(['Invalid id']) })
      ])
    );
  });
});

import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Assets (e2e)', () => {
  it('validates asset upload payloads', async () => {
    const suffix = Date.now();
    const tenant = { code: `asset-validate-${suffix}`, name: 'Asset Validate' };

    const login = await request(base).post('/auth/register').send({ username: `asset-validate-${suffix}` });
    expect(login.status).toBe(201);
    const token = login.body.accessToken as string;

    await request(base).post('/tenants').send(tenant);
    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    const invalidUpload = await request(base)
      .post('/assets/upload')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({
        filename: 'bad.png',
        mime: 'image/png',
        size: 0
      });

    expect(invalidUpload.status).toBe(400);
    expect(invalidUpload.body.message).toContain('Invalid size');
    expect(invalidUpload.body.error.code).toBe('validation_failed');
    expect(invalidUpload.body.error.details[0].field).toBe('size');
  });

  it('rate limits upload creation by client ip', async () => {
    const suffix = Date.now();
    const tenant = { code: `asset-rate-${suffix}`, name: 'Asset Rate Limit' };
    const ip = `203.0.113.${(suffix % 200) + 1}`;

    const login = await request(base).post('/auth/register').send({ username: `asset-rate-${suffix}` });
    expect(login.status).toBe(201);
    const token = login.body.accessToken as string;

    await request(base).post('/tenants').send(tenant);
    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    for (let index = 0; index < 10; index += 1) {
      const upload = await request(base)
        .post('/assets/upload')
        .set('X-Test-Rate-Limit', 'on')
        .set('X-Forwarded-For', ip)
        .set('X-Tenant-Code', tenant.code)
        .set('Authorization', `Bearer ${token}`)
        .send({
          filename: `rate-${index}.png`,
          mime: 'image/png',
          size: 100 + index,
          kind: 'image'
        });

      expect(upload.status).toBe(201);
    }

    const limited = await request(base)
      .post('/assets/upload')
      .set('X-Test-Rate-Limit', 'on')
      .set('X-Forwarded-For', ip)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({
        filename: 'rate-blocked.png',
        mime: 'image/png',
        size: 999,
        kind: 'image'
      });

    expect(limited.status).toBe(429);
    expect(limited.body.error.code).toBe('too_many_requests');
    expect(String(limited.body.message)).toContain('Rate limit exceeded');
  });

  it('validates id params', async () => {
    const suffix = Date.now();
    const tenant = { code: `asset-params-${suffix}`, name: 'Asset Params' };

    const login = await request(base).post('/auth/register').send({ username: `asset-params-${suffix}` });
    expect(login.status).toBe(201);
    const token = login.body.accessToken as string;

    await request(base).post('/tenants').send(tenant);
    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    const invalidGet = await request(base)
      .get('/assets/not-a-uuid')
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

  it('creates upload URLs, stores asset metadata, enforces delete rules, and isolates assets by tenant', async () => {
    const suffix = Date.now();
    const tenantA = { code: `asset-a-${suffix}`, name: 'Asset A' };
    const tenantB = { code: `asset-b-${suffix}`, name: 'Asset B' };

    const login = await request(base).post('/auth/register').send({ username: `asset-user-${suffix}` });
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

    const createUpload = await request(base)
      .post('/assets/upload')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({
        filename: 'figure.png',
        mime: 'image/png',
        size: 12345,
        kind: 'image',
        width: 1200,
        height: 800
      });

    expect(createUpload.status).toBe(201);
    expect(createUpload.body.asset.mime).toBe('image/png');
    expect(createUpload.body.asset.size).toBe(12345);
    expect(createUpload.body.asset.originalFilename).toBe('figure.png');
    expect(typeof createUpload.body.upload.url).toBe('string');
    expect(createUpload.body.upload.method).toBe('PUT');

    const assetId = createUpload.body.asset.id as string;

    const tenantAList = await request(base)
      .get('/assets')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`);

    expect(tenantAList.status).toBe(200);
    expect(tenantAList.body.assets.some((asset: any) => asset.id === assetId)).toBe(true);
    expect(tenantAList.body.meta).toMatchObject({
      limit: 50,
      offset: 0,
      returned: 1,
      total: 1,
      hasMore: false,
      sortBy: 'createdAt',
      sortOrder: 'desc'
    });

    const getAsset = await request(base)
      .get(`/assets/${assetId}`)
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`);

    expect(getAsset.status).toBe(200);
    expect(getAsset.body.asset.storageKey).toContain(createUpload.body.asset.tenantId);
    expect(getAsset.body.asset.originalFilename).toBe('figure.png');

    const tenantBList = await request(base)
      .get('/assets')
      .set('X-Tenant-Code', tenantB.code)
      .set('Authorization', `Bearer ${token}`);

    expect(tenantBList.status).toBe(200);
    expect(tenantBList.body.assets.some((asset: any) => asset.id === assetId)).toBe(false);

    const tenantBGet = await request(base)
      .get(`/assets/${assetId}`)
      .set('X-Tenant-Code', tenantB.code)
      .set('Authorization', `Bearer ${token}`);

    expect(tenantBGet.status).toBe(404);

    const createQuestion = await request(base)
      .post('/questions')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(createQuestion.status).toBe(201);

    const questionId = createQuestion.body.question.id as string;

    const setContent = await request(base)
      .put(`/questions/${questionId}/content`)
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({
        stemBlocks: [{ type: 'paragraph', children: [{ text: '图像题干', assetId }] }]
      });

    expect(setContent.status).toBe(200);

    const deleteReferenced = await request(base)
      .delete(`/assets/${assetId}`)
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`);

    expect(deleteReferenced.status).toBe(400);
    expect(String(deleteReferenced.body.message || '')).toContain('question content');

    const createUpload2 = await request(base)
      .post('/assets/upload')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({
        filename: 'unused.png',
        mime: 'image/png',
        size: 100,
        kind: 'image'
      });

    expect(createUpload2.status).toBe(201);
    const unusedAssetId = createUpload2.body.asset.id as string;

    const deleteUnused = await request(base)
      .delete(`/assets/${unusedAssetId}`)
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`);

    expect(deleteUnused.status).toBe(200);

    const getDeleted = await request(base)
      .get(`/assets/${unusedAssetId}`)
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`);

    expect(getDeleted.status).toBe(404);

    const sortedAssets = await request(base)
      .get('/assets')
      .query({ sortBy: 'size', sortOrder: 'asc', offset: '0', limit: '1' })
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`);

    expect(sortedAssets.status).toBe(200);
    expect(sortedAssets.body.meta).toMatchObject({
      limit: 1,
      offset: 0,
      returned: 1,
      total: 1,
      hasMore: false,
      sortBy: 'size',
      sortOrder: 'asc'
    });
  });

  it('cleans up orphaned stale assets without deleting referenced ones', async () => {
    const suffix = Date.now();
    const tenant = { code: `asset-cleanup-${suffix}`, name: 'Asset Cleanup' };

    const login = await request(base).post('/auth/register').send({ username: `asset-cleanup-${suffix}` });
    expect(login.status).toBe(201);
    const token = login.body.accessToken as string;

    await request(base).post('/tenants').send(tenant);
    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    const referencedUpload = await request(base)
      .post('/assets/upload')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({
        filename: 'referenced.png',
        mime: 'image/png',
        size: 120,
        kind: 'image'
      });

    const orphanUpload = await request(base)
      .post('/assets/upload')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({
        filename: 'orphan.png',
        mime: 'image/png',
        size: 110,
        kind: 'image'
      });

    expect(referencedUpload.status).toBe(201);
    expect(orphanUpload.status).toBe(201);

    const referencedAssetId = referencedUpload.body.asset.id as string;
    const orphanAssetId = orphanUpload.body.asset.id as string;

    const createQuestion = await request(base)
      .post('/questions')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(createQuestion.status).toBe(201);

    const setContent = await request(base)
      .put(`/questions/${createQuestion.body.question.id}/content`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({
        stemBlocks: [{ type: 'paragraph', children: [{ text: '保留这张图', assetId: referencedAssetId }] }]
      });

    expect(setContent.status).toBe(200);

    const cleanup = await request(base)
      .post('/assets/cleanup')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ staleHours: 0 });

    expect(cleanup.status).toBe(201);
    expect(cleanup.body.cleanup.deletedAssets).toBe(1);

    const getReferenced = await request(base)
      .get(`/assets/${referencedAssetId}`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(getReferenced.status).toBe(200);

    const getDeleted = await request(base)
      .get(`/assets/${orphanAssetId}`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(getDeleted.status).toBe(404);
  });
});

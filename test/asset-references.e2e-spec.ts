import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Asset references (e2e)', () => {
  it('allows same-tenant asset references and rejects cross-tenant asset references', async () => {
    const suffix = Date.now();
    const tenantA = { code: `asset-ref-a-${suffix}`, name: 'Asset Ref A' };
    const tenantB = { code: `asset-ref-b-${suffix}`, name: 'Asset Ref B' };

    const login = await request(base).post('/auth/register').send({ username: `asset-ref-user-${suffix}` });
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

    const assetA = await request(base)
      .post('/assets/upload')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ filename: 'a.png', mime: 'image/png', size: 100 });
    expect(assetA.status).toBe(201);

    const assetB = await request(base)
      .post('/assets/upload')
      .set('X-Tenant-Code', tenantB.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ filename: 'b.png', mime: 'image/png', size: 100 });
    expect(assetB.status).toBe(201);

    const createQuestion = await request(base)
      .post('/questions')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({});
    expect(createQuestion.status).toBe(201);
    const questionId = createQuestion.body.question.id as string;

    const sameTenantContent = await request(base)
      .put(`/questions/${questionId}/content`)
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ stemBlocks: [{ type: 'image', assetId: assetA.body.asset.id }] });

    expect(sameTenantContent.status).toBe(200);

    const crossTenantContent = await request(base)
      .put(`/questions/${questionId}/content`)
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ stemBlocks: [{ type: 'image', assetId: assetB.body.asset.id }] });

    expect(crossTenantContent.status).toBe(400);

    const sameTenantLayout = await request(base)
      .post('/layout-elements')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ blocks: [{ type: 'image', assetId: assetA.body.asset.id }] });

    expect(sameTenantLayout.status).toBe(201);

    const crossTenantLayout = await request(base)
      .post('/layout-elements')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ blocks: [{ type: 'image', assetId: assetB.body.asset.id }] });

    expect(crossTenantLayout.status).toBe(400);

    const imported = await request(base)
      .post('/questions/import')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({
        items: [{ type: 'single_choice', content: { stemBlocks: [{ type: 'image', assetId: assetA.body.asset.id }] } }]
      });

    expect(imported.status).toBe(201);

    const importedBad = await request(base)
      .post('/questions/import')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({
        items: [{ type: 'single_choice', content: { stemBlocks: [{ type: 'image', assetId: assetB.body.asset.id }] } }]
      });

    expect(importedBad.status).toBe(400);
  });
});

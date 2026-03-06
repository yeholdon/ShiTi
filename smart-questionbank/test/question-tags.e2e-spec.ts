import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Question tags (e2e)', () => {
  it('supports CRUD within a tenant and hides tags from other tenants', async () => {
    const suffix = Date.now();
    const tenantA = { code: `tags-a-${suffix}`, name: 'Tags A' };
    const tenantB = { code: `tags-b-${suffix}`, name: 'Tags B' };
    const tagName = `Geometry ${suffix}`;

    const login = await request(base).post('/auth/register').send({ username: `tags-user-${suffix}` });
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

    const createTag = await request(base)
      .post('/question-tags')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ name: tagName });

    expect(createTag.status).toBe(201);
    expect(createTag.body.tag.name).toBe(tagName);

    const tenantAList = await request(base)
      .get('/question-tags')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`);

    expect(tenantAList.status).toBe(200);
    expect(tenantAList.body.tags.some((tag: any) => tag.id === createTag.body.tag.id)).toBe(true);

    const tenantBList = await request(base)
      .get('/question-tags')
      .set('X-Tenant-Code', tenantB.code)
      .set('Authorization', `Bearer ${token}`);

    expect(tenantBList.status).toBe(200);
    expect(tenantBList.body.tags.some((tag: any) => tag.id === createTag.body.tag.id)).toBe(false);

    const crossTenantDelete = await request(base)
      .delete(`/question-tags/${createTag.body.tag.id}`)
      .set('X-Tenant-Code', tenantB.code)
      .set('Authorization', `Bearer ${token}`);

    expect(crossTenantDelete.status).toBe(404);

    const removeTag = await request(base)
      .delete(`/question-tags/${createTag.body.tag.id}`)
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`);

    expect(removeTag.status).toBe(200);
    expect(removeTag.body).toEqual({ ok: true });

    const tenantAListAfterDelete = await request(base)
      .get('/question-tags')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`);

    expect(tenantAListAfterDelete.status).toBe(200);
    expect(tenantAListAfterDelete.body.tags.some((tag: any) => tag.id === createTag.body.tag.id)).toBe(false);
  });
});

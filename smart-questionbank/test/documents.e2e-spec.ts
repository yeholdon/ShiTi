import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Documents (e2e)', () => {
  it('register -> join tenant -> create document -> list -> get -> add item -> reorder -> update -> delete', async () => {
    const suffix = Date.now();
    const tenant = { code: `doc-tenant-${suffix}`, name: 'Doc Tenant' };

    await request(base).post('/tenants').send(tenant);

    const reg = await request(base).post('/auth/register').send({ username: `user-doc-${suffix}` });
    expect(reg.status).toBe(201);
    const token = reg.body.accessToken;

    const join = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'owner' });
    expect(join.status).toBe(201);

    const created = await request(base)
      .post('/documents')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ name: 'My Paper', kind: 'paper' });

    expect(created.status).toBe(201);
    const documentId = created.body.document.id;

    const list = await request(base)
      .get('/documents')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(list.status).toBe(200);
    expect(Array.isArray(list.body.documents)).toBe(true);

    const get = await request(base)
      .get(`/documents/${documentId}`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(get.status).toBe(200);
    expect(get.body.document.id).toBe(documentId);
    expect(Array.isArray(get.body.items)).toBe(true);

    const createdQuestion = await request(base)
      .post('/questions')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(createdQuestion.status).toBe(201);

    const addItem = await request(base)
      .post(`/documents/${documentId}/items`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ itemType: 'question', questionId: createdQuestion.body.question.id });

    expect(addItem.status).toBe(201);
    const itemId = addItem.body.item.id;

    const addItem2 = await request(base)
      .post(`/documents/${documentId}/items`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ itemType: 'question', questionId: createdQuestion.body.question.id });

    expect(addItem2.status).toBe(201);
    const itemId2 = addItem2.body.item.id;

    const reorder = await request(base)
      .patch(`/documents/${documentId}/items/reorder`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ items: [{ id: itemId, orderIndex: 1 }, { id: itemId2, orderIndex: 0 }] });

    expect(reorder.status).toBe(200);

    const get2 = await request(base)
      .get(`/documents/${documentId}`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(get2.status).toBe(200);
    expect(get2.body.items.map((i: any) => i.id)).toEqual([itemId2, itemId]);

    const updated = await request(base)
      .patch(`/documents/${documentId}`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ name: 'My Paper v2' });

    expect(updated.status).toBe(200);
    expect(updated.body.document.name).toBe('My Paper v2');

    const deleted = await request(base)
      .delete(`/documents/${documentId}`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(deleted.status).toBe(200);

    const getAfter = await request(base)
      .get(`/documents/${documentId}`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(getAfter.status).toBe(404);
  });
});

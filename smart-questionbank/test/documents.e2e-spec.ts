import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Documents (e2e)', () => {
  it('validates document payloads', async () => {
    const suffix = Date.now();
    const tenant = { code: `doc-validate-${suffix}`, name: 'Doc Validate' };

    await request(base).post('/tenants').send(tenant);

    const reg = await request(base).post('/auth/register').send({ username: `user-doc-validate-${suffix}` });
    expect(reg.status).toBe(201);
    const token = reg.body.accessToken;

    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    const created = await request(base)
      .post('/documents')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(created.status).toBe(400);
    expect(created.body.message).toContain('Missing name');
    expect(created.body.error.code).toBe('validation_failed');
  });

  it('validates id params', async () => {
    const suffix = Date.now();
    const tenant = { code: `doc-params-${suffix}`, name: 'Doc Params' };

    await request(base).post('/tenants').send(tenant);

    const reg = await request(base).post('/auth/register').send({ username: `user-doc-params-${suffix}` });
    expect(reg.status).toBe(201);
    const token = reg.body.accessToken;

    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    const getInvalid = await request(base)
      .get('/documents/not-a-uuid')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(getInvalid.status).toBe(400);
    expect(getInvalid.body.error.code).toBe('validation_failed');
    expect(getInvalid.body.error.details).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ field: 'id', messages: expect.arrayContaining(['Invalid id']) })
      ])
    );

    const removeInvalidItem = await request(base)
      .delete('/documents/not-a-uuid/items/also-bad')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(removeInvalidItem.status).toBe(400);
    expect(removeInvalidItem.body.error.code).toBe('validation_failed');
    expect(removeInvalidItem.body.error.details).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ field: 'id', messages: expect.arrayContaining(['Invalid id']) }),
        expect.objectContaining({ field: 'itemId', messages: expect.arrayContaining(['Invalid itemId']) })
      ])
    );
  });

  it('register -> join tenant -> create document -> list -> get -> add item -> reorder -> remove item -> update -> delete', async () => {
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
    expect(list.body.documents.some((document: any) => document.id === documentId)).toBe(true);
    expect(list.body.meta).toMatchObject({
      limit: 50,
      offset: 0,
      returned: 1,
      total: 1,
      hasMore: false,
      sortBy: 'createdAt',
      sortOrder: 'desc'
    });

    const createdHandout = await request(base)
      .post('/documents')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ name: 'Worksheet Draft', kind: 'handout' });

    expect(createdHandout.status).toBe(201);

    const filterByName = await request(base)
      .get('/documents')
      .query({ q: 'worksheet' })
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(filterByName.status).toBe(200);
    expect(filterByName.body.documents.map((document: any) => document.name)).toEqual(['Worksheet Draft']);

    const filterByKind = await request(base)
      .get('/documents')
      .query({ kind: 'paper', limit: '1' })
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(filterByKind.status).toBe(200);
    expect(filterByKind.body.documents).toHaveLength(1);
    expect(filterByKind.body.documents[0].kind).toBe('paper');
    expect(filterByKind.body.meta).toMatchObject({
      limit: 1,
      offset: 0,
      returned: 1,
      total: 1,
      hasMore: false,
      sortBy: 'createdAt',
      sortOrder: 'desc'
    });

    const offsetAndSort = await request(base)
      .get('/documents')
      .query({ sortBy: 'name', sortOrder: 'asc', offset: '1', limit: '1' })
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(offsetAndSort.status).toBe(200);
    expect(offsetAndSort.body.documents).toHaveLength(1);
    expect(offsetAndSort.body.documents[0].name).toBe('Worksheet Draft');
    expect(offsetAndSort.body.meta).toMatchObject({
      limit: 1,
      offset: 1,
      returned: 1,
      total: 2,
      hasMore: false,
      sortBy: 'name',
      sortOrder: 'asc'
    });

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
    const questionId = createdQuestion.body.question.id as string;

    const patchQuestion = await request(base)
      .patch(`/questions/${questionId}`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ type: 'solution', difficulty: 4 });

    expect(patchQuestion.status).toBe(200);

    const createdQuestion2 = await request(base)
      .post('/questions')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(createdQuestion2.status).toBe(201);
    const questionId2 = createdQuestion2.body.question.id as string;

    const patchQuestion2 = await request(base)
      .patch(`/questions/${questionId2}`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ type: 'fill_blank', difficulty: 2 });

    expect(patchQuestion2.status).toBe(200);

    const addItem = await request(base)
      .post(`/documents/${documentId}/items`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ itemType: 'question', questionId });

    expect(addItem.status).toBe(201);
    const itemId = addItem.body.item.id;

    const addItem2 = await request(base)
      .post(`/documents/${documentId}/items`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ itemType: 'question', questionId: questionId2 });

    expect(addItem2.status).toBe(201);
    const itemId2 = addItem2.body.item.id;

    const bulkDoc = await request(base)
      .post('/documents')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ name: 'Bulk Worksheet', kind: 'handout' });

    expect(bulkDoc.status).toBe(201);
    const bulkDocumentId = bulkDoc.body.document.id as string;

    const bulkAdd = await request(base)
      .post(`/documents/${bulkDocumentId}/items/bulk`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({
        items: [
          { itemType: 'question', questionId },
          { itemType: 'question', questionId: questionId2 }
        ]
      });

    expect(bulkAdd.status).toBe(201);
    expect(bulkAdd.body.items).toHaveLength(2);

    const bulkGet = await request(base)
      .get(`/documents/${bulkDocumentId}`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(bulkGet.status).toBe(200);
    expect(bulkGet.body.items).toHaveLength(2);
    expect(bulkGet.body.items.map((item: any) => item.orderIndex)).toEqual([0, 1]);

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
    expect(get2.body.document.stats).toEqual({
      totalQuestions: 2,
      avgDifficulty: 3,
      perTypeCounts: { fill_blank: 1, solution: 1 }
    });
    expect(get2.body.document.summary).toEqual({
      totalItems: 2,
      questionItems: 2,
      layoutItems: 0,
      latestExportJob: null
    });

    const removeItem = await request(base)
      .delete(`/documents/${documentId}/items/${itemId2}`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(removeItem.status).toBe(200);

    const get3 = await request(base)
      .get(`/documents/${documentId}`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(get3.status).toBe(200);
    expect(get3.body.items).toHaveLength(1);
    expect(get3.body.items[0].id).toBe(itemId);
    expect(get3.body.items[0].orderIndex).toBe(0);
    expect(get3.body.document.stats).toEqual({
      totalQuestions: 1,
      avgDifficulty: 4,
      perTypeCounts: { solution: 1 }
    });
    expect(get3.body.document.summary).toEqual({
      totalItems: 1,
      questionItems: 1,
      layoutItems: 0,
      latestExportJob: null
    });

    const listWithStats = await request(base)
      .get('/documents')
      .query({ kind: 'paper' })
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(listWithStats.status).toBe(200);
    const listedDocument = listWithStats.body.documents.find((document: any) => document.id === documentId);
    expect(listedDocument?.stats).toEqual({
      totalQuestions: 1,
      avgDifficulty: 4,
      perTypeCounts: { solution: 1 }
    });
    expect(listedDocument?.summary).toEqual({
      totalItems: 1,
      questionItems: 1,
      layoutItems: 0,
      latestExportJob: null
    });

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

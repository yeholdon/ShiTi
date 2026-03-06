import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Multi-tenant hard isolation (e2e)', () => {
  it('rejects referencing another tenant subject when creating questions', async () => {
    const suffix = Date.now();
    const tenantA = { code: `iso-a-${suffix}`, name: 'Isolation A' };
    const tenantB = { code: `iso-b-${suffix}`, name: 'Isolation B' };

    await request(base).post('/tenants').send(tenantA);
    await request(base).post('/tenants').send(tenantB);

    const reg = await request(base).post('/auth/register').send({ username: `iso-user-${suffix}` });
    expect(reg.status).toBe(201);
    const token = reg.body.accessToken;

    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenantA.code, role: 'owner' });

    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenantB.code, role: 'owner' });

    const bSubject = await request(base)
      .post('/subjects')
      .set('X-Tenant-Code', tenantB.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ name: `TenantB Subject ${suffix}` });

    expect(bSubject.status).toBe(201);
    const tenantBSubjectId = bSubject.body.subject.id;

    const badCreate = await request(base)
      .post('/questions')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ subjectId: tenantBSubjectId });

    expect(badCreate.status).toBe(400);
    expect(String(badCreate.body.message || '')).toContain('Invalid subjectId');
  });

  it('cannot read another tenant export job even when same user belongs to both tenants', async () => {
    const suffix = Date.now();
    const tenantA = { code: `iso-export-a-${suffix}`, name: 'Export A' };
    const tenantB = { code: `iso-export-b-${suffix}`, name: 'Export B' };

    await request(base).post('/tenants').send(tenantA);
    await request(base).post('/tenants').send(tenantB);

    const reg = await request(base).post('/auth/register').send({ username: `iso-export-user-${suffix}` });
    expect(reg.status).toBe(201);
    const token = reg.body.accessToken;

    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenantA.code, role: 'owner' });

    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenantB.code, role: 'owner' });

    const createdDoc = await request(base)
      .post('/documents')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ name: 'Isolation Export Doc', kind: 'paper' });

    expect(createdDoc.status).toBe(201);
    const documentId = createdDoc.body.document.id;

    const createdJob = await request(base)
      .post('/export-jobs')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ documentId });

    expect(createdJob.status).toBe(201);
    const exportJobId = createdJob.body.job.id;

    const start = Date.now();
    // wait until terminal state before cross-tenant read checks
    while (Date.now() - start < 3000) {
      const get = await request(base)
        .get(`/export-jobs/${exportJobId}`)
        .set('X-Tenant-Code', tenantA.code)
        .set('Authorization', `Bearer ${token}`);

      expect(get.status).toBe(200);
      if (get.body.job.status === 'succeeded' || get.body.job.status === 'failed') break;
      await new Promise((r) => setTimeout(r, 100));
    }

    const wrongTenantGet = await request(base)
      .get(`/export-jobs/${exportJobId}`)
      .set('X-Tenant-Code', tenantB.code)
      .set('Authorization', `Bearer ${token}`);
    expect(wrongTenantGet.status).toBe(404);

    const wrongTenantResult = await request(base)
      .get(`/export-jobs/${exportJobId}/result`)
      .set('X-Tenant-Code', tenantB.code)
      .set('Authorization', `Bearer ${token}`);
    expect(wrongTenantResult.status).toBe(404);
  });

  it('rejects using another tenant subject in import and patch flows', async () => {
    const suffix = Date.now();
    const tenantA = { code: `iso-subject-a-${suffix}`, name: 'Subject A' };
    const tenantB = { code: `iso-subject-b-${suffix}`, name: 'Subject B' };

    await request(base).post('/tenants').send(tenantA);
    await request(base).post('/tenants').send(tenantB);

    const reg = await request(base).post('/auth/register').send({ username: `iso-subject-user-${suffix}` });
    expect(reg.status).toBe(201);
    const token = reg.body.accessToken;

    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenantA.code, role: 'owner' });

    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenantB.code, role: 'owner' });

    const bSubject = await request(base)
      .post('/subjects')
      .set('X-Tenant-Code', tenantB.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ name: `TenantB Subject for Patch ${suffix}` });
    expect(bSubject.status).toBe(201);
    const tenantBSubjectId = bSubject.body.subject.id;

    const imported = await request(base)
      .post('/questions/import')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({
        items: [{ type: 'single_choice', subjectId: tenantBSubjectId, content: { stemBlocks: [{ type: 'text', text: 'x?' }] } }]
      });
    expect(imported.status).toBe(400);
    expect(String(imported.body.message || '')).toContain('Invalid subjectId');

    const createdQuestion = await request(base)
      .post('/questions')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({});
    expect(createdQuestion.status).toBe(201);
    const questionId = createdQuestion.body.question.id;

    const patched = await request(base)
      .patch(`/questions/${questionId}`)
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ subjectId: tenantBSubjectId });
    expect(patched.status).toBe(400);
    expect(String(patched.body.message || '')).toContain('Invalid subjectId');
  });

  it('rejects attaching another tenant question into document items', async () => {
    const suffix = Date.now();
    const tenantA = { code: `iso-doc-a-${suffix}`, name: 'Doc A' };
    const tenantB = { code: `iso-doc-b-${suffix}`, name: 'Doc B' };

    await request(base).post('/tenants').send(tenantA);
    await request(base).post('/tenants').send(tenantB);

    const reg = await request(base).post('/auth/register').send({ username: `iso-doc-user-${suffix}` });
    expect(reg.status).toBe(201);
    const token = reg.body.accessToken;

    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenantA.code, role: 'owner' });

    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenantB.code, role: 'owner' });

    const aDocument = await request(base)
      .post('/documents')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ name: 'Tenant A Doc', kind: 'paper' });
    expect(aDocument.status).toBe(201);
    const documentId = aDocument.body.document.id;

    const bQuestion = await request(base)
      .post('/questions')
      .set('X-Tenant-Code', tenantB.code)
      .set('Authorization', `Bearer ${token}`)
      .send({});
    expect(bQuestion.status).toBe(201);
    const questionId = bQuestion.body.question.id;

    const badAttach = await request(base)
      .post(`/documents/${documentId}/items`)
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ itemType: 'question', questionId });
    expect(badAttach.status).toBe(400);
    expect(String(badAttach.body.message || '')).toContain('Question not found');
  });
});

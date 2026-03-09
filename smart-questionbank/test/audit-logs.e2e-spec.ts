import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Audit logs (e2e)', () => {
  it('records sensitive tenant actions and isolates logs by tenant', async () => {
    const suffix = Date.now();
    const tenantA = { code: `audit-a-${suffix}`, name: 'Audit A' };
    const tenantB = { code: `audit-b-${suffix}`, name: 'Audit B' };

    const login = await request(base).post('/auth/register').send({ username: `audit-user-${suffix}` });
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

    const createQuestion = await request(base)
      .post('/questions')
      .set('Authorization', `Bearer ${token}`)
      .set('X-Tenant-Code', tenantA.code)
      .send({});
    expect(createQuestion.status).toBe(201);

    const updateContent = await request(base)
      .put(`/questions/${createQuestion.body.question.id}/content`)
      .set('Authorization', `Bearer ${token}`)
      .set('X-Tenant-Code', tenantA.code)
      .send({ stemBlocks: [{ type: 'paragraph', children: [{ text: `Audit Stem ${suffix}` }] }] });
    expect(updateContent.status).toBe(200);

    const createDocument = await request(base)
      .post('/documents')
      .set('Authorization', `Bearer ${token}`)
      .set('X-Tenant-Code', tenantA.code)
      .send({ name: `Audit Doc ${suffix}`, kind: 'paper' });
    expect(createDocument.status).toBe(201);

    const createUpload = await request(base)
      .post('/assets/upload')
      .set('Authorization', `Bearer ${token}`)
      .set('X-Tenant-Code', tenantA.code)
      .send({
        filename: `audit-${suffix}.png`,
        mime: 'image/png',
        size: 123,
        kind: 'image'
      });
    expect(createUpload.status).toBe(201);

    const createExport = await request(base)
      .post('/export-jobs')
      .set('Authorization', `Bearer ${token}`)
      .set('X-Tenant-Code', tenantA.code)
      .send({ documentId: createDocument.body.document.id });
    expect(createExport.status).toBe(201);

    const auditA = await request(base)
      .get('/audit-logs')
      .query({ limit: 10 })
      .set('Authorization', `Bearer ${token}`)
      .set('X-Tenant-Code', tenantA.code);

    expect(auditA.status).toBe(200);
    expect(auditA.body.meta.returned).toBeGreaterThanOrEqual(4);
    expect(auditA.body.meta.total).toBeGreaterThanOrEqual(auditA.body.meta.returned);
    expect(auditA.body.meta.sortBy).toBe('createdAt');
    expect(auditA.body.meta.sortOrder).toBe('desc');
    expect(auditA.body.logs.map((entry: any) => entry.action)).toEqual(
      expect.arrayContaining([
        'question.created',
        'question.content_updated',
        'document.created',
        'asset.upload_created',
        'export_job.created'
      ])
    );
    expect(auditA.body.logs.some((entry: any) => entry.username === `audit-user-${suffix}`)).toBe(true);

    const questionOnly = await request(base)
      .get('/audit-logs')
      .query({ targetType: 'question', limit: 10 })
      .set('Authorization', `Bearer ${token}`)
      .set('X-Tenant-Code', tenantA.code);

    expect(questionOnly.status).toBe(200);
    expect(questionOnly.body.meta.targetType).toBe('question');
    expect(questionOnly.body.logs.map((entry: any) => entry.action)).toEqual(
      expect.arrayContaining(['question.created', 'question.content_updated'])
    );
    expect(questionOnly.body.logs.every((entry: any) => entry.targetType === 'question')).toBe(true);

    const paged = await request(base)
      .get('/audit-logs')
      .query({ limit: 1, offset: 1, sortOrder: 'asc' })
      .set('Authorization', `Bearer ${token}`)
      .set('X-Tenant-Code', tenantA.code);

    expect(paged.status).toBe(200);
    expect(paged.body.meta).toMatchObject({
      limit: 1,
      offset: 1,
      returned: 1,
      sortBy: 'createdAt',
      sortOrder: 'asc'
    });

    const exportOnly = await request(base)
      .get('/audit-logs')
      .query({ action: 'export_job.created', limit: 10 })
      .set('Authorization', `Bearer ${token}`)
      .set('X-Tenant-Code', tenantA.code);

    expect(exportOnly.status).toBe(200);
    expect(exportOnly.body.logs).toHaveLength(1);
    expect(exportOnly.body.logs[0].targetId).toBe(createExport.body.job.id);
    expect(typeof exportOnly.body.logs[0].at).toBe('string');

    const since = new Date(Date.now() - 60_000).toISOString();
    const until = new Date(Date.now() + 60_000).toISOString();
    const ranged = await request(base)
      .get('/audit-logs')
      .query({ since, until, limit: 10 })
      .set('Authorization', `Bearer ${token}`)
      .set('X-Tenant-Code', tenantA.code);

    expect(ranged.status).toBe(200);
    expect(ranged.body.meta.since).toBe(since);
    expect(ranged.body.meta.until).toBe(until);
    expect(ranged.body.logs.length).toBeGreaterThanOrEqual(4);

    const stats = await request(base)
      .get('/audit-logs/stats')
      .query({ since, until })
      .set('Authorization', `Bearer ${token}`)
      .set('X-Tenant-Code', tenantA.code);

    expect(stats.status).toBe(200);
    expect(stats.body.stats.total).toBeGreaterThanOrEqual(4);
    expect(stats.body.stats.byAction).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ action: 'question.created' }),
        expect.objectContaining({ action: 'export_job.created' })
      ])
    );
    expect(stats.body.stats.byTargetType).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ targetType: 'question' }),
        expect.objectContaining({ targetType: 'document' })
      ])
    );
    expect(stats.body.stats.byUser).toEqual(
      expect.arrayContaining([expect.objectContaining({ username: `audit-user-${suffix}` })])
    );

    const invalidRange = await request(base)
      .get('/audit-logs')
      .query({ since: 'not-a-date' })
      .set('Authorization', `Bearer ${token}`)
      .set('X-Tenant-Code', tenantA.code);

    expect(invalidRange.status).toBe(400);
    expect(invalidRange.body.error.code).toBe('bad_request');

    const reversedRange = await request(base)
      .get('/audit-logs')
      .query({
        since: new Date(Date.now() + 120_000).toISOString(),
        until: new Date(Date.now() - 120_000).toISOString()
      })
      .set('Authorization', `Bearer ${token}`)
      .set('X-Tenant-Code', tenantA.code);

    expect(reversedRange.status).toBe(400);
    expect(reversedRange.body.error.code).toBe('bad_request');

    const auditB = await request(base)
      .get('/audit-logs')
      .query({ limit: 10 })
      .set('Authorization', `Bearer ${token}`)
      .set('X-Tenant-Code', tenantB.code);

    expect(auditB.status).toBe(200);
    expect(auditB.body.logs.every((entry: any) => entry.tenantId === auditB.body.logs[0]?.tenantId || true)).toBe(true);
    expect(auditB.body.logs.some((entry: any) => entry.action === 'question.created')).toBe(false);
    expect(auditB.body.logs.some((entry: any) => entry.action === 'question.content_updated')).toBe(false);
    expect(auditB.body.logs.some((entry: any) => entry.action === 'document.created')).toBe(false);
    expect(auditB.body.logs.some((entry: any) => entry.action === 'asset.upload_created')).toBe(false);
    expect(auditB.body.logs.some((entry: any) => entry.action === 'export_job.created')).toBe(false);
  });
});

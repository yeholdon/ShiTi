import request from 'supertest';
import { Queue } from 'bullmq';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';
const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379';

function parseRedisUrl(urlString: string) {
  const url = new URL(urlString);
  return {
    host: url.hostname,
    port: url.port ? Number(url.port) : 6379,
    password: url.password || undefined,
    db: url.pathname && url.pathname !== '/' ? Number(url.pathname.slice(1)) : undefined
  };
}

function openExportQueue() {
  return new Queue('export_jobs', { connection: parseRedisUrl(redisUrl) });
}

describe('ExportJobs (e2e)', () => {
  it('validates create payloads and id params', async () => {
    const suffix = Date.now();
    const tenant = { code: `export-validate-${suffix}`, name: 'Export Validate' };

    await request(base).post('/tenants').send(tenant);

    const reg = await request(base).post('/auth/register').send({ username: `user-export-validate-${suffix}` });
    expect(reg.status).toBe(201);
    const token = reg.body.accessToken;

    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    const invalidCreate = await request(base)
      .post('/export-jobs')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(invalidCreate.status).toBe(400);
    expect(invalidCreate.body.error.code).toBe('validation_failed');
    expect(invalidCreate.body.error.details).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ field: 'documentId', messages: expect.arrayContaining(['Invalid documentId']) })
      ])
    );

    const invalidGet = await request(base)
      .get('/export-jobs/not-a-uuid')
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

  it('register -> join tenant -> create document -> create export job -> get export job', async () => {
    const suffix = Date.now();
    const tenant = { code: `export-tenant-${suffix}`, name: 'Export Tenant' };

    await request(base).post('/tenants').send(tenant);

    const reg = await request(base).post('/auth/register').send({ username: `user-export-${suffix}` });
    expect(reg.status).toBe(201);
    const token = reg.body.accessToken;

    const join = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'owner' });
    expect(join.status).toBe(201);

    const createdDoc = await request(base)
      .post('/documents')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ name: 'Export Doc', kind: 'paper' });

    expect(createdDoc.status).toBe(201);
    const documentId = createdDoc.body.document.id;

    const createdJob = await request(base)
      .post('/export-jobs')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ documentId });

    expect(createdJob.status).toBe(201);

    const jobId = createdJob.body.job.id;

    const start = Date.now();
    let lastStatus: string | undefined;
    while (Date.now() - start < 2000) {
      const get = await request(base)
        .get(`/export-jobs/${jobId}`)
        .set('X-Tenant-Code', tenant.code)
        .set('Authorization', `Bearer ${token}`);

      expect(get.status).toBe(200);
      lastStatus = get.body.job.status;

      if (lastStatus === 'succeeded' || lastStatus === 'failed') break;

      await new Promise((r) => setTimeout(r, 100));
    }

    expect(lastStatus).toBe('succeeded');

    const result = await request(base)
      .get(`/export-jobs/${jobId}/result`)
      .buffer(true)
      .parse((res, cb) => {
        const chunks: Buffer[] = [];
        res.on('data', (d) => chunks.push(Buffer.isBuffer(d) ? d : Buffer.from(d)));
        res.on('end', () => cb(null, Buffer.concat(chunks)));
      })
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(result.status).toBe(200);
    expect(result.headers['content-type']).toMatch(/application\/pdf/);
    expect((result.body as Buffer).length).toBeGreaterThan(100);

    const listDocuments = await request(base)
      .get('/documents')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(listDocuments.status).toBe(200);
    const listedDocument = listDocuments.body.documents.find((document: any) => document.id === documentId);
    expect(listedDocument.summary.latestExportJob).toMatchObject({
      id: jobId,
      kind: 'document_pdf',
      status: 'succeeded'
    });
  });

  it('marks the job failed and returns 503 when queue access is unavailable during create', async () => {
    const suffix = Date.now();
    const tenant = { code: `export-fault-${suffix}`, name: 'Export Fault' };

    await request(base).post('/tenants').send(tenant);

    const reg = await request(base).post('/auth/register').send({ username: `user-export-fault-${suffix}` });
    expect(reg.status).toBe(201);
    const token = reg.body.accessToken;

    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    const createdDoc = await request(base)
      .post('/documents')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ name: 'Queue Fault Doc', kind: 'paper' });

    expect(createdDoc.status).toBe(201);

    const createdJob = await request(base)
      .post('/export-jobs')
      .set('X-Test-Fault', 'queue_unavailable')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ documentId: createdDoc.body.document.id });

    expect(createdJob.status).toBe(503);
    expect(createdJob.body.error.code).toBe('internal_error');
    expect(String(createdJob.body.message)).toContain('Export job could not be queued');

    const listJobs = await request(base)
      .get('/export-jobs')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(listJobs.status).toBe(200);
    expect(listJobs.body.jobs).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          documentId: createdDoc.body.document.id,
          status: 'failed',
          errorMessage: expect.stringContaining('queue unavailable')
        })
      ])
    );
  });

  it('lists export jobs and supports cancel + retry for queued jobs', async () => {
    const suffix = Date.now();
    const tenant = { code: `export-history-${suffix}`, name: 'Export History' };

    await request(base).post('/tenants').send(tenant);

    const reg = await request(base).post('/auth/register').send({ username: `user-export-history-${suffix}` });
    expect(reg.status).toBe(201);
    const token = reg.body.accessToken;

    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    const createdDoc = await request(base)
      .post('/documents')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ name: 'Queued Export Doc', kind: 'paper' });

    expect(createdDoc.status).toBe(201);

    const queue = openExportQueue();
    await queue.pause();

    try {
      const createdJob = await request(base)
        .post('/export-jobs')
        .set('X-Tenant-Code', tenant.code)
        .set('Authorization', `Bearer ${token}`)
        .send({ documentId: createdDoc.body.document.id });

      expect(createdJob.status).toBe(201);
      const jobId = createdJob.body.job.id;

      const listPending = await request(base)
        .get('/export-jobs')
        .query({ status: 'pending' })
        .set('X-Tenant-Code', tenant.code)
        .set('Authorization', `Bearer ${token}`);

      expect(listPending.status).toBe(200);
      expect(listPending.body.jobs.some((job: any) => job.id === jobId)).toBe(true);
      expect(listPending.body.meta).toMatchObject({
        status: 'pending',
        sortBy: 'createdAt',
        sortOrder: 'desc'
      });

      const listSorted = await request(base)
        .get('/export-jobs')
        .query({ sortBy: 'updatedAt', sortOrder: 'asc', limit: 1, offset: 0 })
        .set('X-Tenant-Code', tenant.code)
        .set('Authorization', `Bearer ${token}`);

      expect(listSorted.status).toBe(200);
      expect(listSorted.body.meta).toMatchObject({
        limit: 1,
        offset: 0,
        sortBy: 'updatedAt',
        sortOrder: 'asc'
      });

      const cancel = await request(base)
        .post(`/export-jobs/${jobId}/cancel`)
        .set('X-Tenant-Code', tenant.code)
        .set('Authorization', `Bearer ${token}`);

      expect(cancel.status).toBe(201);
      expect(cancel.body.job.status).toBe('canceled');

      const retry = await request(base)
        .post(`/export-jobs/${jobId}/retry`)
        .set('X-Tenant-Code', tenant.code)
        .set('Authorization', `Bearer ${token}`);

      expect(retry.status).toBe(201);
      expect(retry.body.job.status).toBe('pending');

      await queue.resume();

      const start = Date.now();
      let lastStatus: string | undefined;
      while (Date.now() - start < 2000) {
        const get = await request(base)
          .get(`/export-jobs/${jobId}`)
          .set('X-Tenant-Code', tenant.code)
          .set('Authorization', `Bearer ${token}`);

        expect(get.status).toBe(200);
        lastStatus = get.body.job.status;
        if (lastStatus === 'succeeded' || lastStatus === 'failed') break;
        await new Promise((r) => setTimeout(r, 100));
      }

      expect(lastStatus).toBe('succeeded');

      const cleanup = await request(base)
        .post('/export-jobs/cleanup')
        .set('X-Tenant-Code', tenant.code)
        .set('Authorization', `Bearer ${token}`)
        .send({ staleHours: 0, retainHours: 0 });

      expect(cleanup.status).toBe(201);
      expect(cleanup.body.cleanup.deletedJobs).toBeGreaterThanOrEqual(1);

      const deletedJobGet = await request(base)
        .get(`/export-jobs/${jobId}`)
        .set('X-Tenant-Code', tenant.code)
        .set('Authorization', `Bearer ${token}`);

      expect(deletedJobGet.status).toBe(404);
    } finally {
      await queue.resume().catch(() => undefined);
      await queue.close();
    }
  });
});

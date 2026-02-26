import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('ExportJobs (e2e)', () => {
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
  });
});

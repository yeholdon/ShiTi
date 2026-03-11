import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Questions load smoke (e2e)', () => {
  it('serves concurrent question list reads consistently', async () => {
    const suffix = Date.now();
    const tenant = { code: `question-load-${suffix}`, name: 'Question Load' };

    await request(base).post('/tenants').send(tenant);

    const reg = await request(base).post('/auth/register').send({ username: `question-load-${suffix}` });
    expect(reg.status).toBe(201);
    const token = reg.body.accessToken as string;

    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    const createResults = await Promise.all(
      Array.from({ length: 8 }, () =>
        request(base)
          .post('/questions')
          .set('X-Tenant-Code', tenant.code)
          .set('Authorization', `Bearer ${token}`)
          .send({})
      )
    );

    for (const result of createResults) {
      expect(result.status).toBe(201);
    }

    const reads = await Promise.all(
      Array.from({ length: 12 }, () =>
        request(base)
          .get('/questions')
          .query({ limit: 20 })
          .set('X-Tenant-Code', tenant.code)
          .set('Authorization', `Bearer ${token}`)
      )
    );

    for (const read of reads) {
      expect(read.status).toBe(200);
      expect(Array.isArray(read.body.questions)).toBe(true);
      expect(read.body.questions).toHaveLength(8);
      expect(read.body.meta).toMatchObject({
        limit: 20,
        offset: 0,
        returned: 8,
        total: 8,
        hasMore: false
      });
    }
  });
});

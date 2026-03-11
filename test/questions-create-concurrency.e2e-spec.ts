import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Questions create concurrency (e2e)', () => {
  it('creates distinct questions under concurrent writes', async () => {
    const suffix = Date.now();
    const tenant = { code: `question-create-race-${suffix}`, name: 'Question Create Race' };

    await request(base).post('/tenants').send(tenant);

    const reg = await request(base).post('/auth/register').send({ username: `question-create-race-${suffix}` });
    expect(reg.status).toBe(201);
    const token = reg.body.accessToken as string;

    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    const writes = await Promise.all(
      Array.from({ length: 10 }, () =>
        request(base)
          .post('/questions')
          .set('X-Tenant-Code', tenant.code)
          .set('Authorization', `Bearer ${token}`)
          .send({})
      )
    );

    for (const write of writes) {
      expect(write.status).toBe(201);
      expect(write.body.question).toBeTruthy();
    }

    const ids = new Set(writes.map((write) => write.body.question.id));
    expect(ids.size).toBe(10);

    const list = await request(base)
      .get('/questions')
      .query({ limit: 20 })
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(list.status).toBe(200);
    expect(list.body.questions).toHaveLength(10);
    expect(list.body.meta).toMatchObject({
      returned: 10,
      total: 10,
      hasMore: false
    });
  });
});

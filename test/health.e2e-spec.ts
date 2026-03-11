import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Health (e2e)', () => {
  it('returns ok', async () => {
    const res = await request(base).get('/health').set('X-Request-Id', 'health-e2e-request');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: 'ok' });
    expect(res.headers['x-request-id']).toBe('health-e2e-request');
  });

  it('returns readiness checks', async () => {
    const res = await request(base).get('/health/ready');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ready');
    expect(res.body.checks.database.status).toBe('ok');
    expect(res.body.checks.redis.status).toBe('ok');
    expect(res.body.checks.minio.status).toBe('ok');
  });
});

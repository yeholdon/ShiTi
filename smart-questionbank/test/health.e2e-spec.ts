import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Health (e2e)', () => {
  it('returns ok', async () => {
    const res = await request(base).get('/health');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: 'ok' });
  });
});

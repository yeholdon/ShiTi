import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Admin (e2e)', () => {
  it('serves the admin console', async () => {
    const res = await request(base).get('/admin');
    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toMatch(/text\/html/);
    expect(String(res.text)).toContain('ShiTi');
    expect(String(res.text)).toContain('审计日志');
    expect(String(res.text)).toContain('最近 24 小时');
    expect(String(res.text)).toContain('动作分布');
    expect(String(res.text)).toContain('目标类型分布');
  });
});

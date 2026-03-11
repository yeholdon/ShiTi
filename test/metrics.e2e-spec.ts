import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Metrics (e2e)', () => {
  it('serves Prometheus-style HTTP metrics', async () => {
    await request(base).get('/health');

    const res = await request(base).get('/metrics');

    expect(res.status).toBe(200);
    expect(String(res.headers['content-type'] || '')).toContain('text/plain');
    expect(res.text).toContain('shiti_http_requests_total');
    expect(res.text).toContain('shiti_http_requests_by_status_total{statusCode="200"}');
    expect(res.text).toContain('shiti_http_requests_by_method_status_total{method="GET",statusCode="200"}');
  });
});

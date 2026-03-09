import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Docs (e2e)', () => {
  it('serves the swagger docs page', async () => {
    const res = await request(base).get('/docs');

    expect(res.status).toBe(200);
    expect(res.text).toContain('Swagger UI');
  });

  it('serves the openapi json document', async () => {
    const res = await request(base).get('/docs/openapi.json');

    expect(res.status).toBe(200);
    expect(res.body.openapi).toMatch(/^3\./);
    expect(res.body.info.title).toBe('ShiTi API');
    expect(res.body.paths['/questions']).toBeTruthy();
    expect(res.body.paths['/documents']).toBeTruthy();
    expect(res.body.paths['/metrics']).toBeTruthy();
  });
});

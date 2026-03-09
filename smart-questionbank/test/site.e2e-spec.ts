import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Site (e2e)', () => {
  it('serves the public frontend landing page', async () => {
    const res = await request(base).get('/');

    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toMatch(/text\/html/);
    expect(String(res.text)).toContain('ShiTi');
    expect(String(res.text)).toContain('运维控制台');
    expect(String(res.text)).toContain('/admin');
    expect(String(res.text)).toContain('/docs');
  });

  it('serves the supporting frontend content pages', async () => {
    const workspace = await request(base).get('/site/workspace.html');
    expect(workspace.status).toBe(200);
    expect(String(workspace.text)).toContain('Teaching Workspace');

    const product = await request(base).get('/site/product.html');
    expect(product.status).toBe(200);
    expect(String(product.text)).toContain('Capability Map');

    const architecture = await request(base).get('/site/architecture.html');
    expect(architecture.status).toBe(200);
    expect(String(architecture.text)).toContain('Architecture');

    const consoleGuide = await request(base).get('/site/console.html');
    expect(consoleGuide.status).toBe(200);
    expect(String(consoleGuide.text)).toContain('Console Guide');

    const operations = await request(base).get('/site/operations.html');
    expect(operations.status).toBe(200);
    expect(String(operations.text)).toContain('Operations Flow');

    const quickStart = await request(base).get('/site/get-started.html');
    expect(quickStart.status).toBe(200);
    expect(String(quickStart.text)).toContain('Quick Start');

    const status = await request(base).get('/site/status.html');
    expect(status.status).toBe(200);
    expect(String(status.text)).toContain('Live Status');
  });
});

import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';
const tinyPng = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7Z8ioAAAAASUVORK5CYII=', 'base64');

describe('Export layout elements (e2e)', () => {
  it('exports handout layout elements and asset placeholders into the generated pdf', async () => {
    const suffix = Date.now();
    const tenant = { code: `export-layout-${suffix}`, name: 'Export Layout' };

    await request(base).post('/tenants').send(tenant);

    const reg = await request(base).post('/auth/register').send({ username: `export-layout-${suffix}` });
    expect(reg.status).toBe(201);
    const token = reg.body.accessToken as string;

    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    const uploadedAsset = await request(base)
      .post('/assets/upload')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ filename: 'diagram.png', mime: 'image/png', size: 111 });
    expect(uploadedAsset.status).toBe(201);
    const assetId = uploadedAsset.body.asset.id as string;

    const uploadedBytes = await fetch(uploadedAsset.body.upload.url, {
      method: 'PUT',
      headers: { 'Content-Type': 'image/png' },
      body: tinyPng
    });
    expect(uploadedBytes.ok).toBe(true);

    const layoutElement = await request(base)
      .post('/layout-elements')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({
        blocks: [
          { type: 'paragraph', text: `Handout Intro ${suffix}` },
          { type: 'image', assetId }
        ]
      });
    expect(layoutElement.status).toBe(201);

    const question = await request(base)
      .post('/questions')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({});
    expect(question.status).toBe(201);
    const questionId = question.body.question.id as string;

    const content = await request(base)
      .put(`/questions/${questionId}/content`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({
        stemBlocks: [
          { type: 'text', text: `Question Stem ${suffix}` },
          { type: 'image', assetId }
        ]
      });
    expect(content.status).toBe(200);

    const document = await request(base)
      .post('/documents')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ name: `Handout Export ${suffix}`, kind: 'handout' });
    expect(document.status).toBe(201);
    const documentId = document.body.document.id as string;

    const addLayout = await request(base)
      .post(`/documents/${documentId}/items`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ itemType: 'layout_element', layoutElementId: layoutElement.body.layoutElement.id });
    expect(addLayout.status).toBe(201);

    const addQuestion = await request(base)
      .post(`/documents/${documentId}/items`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ itemType: 'question', questionId });
    expect(addQuestion.status).toBe(201);

    const createdJob = await request(base)
      .post('/export-jobs')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ documentId });
    expect(createdJob.status).toBe(201);
    const jobId = createdJob.body.job.id as string;

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
    const pdfText = (result.body as Buffer).toString('latin1');
    expect(pdfText).toContain(Buffer.from(`Handout Intro ${suffix}`).toString('hex'));
    expect(pdfText).toContain(Buffer.from(`Question Stem ${suffix}`).toString('hex'));
    expect(pdfText).toContain('/Subtype /Image');
  });
});

import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Questions import (e2e)', () => {
  it('imports questions with content/explanation/answers/tags', async () => {
    const suffix = Date.now();
    const tenant = { code: `import-tenant-${suffix}`, name: 'Import Tenant' };

    await request(base).post('/tenants').send(tenant);

    const reg = await request(base).post('/auth/register').send({ username: `import-user-${suffix}` });
    expect(reg.status).toBe(201);
    const token = reg.body.accessToken;

    const join = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    expect(join.status).toBe(201);

    const items = [
      {
        type: 'single_choice',
        difficulty: 2,
        defaultScore: '3.00',
        visibility: 'private',
        tags: ['导入', '选择题'],
        content: { stemBlocks: [{ type: 'text', text: '1+1=？' }] },
        explanation: { stepsBlocks: [{ type: 'step', text: '1+1=2' }], overviewLatex: null, commentaryLatex: null },
        choiceAnswer: {
          optionsBlocks: [
            { type: 'option', key: 'A', text: '1' },
            { type: 'option', key: 'B', text: '2' }
          ],
          correct: { keys: ['B'] }
        },
        source: { year: 2026, month: 3, sourceText: 'import spec' }
      },
      {
        type: 'fill_blank',
        difficulty: 3,
        defaultScore: '5.00',
        visibility: 'tenant_shared',
        tags: ['导入', '填空题'],
        content: { stemBlocks: [{ type: 'text', text: 'x=__' }] },
        blankAnswer: { blanks: [{ key: 'b1', answers: ['42'] }] }
      },
      {
        type: 'solution',
        difficulty: 4,
        defaultScore: '10.00',
        visibility: 'private',
        tags: ['导入', '解答题'],
        content: { stemBlocks: [{ type: 'text', text: '证明：...' }] },
        solutionAnswer: { finalAnswerLatex: 'QED', scoringPoints: [{ key: 'p1', points: 10, description: '完整证明' }] }
      }
    ];

    const imported = await request(base)
      .post('/questions/import')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ items });

    expect(imported.status).toBe(201);
    expect(imported.body.ok).toBe(true);
    expect(imported.body.createdCount).toBe(3);
    expect(Array.isArray(imported.body.questionIds)).toBe(true);

    const listWithTags = await request(base)
      .get('/questions?include=tags')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(listWithTags.status).toBe(200);
    expect(listWithTags.body.questions.length).toBeGreaterThanOrEqual(3);

    const qid = imported.body.questionIds[0];

    const get = await request(base)
      .get(`/questions/${qid}`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(get.status).toBe(200);
    expect(get.body.content?.stemBlocks).toEqual([{ type: 'text', text: '1+1=？' }]);
    expect(get.body.choiceAnswer?.correct).toEqual({ keys: ['B'] });
    expect(get.body.source?.sourceText).toBe('import spec');
    expect(get.body.tags?.map((t: any) => t.name).sort()).toEqual(['导入', '选择题']);
  });

  it('supports dryRun', async () => {
    const suffix = Date.now();
    const tenant = { code: `import-dry-${suffix}`, name: 'Import Dry' };

    await request(base).post('/tenants').send(tenant);

    const reg = await request(base).post('/auth/register').send({ username: `import-dry-user-${suffix}` });
    expect(reg.status).toBe(201);
    const token = reg.body.accessToken;

    const join = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    expect(join.status).toBe(201);

    const imported = await request(base)
      .post('/questions/import')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ dryRun: true, items: [{ type: 'single_choice', content: { stemBlocks: [{ type: 'text', text: 'x?' }] } }] });

    expect(imported.status).toBe(201);
    expect(imported.body.dryRun).toBe(true);
    expect(imported.body.count).toBe(1);

    const list = await request(base)
      .get('/questions')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(list.status).toBe(200);
    expect(list.body.questions).toEqual([]);
  });
});

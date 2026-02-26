import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Business flow (e2e)', () => {
  it('register -> join tenant -> create -> upsert content -> upsert answer -> upsert tags -> get -> list', async () => {
    const suffix = Date.now();
    const tenant = { code: `flow-tenant-${suffix}`, name: 'Flow Tenant' };

    await request(base).post('/tenants').send(tenant);

    const reg = await request(base).post('/auth/register').send({ username: `user-${suffix}` });
    expect(reg.status).toBe(201);
    const token = reg.body.accessToken;
    expect(typeof token).toBe('string');

    const join = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    expect(join.status).toBe(201);

    const created = await request(base)
      .post('/questions')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(created.status).toBe(201);
    const questionId = created.body.question.id;

    const stemBlocks = [{ type: 'text', text: 'Hello stem' }];

    const upsert = await request(base)
      .put(`/questions/${questionId}/content`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ stemBlocks });

    expect(upsert.status).toBe(200);

    const stepsBlocks = [{ type: 'step', text: 'Because...' }];

    const upsertExplanation = await request(base)
      .put(`/questions/${questionId}/explanation`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ stepsBlocks, overviewLatex: null, commentaryLatex: null });

    expect(upsertExplanation.status).toBe(200);

    const optionsBlocks = [
      { type: 'option', key: 'A', text: '1' },
      { type: 'option', key: 'B', text: '2' }
    ];

    const upsertChoiceAnswer = await request(base)
      .put(`/questions/${questionId}/answer-choice`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ optionsBlocks, correct: { keys: ['B'] } });

    expect(upsertChoiceAnswer.status).toBe(200);

    const blanks = [{ key: 'b1', answers: ['42', '四十二'] }];

    const upsertBlankAnswer = await request(base)
      .put(`/questions/${questionId}/answer-blank`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ blanks });

    expect(upsertBlankAnswer.status).toBe(200);

    const scoringPoints = [
      { key: 'p1', points: 2, description: '关键步骤正确' },
      { key: 'p2', points: 3, description: '结论正确' }
    ];

    const upsertSolutionAnswer = await request(base)
      .put(`/questions/${questionId}/answer-solution`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ finalAnswerLatex: 'x=42', scoringPoints });

    expect(upsertSolutionAnswer.status).toBe(200);

    const createdTag = await request(base)
      .post('/question-tags')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ name: '重点题' });

    expect(createdTag.status).toBe(201);
    const tagId = createdTag.body.tag.id;

    const setTags = await request(base)
      .put(`/questions/${questionId}/tags`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ tagIds: [tagId] });

    expect(setTags.status).toBe(200);
    expect(Array.isArray(setTags.body.tags)).toBe(true);

    const get = await request(base)
      .get(`/questions/${questionId}`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(get.status).toBe(200);
    expect(get.body.content?.stemBlocks).toEqual(stemBlocks);
    expect(get.body.explanation?.stepsBlocks).toEqual(stepsBlocks);
    expect(get.body.choiceAnswer?.optionsBlocks).toEqual(optionsBlocks);
    expect(get.body.choiceAnswer?.correct).toEqual({ keys: ['B'] });
    expect(get.body.blankAnswer?.blanks).toEqual(blanks);
    expect(get.body.solutionAnswer?.finalAnswerLatex).toBe('x=42');
    expect(get.body.solutionAnswer?.scoringPoints).toEqual(scoringPoints);
    expect(get.body.tags?.map((t: any) => t.id)).toEqual([tagId]);

    const upsertSource = await request(base)
      .put(`/questions/${questionId}/source`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ year: 2026, month: 2, sourceText: '小红书模拟来源' });

    expect(upsertSource.status).toBe(200);

    const get2 = await request(base)
      .get(`/questions/${questionId}`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(get2.status).toBe(200);
    expect(get2.body.source?.year).toBe(2026);
    expect(get2.body.source?.month).toBe(2);
    expect(get2.body.source?.sourceText).toBe('小红书模拟来源');

    const list = await request(base)
      .get('/questions')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(list.status).toBe(200);
    expect(Array.isArray(list.body.questions)).toBe(true);
  });
});

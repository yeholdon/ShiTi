import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Questions details roundtrip (e2e)', () => {
  it('persists question content, explanation, source, and choice answer details', async () => {
    const suffix = Date.now();
    const tenant = { code: `question-details-${suffix}`, name: 'Question Details' };

    const login = await request(base).post('/auth/register').send({ username: `question-details-${suffix}` });
    expect(login.status).toBe(201);
    const token = login.body.accessToken as string;

    await request(base).post('/tenants').send(tenant);
    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    const createQuestion = await request(base)
      .post('/questions')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(createQuestion.status).toBe(201);
    const questionId = createQuestion.body.question.id as string;

    const stemBlocks = [{ type: 'paragraph', children: [{ text: `Stem ${suffix}` }] }];
    const stepsBlocks = [{ type: 'paragraph', children: [{ text: `Step ${suffix}` }] }];
    const optionsBlocks = [
      { key: 'A', blocks: [{ type: 'paragraph', children: [{ text: `Option A ${suffix}` }] }] },
      { key: 'B', blocks: [{ type: 'paragraph', children: [{ text: `Option B ${suffix}` }] }] }
    ];

    const setContent = await request(base)
      .put(`/questions/${questionId}/content`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ stemBlocks });
    expect(setContent.status).toBe(200);
    expect(setContent.body.content.stemBlocks).toEqual(stemBlocks);

    const setExplanation = await request(base)
      .put(`/questions/${questionId}/explanation`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({
        overviewLatex: `x = ${suffix}`,
        stepsBlocks,
        commentaryLatex: `y = ${suffix}`
      });
    expect(setExplanation.status).toBe(200);
    expect(setExplanation.body.explanation.stepsBlocks).toEqual(stepsBlocks);

    const setSource = await request(base)
      .put(`/questions/${questionId}/source`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ year: 2026, month: 3, sourceText: `Source ${suffix}` });
    expect(setSource.status).toBe(200);
    expect(setSource.body.source.sourceText).toBe(`Source ${suffix}`);

    const setChoiceAnswer = await request(base)
      .put(`/questions/${questionId}/answer-choice`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ optionsBlocks, correct: ['B'] });
    expect(setChoiceAnswer.status).toBe(200);
    expect(setChoiceAnswer.body.choiceAnswer.correct).toEqual(['B']);

    const getQuestion = await request(base)
      .get(`/questions/${questionId}`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(getQuestion.status).toBe(200);
    expect(getQuestion.body.content.stemBlocks).toEqual(stemBlocks);
    expect(getQuestion.body.explanation.overviewLatex).toBe(`x = ${suffix}`);
    expect(getQuestion.body.explanation.stepsBlocks).toEqual(stepsBlocks);
    expect(getQuestion.body.explanation.commentaryLatex).toBe(`y = ${suffix}`);
    expect(getQuestion.body.source).toMatchObject({ year: 2026, month: 3, sourceText: `Source ${suffix}` });
    expect(getQuestion.body.choiceAnswer.optionsBlocks).toEqual(optionsBlocks);
    expect(getQuestion.body.choiceAnswer.correct).toEqual(['B']);
  });
});

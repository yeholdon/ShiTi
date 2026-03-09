import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Questions answer modes roundtrip (e2e)', () => {
  it('validates answer mode payloads', async () => {
    const suffix = Date.now();
    const tenant = { code: `question-answers-validate-${suffix}`, name: 'Question Answers Validate' };

    const login = await request(base).post('/auth/register').send({ username: `question-answers-validate-${suffix}` });
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

    const badChoice = await request(base)
      .put(`/questions/${questionId}/answer-choice`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(badChoice.status).toBe(400);
    expect(badChoice.body.message).toContain('Missing optionsBlocks');
    expect(badChoice.body.error.code).toBe('validation_failed');

    const badBlank = await request(base)
      .put(`/questions/${questionId}/answer-blank`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(badBlank.status).toBe(400);
    expect(badBlank.body.message).toContain('Missing blanks');
    expect(badBlank.body.error.code).toBe('validation_failed');

    const badSolution = await request(base)
      .put(`/questions/${questionId}/answer-solution`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(badSolution.status).toBe(400);
    expect(badSolution.body.message).toContain('Missing scoringPoints');
    expect(badSolution.body.error.code).toBe('validation_failed');
  });

  it('persists blank and solution answers through question detail reads', async () => {
    const suffix = Date.now();
    const tenant = { code: `question-answers-${suffix}`, name: 'Question Answers' };

    const login = await request(base).post('/auth/register').send({ username: `question-answers-${suffix}` });
    expect(login.status).toBe(201);
    const token = login.body.accessToken as string;

    await request(base).post('/tenants').send(tenant);
    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    const createBlankQuestion = await request(base)
      .post('/questions')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({});
    expect(createBlankQuestion.status).toBe(201);

    const blankQuestionId = createBlankQuestion.body.question.id as string;
    const blanks = [{ key: 'blank-1', answers: [`${suffix}`] }];

    const setBlankAnswer = await request(base)
      .put(`/questions/${blankQuestionId}/answer-blank`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ blanks });

    expect(setBlankAnswer.status).toBe(200);
    expect(setBlankAnswer.body.blankAnswer.blanks).toEqual(blanks);

    const blankQuestion = await request(base)
      .get(`/questions/${blankQuestionId}`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(blankQuestion.status).toBe(200);
    expect(blankQuestion.body.blankAnswer.blanks).toEqual(blanks);

    const createSolutionQuestion = await request(base)
      .post('/questions')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({});
    expect(createSolutionQuestion.status).toBe(201);

    const solutionQuestionId = createSolutionQuestion.body.question.id as string;
    const scoringPoints = [
      { key: 'step-1', score: '2.00', note: `Point ${suffix}` },
      { key: 'step-2', score: '3.00', note: `Final ${suffix}` }
    ];
    const referenceAnswerBlocks = [{ type: 'paragraph', children: [{ text: `Answer ${suffix}` }] }];
    const scoringPointsBlocks = [{ type: 'paragraph', children: [{ text: `Scoring ${suffix}` }] }];

    const setSolutionAnswer = await request(base)
      .put(`/questions/${solutionQuestionId}/answer-solution`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({
        finalAnswerLatex: `x = ${suffix}`,
        referenceAnswerBlocks,
        scoringPoints,
        scoringPointsBlocks
      });

    expect(setSolutionAnswer.status).toBe(200);
    expect(setSolutionAnswer.body.solutionAnswer.finalAnswerLatex).toBe(`x = ${suffix}`);
    expect(setSolutionAnswer.body.solutionAnswer.referenceAnswerBlocks).toEqual(referenceAnswerBlocks);
    expect(setSolutionAnswer.body.solutionAnswer.scoringPoints).toEqual(scoringPoints);
    expect(setSolutionAnswer.body.solutionAnswer.scoringPointsBlocks).toEqual(scoringPointsBlocks);

    const solutionQuestion = await request(base)
      .get(`/questions/${solutionQuestionId}`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(solutionQuestion.status).toBe(200);
    expect(solutionQuestion.body.solutionAnswer.finalAnswerLatex).toBe(`x = ${suffix}`);
    expect(solutionQuestion.body.solutionAnswer.referenceAnswerBlocks).toEqual(referenceAnswerBlocks);
    expect(solutionQuestion.body.solutionAnswer.scoringPoints).toEqual(scoringPoints);
    expect(solutionQuestion.body.solutionAnswer.scoringPointsBlocks).toEqual(scoringPointsBlocks);
  });
});

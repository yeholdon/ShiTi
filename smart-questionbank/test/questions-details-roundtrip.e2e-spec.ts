import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { PrismaClient, QuestionType, QuestionVisibility } from '@prisma/client';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';
const prisma = new PrismaClient();

afterAll(async () => {
  await prisma.$disconnect();
});

describe('Questions details roundtrip (e2e)', () => {
  it('validates id params', async () => {
    const suffix = Date.now();
    const tenant = { code: `question-details-params-${suffix}`, name: 'Question Details Params' };

    const login = await request(base).post('/auth/register').send({ username: `question-details-params-${suffix}` });
    expect(login.status).toBe(201);
    const token = login.body.accessToken as string;

    await request(base).post('/tenants').send(tenant);
    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    const invalidGet = await request(base)
      .get('/questions/not-a-uuid')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(invalidGet.status).toBe(400);
    expect(invalidGet.body.error.code).toBe('validation_failed');
    expect(invalidGet.body.error.details).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ field: 'id', messages: expect.arrayContaining(['Invalid id']) })
      ])
    );

    const invalidContent = await request(base)
      .put('/questions/not-a-uuid/content')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ stemBlocks: [] });

    expect(invalidContent.status).toBe(400);
    expect(invalidContent.body.error.code).toBe('validation_failed');
    expect(invalidContent.body.error.details).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ field: 'id', messages: expect.arrayContaining(['Invalid id']) })
      ])
    );
  });

  it('validates content and explanation payloads', async () => {
    const suffix = Date.now();
    const tenant = { code: `question-details-validate-${suffix}`, name: 'Question Details Validate' };

    const login = await request(base).post('/auth/register').send({ username: `question-details-validate-${suffix}` });
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

    const badContent = await request(base)
      .put(`/questions/${questionId}/content`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(badContent.status).toBe(400);
    expect(badContent.body.message).toContain('Missing stemBlocks');
    expect(badContent.body.error.code).toBe('validation_failed');

    const badExplanation = await request(base)
      .put(`/questions/${questionId}/explanation`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(badExplanation.status).toBe(400);
    expect(badExplanation.body.message).toContain('Missing stepsBlocks');
    expect(badExplanation.body.error.code).toBe('validation_failed');

    const badSource = await request(base)
      .put(`/questions/${questionId}/source`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ month: 13 });

    expect(badSource.status).toBe(400);
    expect(badSource.body.message).toContain('Invalid month');
    expect(badSource.body.error.code).toBe('validation_failed');
  });

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
    const overviewBlocks = [{ type: 'paragraph', children: [{ text: `Overview ${suffix}` }] }];
    const commentaryBlocks = [{ type: 'paragraph', children: [{ text: `Comment ${suffix}` }] }];
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
        overviewBlocks,
        stepsBlocks,
        commentaryLatex: `y = ${suffix}`,
        commentaryBlocks
      });
    expect(setExplanation.status).toBe(200);
    expect(setExplanation.body.explanation.stepsBlocks).toEqual(stepsBlocks);
    expect(setExplanation.body.explanation.overviewBlocks).toEqual(overviewBlocks);
    expect(setExplanation.body.explanation.commentaryBlocks).toEqual(commentaryBlocks);

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
    expect(getQuestion.body.explanation.overviewBlocks).toEqual(overviewBlocks);
    expect(getQuestion.body.explanation.stepsBlocks).toEqual(stepsBlocks);
    expect(getQuestion.body.explanation.commentaryLatex).toBe(`y = ${suffix}`);
    expect(getQuestion.body.explanation.commentaryBlocks).toEqual(commentaryBlocks);
    expect(getQuestion.body.source).toMatchObject({ year: 2026, month: 3, sourceText: `Source ${suffix}` });
    expect(getQuestion.body.choiceAnswer.optionsBlocks).toEqual(optionsBlocks);
    expect(getQuestion.body.choiceAnswer.correct).toEqual(['B']);
  });

  it('returns normalized block fields for legacy explanation and solution rows', async () => {
    const suffix = Date.now();
    const tenant = { code: `question-legacy-blocks-${suffix}`, name: 'Question Legacy Blocks' };
    const username = `question-legacy-blocks-${suffix}`;

    const login = await request(base).post('/auth/register').send({ username });
    expect(login.status).toBe(201);
    const token = login.body.accessToken as string;
    const user = await prisma.user.findUnique({ where: { username } });
    expect(user).toBeTruthy();
    const userId = user!.id;

    const createTenant = await request(base).post('/tenants').send(tenant);
    expect(createTenant.status).toBe(201);
    const tenantId = createTenant.body.tenant.id as string;

    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    const systemSubject = await prisma.subject.findFirst({ where: { tenantId: null, isSystem: true } });
    expect(systemSubject).toBeTruthy();

    const questionId = randomUUID();
    await prisma.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT set_config('app.tenant_id', ${tenantId}, true)`;

      await tx.question.create({
        data: {
          tenantId,
          id: questionId,
          type: QuestionType.solution,
          difficulty: 3,
          defaultScore: '5.00',
          subjectId: systemSubject!.id,
          ownerUserId: userId,
          visibility: QuestionVisibility.private
        }
      });

      await tx.questionExplanation.create({
        data: {
          tenantId,
          questionId,
          overviewLatex: `legacy overview ${suffix}`,
          stepsBlocks: [{ type: 'paragraph', children: [{ text: `legacy step ${suffix}` }] }],
          commentaryLatex: `legacy commentary ${suffix}`
        }
      });

      await tx.questionAnswerSolution.create({
        data: {
          tenantId,
          questionId,
          finalAnswerLatex: `legacy final ${suffix}`,
          scoringPoints: [{ key: 'legacy-1', score: '1.00', note: `legacy note ${suffix}` }]
        }
      });
    });

    const getQuestion = await request(base)
      .get(`/questions/${questionId}`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(getQuestion.status).toBe(200);
    expect(getQuestion.body.explanation.overviewBlocks).toEqual([
      { type: 'latex', children: [{ text: `legacy overview ${suffix}` }] }
    ]);
    expect(getQuestion.body.explanation.commentaryBlocks).toEqual([
      { type: 'latex', children: [{ text: `legacy commentary ${suffix}` }] }
    ]);
    expect(getQuestion.body.solutionAnswer.referenceAnswerBlocks).toEqual([
      { type: 'latex', children: [{ text: `legacy final ${suffix}` }] }
    ]);
  });
});

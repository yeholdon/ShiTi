import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Questions taxonomy (e2e)', () => {
  it('validates id params', async () => {
    const suffix = Date.now();
    const tenant = { code: `question-taxonomy-params-${suffix}`, name: 'Question Taxonomy Params' };

    const login = await request(base).post('/auth/register').send({ username: `question-taxonomy-params-${suffix}` });
    expect(login.status).toBe(201);
    const token = login.body.accessToken as string;

    await request(base).post('/tenants').send(tenant);
    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    const invalidSet = await request(base)
      .put('/questions/not-a-uuid/taxonomy')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ stageIds: [] });

    expect(invalidSet.status).toBe(400);
    expect(invalidSet.body.error.code).toBe('validation_failed');
    expect(invalidSet.body.error.details).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ field: 'id', messages: expect.arrayContaining(['Invalid id']) })
      ])
    );
  });

  it('validates taxonomy payload shape', async () => {
    const suffix = Date.now();
    const tenant = { code: `question-taxonomy-validate-${suffix}`, name: 'Question Taxonomy Validate' };

    const login = await request(base).post('/auth/register').send({ username: `question-taxonomy-validate-${suffix}` });
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

    const setTaxonomy = await request(base)
      .put(`/questions/${createQuestion.body.question.id}/taxonomy`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ stageIds: 'primary' });

    expect(setTaxonomy.status).toBe(400);
    expect(setTaxonomy.body.message).toContain('Invalid stageIds');
    expect(setTaxonomy.body.error.code).toBe('validation_failed');
  });

  it('assigns taxonomy to a question, returns it in detail, and filters list by taxonomy ids', async () => {
    const suffix = Date.now();
    const tenant = { code: `question-taxonomy-${suffix}`, name: 'Question Taxonomy' };

    const login = await request(base).post('/auth/register').send({ username: `question-taxonomy-${suffix}` });
    expect(login.status).toBe(201);
    const token = login.body.accessToken as string;

    await request(base).post('/tenants').send(tenant);
    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    const systemStages = await request(base).get('/stages').set('Authorization', `Bearer ${token}`);
    const systemTextbooks = await request(base).get('/textbooks').set('Authorization', `Bearer ${token}`);
    expect(systemStages.status).toBe(200);
    expect(systemTextbooks.status).toBe(200);

    const stageId = systemStages.body.stages.find((stage: any) => stage.code === 'primary').id as string;

    const systemGrades = await request(base)
      .get('/grades')
      .query({ stageId })
      .set('Authorization', `Bearer ${token}`);
    expect(systemGrades.status).toBe(200);
    const gradeId = systemGrades.body.grades[0].id as string;
    const textbookId = systemTextbooks.body.textbooks[0].id as string;

    const createChapter = await request(base)
      .post('/chapters')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ textbookId, name: `章节-${suffix}` });
    expect(createChapter.status).toBe(201);
    const chapterId = createChapter.body.chapter.id as string;

    const createQuestion = await request(base)
      .post('/questions')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({});
    expect(createQuestion.status).toBe(201);
    const questionId = createQuestion.body.question.id as string;

    const setTaxonomy = await request(base)
      .put(`/questions/${questionId}/taxonomy`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ stageIds: [stageId], gradeIds: [gradeId], textbookIds: [textbookId], chapterIds: [chapterId] });

    expect(setTaxonomy.status).toBe(200);
    expect(setTaxonomy.body.stages.map((stage: any) => stage.id)).toEqual([stageId]);
    expect(setTaxonomy.body.grades.map((grade: any) => grade.id)).toEqual([gradeId]);
    expect(setTaxonomy.body.textbooks.map((textbook: any) => textbook.id)).toEqual([textbookId]);
    expect(setTaxonomy.body.chapters.map((chapter: any) => chapter.id)).toEqual([chapterId]);

    const getQuestion = await request(base)
      .get(`/questions/${questionId}`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(getQuestion.status).toBe(200);
    expect(getQuestion.body.stages.map((stage: any) => stage.id)).toEqual([stageId]);
    expect(getQuestion.body.grades.map((grade: any) => grade.id)).toEqual([gradeId]);
    expect(getQuestion.body.textbooks.map((textbook: any) => textbook.id)).toEqual([textbookId]);
    expect(getQuestion.body.chapters.map((chapter: any) => chapter.id)).toEqual([chapterId]);

    const filterByStage = await request(base)
      .get('/questions')
      .query({ stageId })
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);
    expect(filterByStage.status).toBe(200);
    expect(filterByStage.body.questions.map((question: any) => question.id)).toEqual([questionId]);

    const filterByGrade = await request(base)
      .get('/questions')
      .query({ gradeId })
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);
    expect(filterByGrade.status).toBe(200);
    expect(filterByGrade.body.questions.map((question: any) => question.id)).toEqual([questionId]);

    const filterByTextbook = await request(base)
      .get('/questions')
      .query({ textbookId })
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);
    expect(filterByTextbook.status).toBe(200);
    expect(filterByTextbook.body.questions.map((question: any) => question.id)).toEqual([questionId]);

    const filterByChapter = await request(base)
      .get('/questions')
      .query({ chapterId })
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);
    expect(filterByChapter.status).toBe(200);
    expect(filterByChapter.body.questions.map((question: any) => question.id)).toEqual([questionId]);
  });
});

import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Questions list filters (e2e)', () => {
  it('filters question list by type, difficulty, subject, visibility, keyword, and limit', async () => {
    const suffix = Date.now();
    const tenant = { code: `question-filters-${suffix}`, name: 'Question Filters' };

    const login = await request(base).post('/auth/register').send({ username: `question-filters-${suffix}` });
    expect(login.status).toBe(201);
    const token = login.body.accessToken as string;

    await request(base).post('/tenants').send(tenant);
    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    const createSubject = await request(base)
      .post('/subjects')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ name: `筛选学科-${suffix}` });
    expect(createSubject.status).toBe(201);
    const subjectId = createSubject.body.subject.id as string;

    const createTag = await request(base)
      .post('/question-tags')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ name: `筛选标签-${suffix}` });
    expect(createTag.status).toBe(201);
    const tagId = createTag.body.tag.id as string;

    const createQuestionA = await request(base)
      .post('/questions')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ subjectId });
    expect(createQuestionA.status).toBe(201);
    const questionAId = createQuestionA.body.question.id as string;

    await request(base)
      .patch(`/questions/${questionAId}`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ type: 'solution', difficulty: 5, visibility: 'tenant_shared' });

    await request(base)
      .put(`/questions/${questionAId}/content`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ stemBlocks: [{ type: 'text', text: `关键字甲-${suffix}` }] });

    await request(base)
      .put(`/questions/${questionAId}/tags`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ tagIds: [tagId] });

    const createQuestionB = await request(base)
      .post('/questions')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({});
    expect(createQuestionB.status).toBe(201);
    const questionBId = createQuestionB.body.question.id as string;

    await request(base)
      .patch(`/questions/${questionBId}`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ type: 'fill_blank', difficulty: 2, visibility: 'private' });

    await request(base)
      .put(`/questions/${questionBId}/content`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ stemBlocks: [{ type: 'text', text: `关键字乙-${suffix}` }] });

    const filterByType = await request(base)
      .get('/questions')
      .query({ type: 'solution' })
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(filterByType.status).toBe(200);
    expect(filterByType.body.questions.map((question: any) => question.id)).toEqual([questionAId]);

    const filterByDifficulty = await request(base)
      .get('/questions')
      .query({ difficulty: '2' })
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(filterByDifficulty.status).toBe(200);
    expect(filterByDifficulty.body.questions.map((question: any) => question.id)).toEqual([questionBId]);

    const filterBySubject = await request(base)
      .get('/questions')
      .query({ subjectId })
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(filterBySubject.status).toBe(200);
    expect(filterBySubject.body.questions.map((question: any) => question.id)).toEqual([questionAId]);

    const filterByVisibility = await request(base)
      .get('/questions')
      .query({ visibility: 'tenant_shared' })
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(filterByVisibility.status).toBe(200);
    expect(filterByVisibility.body.questions.map((question: any) => question.id)).toEqual([questionAId]);

    const filterByKeyword = await request(base)
      .get('/questions')
      .query({ q: `甲-${suffix}`, include: 'tags,summary' })
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(filterByKeyword.status).toBe(200);
    expect(filterByKeyword.body.questions.map((question: any) => question.id)).toEqual([questionAId]);
    expect(filterByKeyword.body.questions[0].tags.map((tag: any) => tag.id)).toEqual([tagId]);
    expect(filterByKeyword.body.questions[0].summary.stemPreview).toContain(`关键字甲-${suffix}`);
    expect(filterByKeyword.body.questions[0].summary.stages).toEqual([]);
    expect(filterByKeyword.body.meta).toMatchObject({
      limit: 50,
      offset: 0,
      returned: 1,
      total: 1,
      hasMore: false,
      sortBy: 'createdAt',
      sortOrder: 'desc'
    });

    const filterByTag = await request(base)
      .get('/questions')
      .query({ tagId, include: 'tags' })
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(filterByTag.status).toBe(200);
    expect(filterByTag.body.questions.map((question: any) => question.id)).toEqual([questionAId]);
    expect(filterByTag.body.questions[0].tags.map((tag: any) => tag.id)).toEqual([tagId]);

    const limitOne = await request(base)
      .get('/questions')
      .query({ limit: '1' })
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(limitOne.status).toBe(200);
    expect(limitOne.body.questions).toHaveLength(1);
    expect(limitOne.body.meta.returned).toBe(1);
    expect(limitOne.body.meta.total).toBe(2);

    const sortAndOffset = await request(base)
      .get('/questions')
      .query({ sortBy: 'difficulty', sortOrder: 'asc', offset: '1', limit: '1' })
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(sortAndOffset.status).toBe(200);
    expect(sortAndOffset.body.questions).toHaveLength(1);
    expect(sortAndOffset.body.questions[0].id).toBe(questionAId);
    expect(sortAndOffset.body.meta).toMatchObject({
      limit: 1,
      offset: 1,
      returned: 1,
      total: 2,
      hasMore: false,
      sortBy: 'difficulty',
      sortOrder: 'asc'
    });
  });
});

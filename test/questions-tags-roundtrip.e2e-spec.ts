import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Questions tags roundtrip (e2e)', () => {
  it('validates id params', async () => {
    const suffix = Date.now();
    const tenant = { code: `question-tags-params-${suffix}`, name: 'Question Tags Params' };

    const login = await request(base).post('/auth/register').send({ username: `question-tags-params-${suffix}` });
    expect(login.status).toBe(201);
    const token = login.body.accessToken as string;

    await request(base).post('/tenants').send(tenant);
    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    const invalidSet = await request(base)
      .put('/questions/not-a-uuid/tags')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ tagIds: [] });

    expect(invalidSet.status).toBe(400);
    expect(invalidSet.body.error.code).toBe('validation_failed');
    expect(invalidSet.body.error.details).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ field: 'id', messages: expect.arrayContaining(['Invalid id']) })
      ])
    );
  });

  it('sets, lists, reads back, and replaces question tags within a tenant', async () => {
    const suffix = Date.now();
    const tenant = { code: `question-tags-roundtrip-${suffix}`, name: 'Question Tags Roundtrip' };

    const login = await request(base).post('/auth/register').send({ username: `question-tags-roundtrip-${suffix}` });
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

    const createTagA = await request(base)
      .post('/question-tags')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ name: `Tag A ${suffix}` });
    const createTagB = await request(base)
      .post('/question-tags')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ name: `Tag B ${suffix}` });

    expect(createTagA.status).toBe(201);
    expect(createTagB.status).toBe(201);

    const invalidSet = await request(base)
      .put(`/questions/${questionId}/tags`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(invalidSet.status).toBe(400);
    expect(invalidSet.body.message).toContain('Missing tagIds');
    expect(invalidSet.body.error.code).toBe('validation_failed');

    const unknownTagSet = await request(base)
      .put(`/questions/${questionId}/tags`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ tagIds: [createTagA.body.tag.id, `00000000-0000-0000-0000-000000000000`] });

    expect(unknownTagSet.status).toBe(400);
    expect(unknownTagSet.body.message).toContain('Some tags not found');

    const setTags = await request(base)
      .put(`/questions/${questionId}/tags`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ tagIds: [createTagA.body.tag.id, createTagB.body.tag.id, createTagA.body.tag.id] });

    expect(setTags.status).toBe(200);
    expect(setTags.body.tags.map((tag: any) => tag.id).sort()).toEqual(
      [createTagA.body.tag.id, createTagB.body.tag.id].sort()
    );

    const listQuestions = await request(base)
      .get('/questions?include=tags')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(listQuestions.status).toBe(200);
    const listedQuestion = listQuestions.body.questions.find((question: any) => question.id === questionId);
    expect(listedQuestion).toBeTruthy();
    expect(listedQuestion.tags.map((tag: any) => tag.id).sort()).toEqual(
      [createTagA.body.tag.id, createTagB.body.tag.id].sort()
    );

    const getQuestion = await request(base)
      .get(`/questions/${questionId}`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`);

    expect(getQuestion.status).toBe(200);
    expect(getQuestion.body.tags.map((tag: any) => tag.id).sort()).toEqual(
      [createTagA.body.tag.id, createTagB.body.tag.id].sort()
    );

    const replaceTags = await request(base)
      .put(`/questions/${questionId}/tags`)
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ tagIds: [createTagB.body.tag.id] });

    expect(replaceTags.status).toBe(200);
    expect(replaceTags.body.tags.map((tag: any) => tag.id)).toEqual([createTagB.body.tag.id]);
  });
});

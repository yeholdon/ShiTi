import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Subjects (e2e)', () => {
  it('lists system subjects for everyone and tenant subjects only within the tenant', async () => {
    const suffix = Date.now();
    const tenantA = { code: `subjects-a-${suffix}`, name: 'Subjects A' };
    const tenantB = { code: `subjects-b-${suffix}`, name: 'Subjects B' };

    const login = await request(base).post('/auth/register').send({ username: `subjects-user-${suffix}` });
    expect(login.status).toBe(201);
    const token = login.body.accessToken as string;
    expect(typeof token).toBe('string');

    await request(base).post('/tenants').send(tenantA);
    await request(base).post('/tenants').send(tenantB);

    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenantA.code, role: 'owner' });

    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenantB.code, role: 'owner' });

    const systemList = await request(base).get('/subjects').set('Authorization', `Bearer ${token}`);
    expect(systemList.status).toBe(200);
    expect(Array.isArray(systemList.body.subjects)).toBe(true);
    expect(systemList.body.subjects.length).toBeGreaterThan(0);

    const systemSubjectNames = new Set<string>(systemList.body.subjects.map((subject: any) => subject.name));
    const tenantSubjectName = `Tenant Subject ${suffix}`;

    const createSubject = await request(base)
      .post('/subjects')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`)
      .send({ name: tenantSubjectName });

    expect(createSubject.status).toBe(201);
    expect(createSubject.body.subject.name).toBe(tenantSubjectName);
    expect(createSubject.body.subject.tenantId).toBeTruthy();

    const tenantAList = await request(base)
      .get('/subjects')
      .set('X-Tenant-Code', tenantA.code)
      .set('Authorization', `Bearer ${token}`);

    expect(tenantAList.status).toBe(200);
    expect(tenantAList.body.subjects.some((subject: any) => subject.name === tenantSubjectName)).toBe(true);
    expect(
      systemList.body.subjects.every((systemSubject: any) =>
        tenantAList.body.subjects.some((subject: any) => subject.name === systemSubject.name)
      )
    ).toBe(true);

    const tenantBList = await request(base)
      .get('/subjects')
      .set('X-Tenant-Code', tenantB.code)
      .set('Authorization', `Bearer ${token}`);

    expect(tenantBList.status).toBe(200);
    expect(tenantBList.body.subjects.some((subject: any) => subject.name === tenantSubjectName)).toBe(false);
    expect(
      [...systemSubjectNames].every((name) => tenantBList.body.subjects.some((subject: any) => subject.name === name))
    ).toBe(true);
  });
});

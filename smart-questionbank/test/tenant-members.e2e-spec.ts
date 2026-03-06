import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Tenant members (e2e)', () => {
  it('returns 400 when tenantCode is missing', async () => {
    const suffix = Date.now();
    const login = await request(base).post('/auth/register').send({ username: `tenant-members-empty-${suffix}` });
    expect(login.status).toBe(201);

    const res = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${login.body.accessToken}`)
      .send({});

    expect(res.status).toBe(400);
    expect(res.body.message).toContain('Missing tenantCode');
  });

  it('returns 404 for unknown tenant and upserts membership role when tenant exists', async () => {
    const suffix = Date.now();
    const tenant = { code: `tenant-members-${suffix}`, name: 'Tenant Members' };

    const login = await request(base).post('/auth/register').send({ username: `tenant-members-${suffix}` });
    expect(login.status).toBe(201);
    const token = login.body.accessToken as string;

    const missingTenant = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: `missing-${suffix}` });

    expect(missingTenant.status).toBe(404);
    expect(missingTenant.body.message).toContain('Tenant not found');

    await request(base).post('/tenants').send(tenant);

    const joinAsMember = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'member' });

    expect(joinAsMember.status).toBe(201);
    expect(joinAsMember.body.membership.role).toBe('member');
    expect(joinAsMember.body.membership.status).toBe('active');

    const joinAsOwner = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    expect(joinAsOwner.status).toBe(201);
    expect(joinAsOwner.body.membership.role).toBe('owner');
    expect(joinAsOwner.body.membership.status).toBe('active');
    expect(joinAsOwner.body.membership.tenantId).toBe(joinAsMember.body.membership.tenantId);
    expect(joinAsOwner.body.membership.id).toBe(joinAsMember.body.membership.id);
  });
});

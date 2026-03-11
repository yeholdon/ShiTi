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
    expect(res.body.statusCode).toBe(400);
    expect(res.body.error.code).toBe('validation_failed');
    expect(res.body.path).toBe('/tenant-members');
    expect(typeof res.body.timestamp).toBe('string');
  });

  it('returns 404 for unknown tenant, joins existing tenants, and blocks self-escalation for non-owners', async () => {
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
    expect(missingTenant.body.error.code).toBe('not_found');

    await request(base).post('/tenants').send(tenant);

    const joinAsMember = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'member' });

    expect(joinAsMember.status).toBe(201);
    expect(joinAsMember.body.membership.role).toBe('member');
    expect(joinAsMember.body.membership.status).toBe('active');

    const rejoinAsMember = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'member' });

    expect(rejoinAsMember.status).toBe(201);
    expect(rejoinAsMember.body.membership.role).toBe('member');
    expect(rejoinAsMember.body.membership.status).toBe('active');
    expect(rejoinAsMember.body.membership.tenantId).toBe(joinAsMember.body.membership.tenantId);
    expect(rejoinAsMember.body.membership.id).toBe(joinAsMember.body.membership.id);

    const joinAsOwner = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${token}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    expect(joinAsOwner.status).toBe(400);
    expect(joinAsOwner.body.message).toContain('Only tenant owners can grant admin or owner roles');
    expect(joinAsOwner.body.error.code).toBe('bad_request');
  });

  it('allows owners to update tenant roles while protecting last-owner invariants', async () => {
    const suffix = Date.now();
    const tenant = { code: `tenant-member-role-${suffix}`, name: 'Tenant Member Role' };

    await request(base).post('/tenants').send(tenant);

    const ownerLogin = await request(base).post('/auth/register').send({ username: `tenant-owner-${suffix}` });
    expect(ownerLogin.status).toBe(201);
    const ownerToken = ownerLogin.body.accessToken as string;

    const secondLogin = await request(base).post('/auth/register').send({ username: `tenant-second-${suffix}` });
    expect(secondLogin.status).toBe(201);
    const secondToken = secondLogin.body.accessToken as string;

    const ownerJoin = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    expect(ownerJoin.status).toBe(201);

    const secondJoin = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${secondToken}`)
      .send({ tenantCode: tenant.code, role: 'member' });

    expect(secondJoin.status).toBe(201);

    const promoteAdmin = await request(base)
      .patch(`/tenant-members/${secondJoin.body.membership.id}/role`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('X-Tenant-Code', tenant.code)
      .send({ role: 'admin' });

    expect(promoteAdmin.status).toBe(200);
    expect(promoteAdmin.body.membership.role).toBe('admin');

    const selfDemote = await request(base)
      .patch(`/tenant-members/${promoteAdmin.body.membership.id}/role`)
      .set('Authorization', `Bearer ${secondToken}`)
      .set('X-Tenant-Code', tenant.code)
      .send({ role: 'member' });

    expect(selfDemote.status).toBe(403);
    expect(selfDemote.body.error.code).toBe('forbidden');

    const ownerSelfDemote = await request(base)
      .patch(`/tenant-members/${ownerJoin.body.membership.id}/role`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('X-Tenant-Code', tenant.code)
      .send({ role: 'member' });

    expect(ownerSelfDemote.status).toBe(400);
    expect(String(ownerSelfDemote.body.message)).toContain('Owners cannot demote themselves');

    const thirdLogin = await request(base).post('/auth/register').send({ username: `tenant-third-${suffix}` });
    expect(thirdLogin.status).toBe(201);
    const thirdToken = thirdLogin.body.accessToken as string;

    const thirdJoin = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${thirdToken}`)
      .send({ tenantCode: tenant.code, role: 'member' });

    expect(thirdJoin.status).toBe(201);

    const promoteOwner = await request(base)
      .patch(`/tenant-members/${thirdJoin.body.membership.id}/role`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('X-Tenant-Code', tenant.code)
      .send({ role: 'owner' });

    expect(promoteOwner.status).toBe(200);
    expect(promoteOwner.body.membership.role).toBe('owner');

    const demoteFormerOwner = await request(base)
      .patch(`/tenant-members/${ownerJoin.body.membership.id}/role`)
      .set('Authorization', `Bearer ${thirdToken}`)
      .set('X-Tenant-Code', tenant.code)
      .send({ role: 'admin' });

    expect(demoteFormerOwner.status).toBe(200);
    expect(demoteFormerOwner.body.membership.role).toBe('admin');
  });

  it('converges concurrent joins for the same tenant membership to one active row', async () => {
    const suffix = Date.now();
    const tenant = { code: `tenant-members-race-${suffix}`, name: 'Tenant Members Race' };

    await request(base).post('/tenants').send(tenant);

    const login = await request(base).post('/auth/register').send({ username: `tenant-members-race-${suffix}` });
    expect(login.status).toBe(201);
    const token = login.body.accessToken as string;

    const joins = await Promise.all(
      Array.from({ length: 5 }, () =>
        request(base)
          .post('/tenant-members')
          .set('Authorization', `Bearer ${token}`)
          .send({ tenantCode: tenant.code, role: 'owner' })
      )
    );

    for (const join of joins) {
      expect(join.status).toBe(201);
      expect(join.body.membership.role).toBe('owner');
      expect(join.body.membership.status).toBe('active');
    }

    const ids = new Set(joins.map((join) => join.body.membership.id));
    const tenantIds = new Set(joins.map((join) => join.body.membership.tenantId));

    expect(ids.size).toBe(1);
    expect(tenantIds.size).toBe(1);
  });
});

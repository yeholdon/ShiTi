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
    expect(promoteAdmin.body.membership.username).toBe(`tenant-second-${suffix}`);

    const ownerList = await request(base)
      .get('/tenant-members')
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('X-Tenant-Code', tenant.code);

    expect(ownerList.status).toBe(200);
    expect(ownerList.body.members.length).toBeGreaterThanOrEqual(2);
    expect(ownerList.body.members.some((member: any) => member.username === `tenant-second-${suffix}` && member.role == 'admin')).toBe(true);

    const selfDemote = await request(base)
      .patch(`/tenant-members/${promoteAdmin.body.membership.id}/role`)
      .set('Authorization', `Bearer ${secondToken}`)
      .set('X-Tenant-Code', tenant.code)
      .send({ role: 'member' });

    expect(selfDemote.status).toBe(403);
    expect(selfDemote.body.error.code).toBe('forbidden');

    const adminList = await request(base)
      .get('/tenant-members')
      .set('Authorization', `Bearer ${secondToken}`)
      .set('X-Tenant-Code', tenant.code);

    expect(adminList.status).toBe(200);
    expect(adminList.body.members.some((member: any) => member.username === `tenant-second-${suffix}` && member.role == 'admin')).toBe(true);

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

    const memberListForbidden = await request(base)
      .get('/tenant-members')
      .set('Authorization', `Bearer ${thirdToken}`)
      .set('X-Tenant-Code', tenant.code);

    expect(memberListForbidden.status).toBe(403);
    expect(memberListForbidden.body.error.code).toBe('forbidden');

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

  it('allows admins and owners to add existing users while restricting elevated grants', async () => {
    const suffix = Date.now();
    const tenant = { code: `tenant-member-add-${suffix}`, name: 'Tenant Member Add' };

    await request(base).post('/tenants').send(tenant);

    const ownerLogin = await request(base).post('/auth/register').send({ username: `tenant-add-owner-${suffix}` });
    expect(ownerLogin.status).toBe(201);
    const ownerToken = ownerLogin.body.accessToken as string;

    const adminLogin = await request(base).post('/auth/register').send({ username: `tenant-add-admin-${suffix}` });
    expect(adminLogin.status).toBe(201);
    const adminToken = adminLogin.body.accessToken as string;

    const targetLogin = await request(base).post('/auth/register').send({ username: `tenant-add-target-${suffix}` });
    expect(targetLogin.status).toBe(201);

    const elevatedLogin = await request(base).post('/auth/register').send({ username: `tenant-add-elevated-${suffix}` });
    expect(elevatedLogin.status).toBe(201);

    const ownerJoin = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    expect(ownerJoin.status).toBe(201);

    const adminJoin = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ tenantCode: tenant.code, role: 'member' });

    expect(adminJoin.status).toBe(201);

    const promoteAdmin = await request(base)
      .patch(`/tenant-members/${adminJoin.body.membership.id}/role`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('X-Tenant-Code', tenant.code)
      .send({ role: 'admin' });

    expect(promoteAdmin.status).toBe(200);

    const addByAdmin = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        tenantCode: tenant.code,
        username: `tenant-add-target-${suffix}`,
        role: 'member',
      });

    expect(addByAdmin.status).toBe(201);
    expect(addByAdmin.body.membership.username).toBe(`tenant-add-target-${suffix}`);
    expect(addByAdmin.body.membership.role).toBe('member');

    const ownerList = await request(base)
      .get('/tenant-members')
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('X-Tenant-Code', tenant.code);

    expect(ownerList.status).toBe(200);
    expect(ownerList.body.members.some((member: any) => member.username === `tenant-add-target-${suffix}`)).toBe(true);

    const adminElevatedAdd = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        tenantCode: tenant.code,
        username: `tenant-add-elevated-${suffix}`,
        role: 'admin',
      });

    expect(adminElevatedAdd.status).toBe(403);
    expect(String(adminElevatedAdd.body.message)).toContain('Only tenant owners can grant admin or owner roles');

    const ownerElevatedAdd = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({
        tenantCode: tenant.code,
        username: `tenant-add-elevated-${suffix}`,
        role: 'admin',
      });

    expect(ownerElevatedAdd.status).toBe(201);
    expect(ownerElevatedAdd.body.membership.username).toBe(`tenant-add-elevated-${suffix}`);
    expect(ownerElevatedAdd.body.membership.role).toBe('admin');
  });

  it('allows status updates while keeping elevated-member protection', async () => {
    const suffix = Date.now();
    const tenant = { code: `tenant-member-status-${suffix}`, name: 'Tenant Member Status' };

    await request(base).post('/tenants').send(tenant);

    const ownerLogin = await request(base).post('/auth/register').send({ username: `tenant-status-owner-${suffix}` });
    expect(ownerLogin.status).toBe(201);
    const ownerToken = ownerLogin.body.accessToken as string;

    const adminLogin = await request(base).post('/auth/register').send({ username: `tenant-status-admin-${suffix}` });
    expect(adminLogin.status).toBe(201);
    const adminToken = adminLogin.body.accessToken as string;

    const memberLogin = await request(base).post('/auth/register').send({ username: `tenant-status-member-${suffix}` });
    expect(memberLogin.status).toBe(201);
    const memberToken = memberLogin.body.accessToken as string;

    const ownerJoin = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ tenantCode: tenant.code, role: 'owner' });
    expect(ownerJoin.status).toBe(201);

    const adminJoin = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ tenantCode: tenant.code, role: 'member' });
    expect(adminJoin.status).toBe(201);

    const promoteAdmin = await request(base)
      .patch(`/tenant-members/${adminJoin.body.membership.id}/role`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('X-Tenant-Code', tenant.code)
      .send({ role: 'admin' });
    expect(promoteAdmin.status).toBe(200);

    const memberJoin = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${memberToken}`)
      .send({ tenantCode: tenant.code, role: 'member' });
    expect(memberJoin.status).toBe(201);

    const disableMemberByAdmin = await request(base)
      .patch(`/tenant-members/${memberJoin.body.membership.id}/status`)
      .set('Authorization', `Bearer ${adminToken}`)
      .set('X-Tenant-Code', tenant.code)
      .send({ status: 'disabled' });
    expect(disableMemberByAdmin.status).toBe(200);
    expect(disableMemberByAdmin.body.membership.status).toBe('disabled');

    const reactivateMemberByAdmin = await request(base)
      .patch(`/tenant-members/${memberJoin.body.membership.id}/status`)
      .set('Authorization', `Bearer ${adminToken}`)
      .set('X-Tenant-Code', tenant.code)
      .send({ status: 'active' });
    expect(reactivateMemberByAdmin.status).toBe(200);
    expect(reactivateMemberByAdmin.body.membership.status).toBe('active');

    const disableAdminByAdmin = await request(base)
      .patch(`/tenant-members/${adminJoin.body.membership.id}/status`)
      .set('Authorization', `Bearer ${adminToken}`)
      .set('X-Tenant-Code', tenant.code)
      .send({ status: 'disabled' });
    expect(disableAdminByAdmin.status).toBe(403);
    expect(String(disableAdminByAdmin.body.message)).toContain('Only tenant owners can update admin or owner member status');

    const disableAdminByOwner = await request(base)
      .patch(`/tenant-members/${adminJoin.body.membership.id}/status`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('X-Tenant-Code', tenant.code)
      .send({ status: 'disabled' });
    expect(disableAdminByOwner.status).toBe(200);
    expect(disableAdminByOwner.body.membership.status).toBe('disabled');

    const selfDisableOwner = await request(base)
      .patch(`/tenant-members/${ownerJoin.body.membership.id}/status`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('X-Tenant-Code', tenant.code)
      .send({ status: 'disabled' });
    expect(selfDisableOwner.status).toBe(400);
    expect(String(selfDisableOwner.body.message)).toContain('Members cannot disable themselves');
  });

  it('allows member removal while keeping elevated-member protection', async () => {
    const suffix = Date.now();
    const tenant = { code: `tenant-member-remove-${suffix}`, name: 'Tenant Member Remove' };

    await request(base).post('/tenants').send(tenant);

    const ownerLogin = await request(base).post('/auth/register').send({ username: `tenant-remove-owner-${suffix}` });
    expect(ownerLogin.status).toBe(201);
    const ownerToken = ownerLogin.body.accessToken as string;

    const adminLogin = await request(base).post('/auth/register').send({ username: `tenant-remove-admin-${suffix}` });
    expect(adminLogin.status).toBe(201);
    const adminToken = adminLogin.body.accessToken as string;

    const memberLogin = await request(base).post('/auth/register').send({ username: `tenant-remove-member-${suffix}` });
    expect(memberLogin.status).toBe(201);
    const memberToken = memberLogin.body.accessToken as string;

    const ownerJoin = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ tenantCode: tenant.code, role: 'owner' });
    expect(ownerJoin.status).toBe(201);

    const adminJoin = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ tenantCode: tenant.code, role: 'member' });
    expect(adminJoin.status).toBe(201);

    const promoteAdmin = await request(base)
      .patch(`/tenant-members/${adminJoin.body.membership.id}/role`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('X-Tenant-Code', tenant.code)
      .send({ role: 'admin' });
    expect(promoteAdmin.status).toBe(200);

    const memberJoin = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${memberToken}`)
      .send({ tenantCode: tenant.code, role: 'member' });
    expect(memberJoin.status).toBe(201);

    const removeMemberByAdmin = await request(base)
      .delete(`/tenant-members/${memberJoin.body.membership.id}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .set('X-Tenant-Code', tenant.code);
    expect(removeMemberByAdmin.status).toBe(200);
    expect(removeMemberByAdmin.body.removed).toBe(true);

    const ownerList = await request(base)
      .get('/tenant-members')
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('X-Tenant-Code', tenant.code);
    expect(ownerList.status).toBe(200);
    expect(ownerList.body.members.some((member: any) => member.username === `tenant-remove-member-${suffix}`)).toBe(false);

    const removeAdminByAdmin = await request(base)
      .delete(`/tenant-members/${adminJoin.body.membership.id}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .set('X-Tenant-Code', tenant.code);
    expect(removeAdminByAdmin.status).toBe(403);
    expect(String(removeAdminByAdmin.body.message)).toContain('Only tenant owners can remove admin or owner members');

    const selfRemoveOwner = await request(base)
      .delete(`/tenant-members/${ownerJoin.body.membership.id}`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('X-Tenant-Code', tenant.code);
    expect(selfRemoveOwner.status).toBe(400);
    expect(String(selfRemoveOwner.body.message)).toContain('Members cannot remove themselves');
  });

  it('supports invited memberships that activate on self-join', async () => {
    const suffix = Date.now();
    const tenant = { code: `tenant-member-invite-${suffix}`, name: 'Tenant Member Invite' };

    await request(base).post('/tenants').send(tenant);

    const ownerLogin = await request(base).post('/auth/register').send({ username: `tenant-invite-owner-${suffix}` });
    expect(ownerLogin.status).toBe(201);
    const ownerToken = ownerLogin.body.accessToken as string;

    const invitedLogin = await request(base).post('/auth/register').send({ username: `tenant-invite-user-${suffix}` });
    expect(invitedLogin.status).toBe(201);
    const invitedToken = invitedLogin.body.accessToken as string;

    const ownerJoin = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ tenantCode: tenant.code, role: 'owner' });
    expect(ownerJoin.status).toBe(201);

    const invite = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({
        tenantCode: tenant.code,
        username: `tenant-invite-user-${suffix}`,
        role: 'member',
        status: 'invited',
      });
    expect(invite.status).toBe(201);
    expect(invite.body.membership.status).toBe('invited');

    const ownerListBefore = await request(base)
      .get('/tenant-members')
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('X-Tenant-Code', tenant.code);
    expect(ownerListBefore.status).toBe(200);
    expect(ownerListBefore.body.members.some((member: any) => member.username === `tenant-invite-user-${suffix}` && member.status === 'invited')).toBe(true);

    const activate = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${invitedToken}`)
      .send({ tenantCode: tenant.code, role: 'member' });
    expect(activate.status).toBe(201);
    expect(activate.body.membership.status).toBe('active');

    const ownerListAfter = await request(base)
      .get('/tenant-members')
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('X-Tenant-Code', tenant.code);
    expect(ownerListAfter.status).toBe(200);
    expect(ownerListAfter.body.members.some((member: any) => member.username === `tenant-invite-user-${suffix}` && member.status === 'active')).toBe(true);
  });

  it('allows resending invitations for invited memberships only', async () => {
    const suffix = Date.now();
    const tenant = { code: `tenant-member-resend-${suffix}`, name: 'Tenant Member Resend' };

    await request(base).post('/tenants').send(tenant);

    const ownerLogin = await request(base).post('/auth/register').send({ username: `tenant-resend-owner-${suffix}` });
    expect(ownerLogin.status).toBe(201);
    const ownerToken = ownerLogin.body.accessToken as string;

    const invitedLogin = await request(base).post('/auth/register').send({ username: `tenant-resend-user-${suffix}` });
    expect(invitedLogin.status).toBe(201);

    const ownerJoin = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ tenantCode: tenant.code, role: 'owner' });
    expect(ownerJoin.status).toBe(201);

    const invite = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({
        tenantCode: tenant.code,
        username: `tenant-resend-user-${suffix}`,
        role: 'member',
        status: 'invited',
      });
    expect(invite.status).toBe(201);
    expect(invite.body.membership.status).toBe('invited');

    const resend = await request(base)
      .post(`/tenant-members/${invite.body.membership.id}/resend-invite`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('X-Tenant-Code', tenant.code);
    expect(resend.status).toBe(201);
    expect(resend.body.resent).toBe(true);
    expect(resend.body.membership.status).toBe('invited');

    const activate = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${invitedLogin.body.accessToken as string}`)
      .send({ tenantCode: tenant.code, role: 'member' });
    expect(activate.status).toBe(201);

    const resendActive = await request(base)
      .post(`/tenant-members/${invite.body.membership.id}/resend-invite`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('X-Tenant-Code', tenant.code);
    expect(resendActive.status).toBe(400);
    expect(String(resendActive.body.message)).toContain(
      'Only invited tenant members can be resent invitations'
    );
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

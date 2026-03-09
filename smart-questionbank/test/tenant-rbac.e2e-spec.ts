import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Tenant RBAC (e2e)', () => {
  it('allows the first tenant member to become owner and blocks member-level write escalation', async () => {
    const suffix = Date.now();
    const tenant = { code: `rbac-${suffix}`, name: 'RBAC Tenant' };

    await request(base).post('/tenants').send(tenant);

    const ownerReg = await request(base).post('/auth/register').send({ username: `rbac-owner-${suffix}` });
    const ownerToken = ownerReg.body.accessToken;

    const ownerJoin = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    expect(ownerJoin.status).toBe(201);
    expect(ownerJoin.body.membership.role).toBe('owner');

    const memberReg = await request(base).post('/auth/register').send({ username: `rbac-member-${suffix}` });
    const memberToken = memberReg.body.accessToken;

    const memberJoin = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${memberToken}`)
      .send({ tenantCode: tenant.code, role: 'member' });

    expect(memberJoin.status).toBe(201);
    expect(memberJoin.body.membership.role).toBe('member');

    const adminReg = await request(base).post('/auth/register').send({ username: `rbac-admin-${suffix}` });
    const adminToken = adminReg.body.accessToken;

    const adminJoin = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ tenantCode: tenant.code, role: 'member' });

    expect(adminJoin.status).toBe(201);
    expect(adminJoin.body.membership.role).toBe('member');

    const promoteAdmin = await request(base)
      .patch(`/tenant-members/${adminJoin.body.membership.id}/role`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('X-Tenant-Code', tenant.code)
      .send({ role: 'admin' });

    expect(promoteAdmin.status).toBe(200);
    expect(promoteAdmin.body.membership.role).toBe('admin');

    const escalate = await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${memberToken}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    expect(escalate.status).toBe(400);
    expect(String(escalate.body.message)).toContain('Only tenant owners can grant admin or owner roles');

    const memberCreateTag = await request(base)
      .post('/question-tags')
      .set('Authorization', `Bearer ${memberToken}`)
      .set('X-Tenant-Code', tenant.code)
      .send({ name: 'member-tag' });

    expect(memberCreateTag.status).toBe(403);
    expect(memberCreateTag.body.error.code).toBe('forbidden');
    expect(String(memberCreateTag.body.message)).toContain('Insufficient tenant role');

    const memberCreateDocument = await request(base)
      .post('/documents')
      .set('Authorization', `Bearer ${memberToken}`)
      .set('X-Tenant-Code', tenant.code)
      .send({ name: 'member-doc', kind: 'paper' });

    expect(memberCreateDocument.status).toBe(403);
    expect(memberCreateDocument.body.error.code).toBe('forbidden');
    expect(String(memberCreateDocument.body.message)).toContain('Insufficient tenant role');

    const ownerCreateTag = await request(base)
      .post('/question-tags')
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('X-Tenant-Code', tenant.code)
      .send({ name: 'owner-tag' });

    expect(ownerCreateTag.status).toBe(201);
    expect(ownerCreateTag.body.tag.name).toBe('owner-tag');

    const adminCreateDocument = await request(base)
      .post('/documents')
      .set('Authorization', `Bearer ${adminToken}`)
      .set('X-Tenant-Code', tenant.code)
      .send({ name: 'admin-doc', kind: 'paper' });

    expect(adminCreateDocument.status).toBe(201);
    expect(adminCreateDocument.body.document.name).toBe('admin-doc');

    const memberListTags = await request(base)
      .get('/question-tags')
      .set('Authorization', `Bearer ${memberToken}`)
      .set('X-Tenant-Code', tenant.code);

    expect(memberListTags.status).toBe(200);
    expect(memberListTags.body.tags.some((tag: any) => tag.name === 'owner-tag')).toBe(true);

    const createdDoc = await request(base)
      .post('/documents')
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('X-Tenant-Code', tenant.code)
      .send({ name: 'RBAC Export Doc', kind: 'paper' });

    expect(createdDoc.status).toBe(201);

    const memberCreateExport = await request(base)
      .post('/export-jobs')
      .set('Authorization', `Bearer ${memberToken}`)
      .set('X-Tenant-Code', tenant.code)
      .send({ documentId: createdDoc.body.document.id });

    expect(memberCreateExport.status).toBe(403);
    expect(memberCreateExport.body.error.code).toBe('forbidden');
    expect(String(memberCreateExport.body.message)).toContain('Insufficient tenant role');

    const adminCreateExport = await request(base)
      .post('/export-jobs')
      .set('Authorization', `Bearer ${adminToken}`)
      .set('X-Tenant-Code', tenant.code)
      .send({ documentId: createdDoc.body.document.id });

    expect([201, 503]).toContain(adminCreateExport.status);

    const adminAssetCleanup = await request(base)
      .post('/assets/cleanup')
      .set('Authorization', `Bearer ${adminToken}`)
      .set('X-Tenant-Code', tenant.code)
      .send({ staleHours: 1 });

    expect(adminAssetCleanup.status).toBe(403);
    expect(adminAssetCleanup.body.error.code).toBe('forbidden');

    const adminExportCleanup = await request(base)
      .post('/export-jobs/cleanup')
      .set('Authorization', `Bearer ${adminToken}`)
      .set('X-Tenant-Code', tenant.code)
      .send({ staleHours: 1, retainHours: 1 });

    expect(adminExportCleanup.status).toBe(403);
    expect(adminExportCleanup.body.error.code).toBe('forbidden');

    const ownerAssetCleanup = await request(base)
      .post('/assets/cleanup')
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('X-Tenant-Code', tenant.code)
      .send({ staleHours: 1 });

    expect(ownerAssetCleanup.status).toBe(201);

    const ownerExportCleanup = await request(base)
      .post('/export-jobs/cleanup')
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('X-Tenant-Code', tenant.code)
      .send({ staleHours: 1, retainHours: 1 });

    expect(ownerExportCleanup.status).toBe(201);

    const memberListExports = await request(base)
      .get('/export-jobs')
      .set('Authorization', `Bearer ${memberToken}`)
      .set('X-Tenant-Code', tenant.code);

    expect(memberListExports.status).toBe(200);

    const memberAuditLogs = await request(base)
      .get('/audit-logs')
      .set('Authorization', `Bearer ${memberToken}`)
      .set('X-Tenant-Code', tenant.code);

    expect(memberAuditLogs.status).toBe(403);
    expect(memberAuditLogs.body.error.code).toBe('forbidden');
    expect(String(memberAuditLogs.body.message)).toContain('Insufficient tenant role');
  });
});

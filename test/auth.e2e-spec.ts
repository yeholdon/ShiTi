import request from 'supertest';

const base = process.env.E2E_BASE_URL || 'http://localhost:3000';

describe('Auth (e2e)', () => {
  it('rate limits register by client ip', async () => {
    const suffix = Date.now();
    const ip = `198.51.100.${(suffix % 200) + 1}`;

    for (let index = 0; index < 5; index += 1) {
      const res = await request(base)
        .post('/auth/register')
        .set('X-Test-Rate-Limit', 'on')
        .set('X-Forwarded-For', ip)
        .send({ username: `rate-limit-${suffix}-${index}`, password: 'secret' });

      expect(res.status).toBe(201);
    }

    const limited = await request(base)
      .post('/auth/register')
      .set('X-Test-Rate-Limit', 'on')
      .set('X-Forwarded-For', ip)
      .send({ username: `rate-limit-${suffix}-blocked`, password: 'secret' });

    expect(limited.status).toBe(429);
    expect(limited.body.error.code).toBe('too_many_requests');
    expect(String(limited.body.message)).toContain('Rate limit exceeded');
  });

  it('validates username on register', async () => {
    const res = await request(base).post('/auth/register').send({});

    expect(res.status).toBe(400);
    expect(res.body.message).toContain('Missing username');
    expect(res.body.error.code).toBe('validation_failed');
    expect(res.body.error.details[0].field).toBe('username');
  });

  it('rejects /questions without Bearer token, then allows with token', async () => {
    const suffix = Date.now();
    const tenant = { code: `auth-tenant-${suffix}`, name: 'Auth Tenant' };
    const username = `u1-${suffix}`;

    await request(base).post('/tenants').send(tenant);

    const res401 = await request(base).get('/questions').set('X-Tenant-Code', tenant.code);
    expect([401, 403]).toContain(res401.status);

    const login = await request(base)
      .post('/auth/register')
      .send({ username, password: 'secret' });
    expect(login.status).toBe(201);
    expect(typeof login.body.accessToken).toBe('string');

    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${login.body.accessToken}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    const res200 = await request(base)
      .get('/questions')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${login.body.accessToken}`);

    expect(res200.status).toBe(200);
    expect(Array.isArray(res200.body.questions)).toBe(true);
  });

  it('lists active tenants for the authenticated user', async () => {
    const suffix = Date.now();
    const tenant = { code: `tenant-list-${suffix}`, name: 'Tenant List' };

    await request(base).post('/tenants').send(tenant);

    const login = await request(base)
      .post('/auth/register')
      .send({ username: `tenant-list-${suffix}`, password: 'secret' });
    expect(login.status).toBe(201);

    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${login.body.accessToken}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    const res = await request(base)
      .get('/tenants')
      .set('Authorization', `Bearer ${login.body.accessToken}`);

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.tenants)).toBe(true);
    expect(res.body.tenants).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          code: tenant.code,
          name: tenant.name,
          role: 'owner'
        })
      ])
    );
  }, 10000);

  it('auto-joins the authenticated creator as owner when creating a tenant', async () => {
    const suffix = Date.now();
    const tenant = { code: `auto-join-${suffix}`, name: 'Auto Join Tenant' };

    const login = await request(base)
      .post('/auth/register')
      .send({ username: `auto-join-${suffix}`, password: 'secret' });
    expect(login.status).toBe(201);

    const created = await request(base)
      .post('/tenants')
      .set('Authorization', `Bearer ${login.body.accessToken}`)
      .send(tenant);
    expect(created.status).toBe(201);

    const listed = await request(base)
      .get('/tenants')
      .set('Authorization', `Bearer ${login.body.accessToken}`);
    expect(listed.status).toBe(200);
    expect(listed.body.tenants).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          code: tenant.code,
          name: tenant.name,
          role: 'owner',
        }),
      ])
    );

    const canReadQuestions = await request(base)
      .get('/questions')
      .set('X-Tenant-Code', tenant.code)
      .set('Authorization', `Bearer ${login.body.accessToken}`);
    expect(canReadQuestions.status).toBe(200);
  }, 10000);

  it('rejects login with the wrong password', async () => {
    const suffix = Date.now();
    const username = `wrong-password-${suffix}`;

    const register = await request(base)
      .post('/auth/register')
      .send({ username, password: 'secret-ok' });
    expect(register.status).toBe(201);

    const login = await request(base)
      .post('/auth/login')
      .send({ username, password: 'secret-bad' });

    expect(login.status).toBe(401);
    expect(String(login.body.message)).toContain('Invalid password');
  });

  it('changes password and invalidates the previous token', async () => {
    const suffix = Date.now();
    const tenant = { code: `change-password-${suffix}`, name: 'Change Password Tenant' };
    const username = `change-password-${suffix}`;

    await request(base).post('/tenants').send(tenant);

    const register = await request(base)
      .post('/auth/register')
      .send({ username, password: 'secret-old' });
    expect(register.status).toBe(201);

    await request(base)
      .post('/tenant-members')
      .set('Authorization', `Bearer ${register.body.accessToken}`)
      .send({ tenantCode: tenant.code, role: 'owner' });

    const change = await request(base)
      .post('/auth/change-password')
      .set('Authorization', `Bearer ${register.body.accessToken}`)
      .send({ currentPassword: 'secret-old', newPassword: 'secret-new' });
    expect(change.status).toBe(201);

    const stale = await request(base)
      .get('/tenants')
      .set('Authorization', `Bearer ${register.body.accessToken}`);
    expect(stale.status).toBe(401);

    const oldLogin = await request(base)
      .post('/auth/login')
      .send({ username, password: 'secret-old' });
    expect(oldLogin.status).toBe(401);

    const freshLogin = await request(base)
      .post('/auth/login')
      .send({ username, password: 'secret-new' });
    expect(freshLogin.status).toBe(201);
  });

  it('logout invalidates the current token', async () => {
    const suffix = Date.now();
    const username = `logout-${suffix}`;

    const register = await request(base)
      .post('/auth/register')
      .send({ username, password: 'secret' });
    expect(register.status).toBe(201);

    const logout = await request(base)
      .post('/auth/logout')
      .set('Authorization', `Bearer ${register.body.accessToken}`);
    expect(logout.status).toBe(201);

    const stale = await request(base)
      .get('/tenants')
      .set('Authorization', `Bearer ${register.body.accessToken}`);
    expect(stale.status).toBe(401);

    const relogin = await request(base)
      .post('/auth/login')
      .send({ username, password: 'secret' });
    expect(relogin.status).toBe(201);
  });

  it('resets password through a one-time reset token', async () => {
    const suffix = Date.now();
    const username = `reset-password-${suffix}`;

    const register = await request(base)
      .post('/auth/register')
      .send({ username, password: 'secret-old' });
    expect(register.status).toBe(201);

    const requestReset = await request(base)
      .post('/auth/request-password-reset')
      .send({ username });
    expect(requestReset.status).toBe(201);
    expect(requestReset.body.deliveryMode).toBe('preview');
    expect(requestReset.body.deliveryTransport).toBe('inline');
    expect(typeof requestReset.body.resetTokenPreview).toBe('string');

    const reset = await request(base)
      .post('/auth/reset-password')
      .send({
        username,
        resetToken: requestReset.body.resetTokenPreview,
        newPassword: 'secret-new',
      });
    expect(reset.status).toBe(201);

    const oldLogin = await request(base)
      .post('/auth/login')
      .send({ username, password: 'secret-old' });
    expect(oldLogin.status).toBe(401);

    const newLogin = await request(base)
      .post('/auth/login')
      .send({ username, password: 'secret-new' });
    expect(newLogin.status).toBe(201);
  });

  it('applies cooldown when requesting reset tokens repeatedly', async () => {
    const suffix = Date.now();
    const username = `reset-cooldown-${suffix}`;

    const register = await request(base)
      .post('/auth/register')
      .send({ username, password: 'secret-old' });
    expect(register.status).toBe(201);

    const first = await request(base)
      .post('/auth/request-password-reset')
      .send({ username });
    expect(first.status).toBe(201);
    expect(typeof first.body.resetTokenPreview).toBe('string');
    expect(first.body.deliveryMode).toBe('preview');
    expect(first.body.deliveryTransport).toBe('inline');
    expect(typeof first.body.previewHint).toBe('string');

    const second = await request(base)
      .post('/auth/request-password-reset')
      .send({ username });
    expect(second.status).toBe(201);
    expect(second.body.resetTokenPreview).toBeUndefined();
    expect(second.body.previewHint).toBe(first.body.previewHint);
    expect(Number(second.body.cooldownSeconds)).toBeGreaterThan(0);
  });

  it('supports console delivery mode for password reset requests', async () => {
    const suffix = Date.now();
    const username = `reset-console-${suffix}`;

    const register = await request(base)
      .post('/auth/register')
      .send({ username, password: 'secret-old' });
    expect(register.status).toBe(201);

    const requestReset = await request(base)
      .post('/auth/request-password-reset')
      .send({ username, deliveryMode: 'console' });
    expect(requestReset.status).toBe(201);
    expect(requestReset.body.deliveryMode).toBe('console');
    expect(requestReset.body.deliveryTransport).toBe('console');
    expect(requestReset.body.resetTokenPreview).toBeUndefined();
    expect(typeof requestReset.body.previewHint).toBe('string');
    expect(typeof requestReset.body.requestId).toBe('string');
  });

  it('supports email delivery mode for email-style usernames', async () => {
    const suffix = Date.now();
    const username = `reset-email-${suffix}@example.com`;

    const register = await request(base)
      .post('/auth/register')
      .send({ username, password: 'secret-old' });
    expect(register.status).toBe(201);

    const requestReset = await request(base)
      .post('/auth/request-password-reset')
      .send({ username, deliveryMode: 'email' });
    expect(requestReset.status).toBe(201);
    expect(requestReset.body.deliveryMode).toBe('email');
    expect(requestReset.body.deliveryTransport).toBe('console');
    expect(requestReset.body.resetTokenPreview).toBeUndefined();
    expect(typeof requestReset.body.previewHint).toBe('string');
    expect(typeof requestReset.body.requestId).toBe('string');
  });

  it('lists recent password reset email events for authenticated users', async () => {
    const suffix = Date.now();
    const username = `reset-events-${suffix}@example.com`;

    const register = await request(base)
      .post('/auth/register')
      .send({ username, password: 'secret-old' });
    expect(register.status).toBe(201);

    const requestReset = await request(base)
      .post('/auth/request-password-reset')
      .send({ username, deliveryMode: 'email' });
    expect(requestReset.status).toBe(201);

    const events = await request(base)
      .get('/auth/password-reset-email-events?limit=5')
      .set('Authorization', `Bearer ${register.body.accessToken}`);

    expect(events.status).toBe(200);
    expect(Array.isArray(events.body.events)).toBe(true);
    expect(events.body.events).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          type: 'delivery',
          status: 'success',
          transport: 'console',
        }),
      ])
    );
    expect(
      events.body.events.some(
        (event: any) =>
          event.type === 'delivery' &&
          typeof event.recipientHint === 'string' &&
          event.recipientHint.includes('@example.com')
      )
    ).toBe(true);
  });

  it('returns a password reset email snapshot for authenticated users', async () => {
    const suffix = Date.now();
    const username = `reset-snapshot-${suffix}@example.com`;

    const register = await request(base)
      .post('/auth/register')
      .send({ username, password: 'secret-old' });
    expect(register.status).toBe(201);

    const requestReset = await request(base)
      .post('/auth/request-password-reset')
      .send({ username, deliveryMode: 'email' });
    expect(requestReset.status).toBe(201);

    const snapshot = await request(base)
      .get('/auth/password-reset-email-snapshot?limit=5')
      .set('Authorization', `Bearer ${register.body.accessToken}`);

    expect(snapshot.status).toBe(200);
    expect(snapshot.body).toEqual(
      expect.objectContaining({
        generatedAt: expect.any(String),
        config: expect.any(Object),
        events: expect.any(Array),
        latest: expect.objectContaining({
          delivery: expect.any(Object),
        }),
        summary: expect.objectContaining({
          anomalyHint: expect.any(String),
          overallVerdict: expect.any(String),
          nextBestAction: expect.any(String),
          latestActivity: expect.any(String),
          trend: expect.any(String),
        }),
      })
    );
  });

  it('returns a password reset email handoff summary for authenticated users', async () => {
    const suffix = Date.now();
    const username = `reset-handoff-${suffix}@example.com`;

    const register = await request(base)
      .post('/auth/register')
      .send({ username, password: 'secret-old' });
    expect(register.status).toBe(201);

    const requestReset = await request(base)
      .post('/auth/request-password-reset')
      .send({ username, deliveryMode: 'email' });
    expect(requestReset.status).toBe(201);

    const handoff = await request(base)
      .get('/auth/password-reset-email-handoff?limit=5')
      .set('Authorization', `Bearer ${register.body.accessToken}`);

    expect(handoff.status).toBe(200);
    expect(handoff.body).toEqual(
      expect.objectContaining({
        generatedAt: expect.any(String),
        summaryText: expect.stringContaining('密码重置邮件链路交接摘要'),
        snapshot: expect.objectContaining({
          config: expect.any(Object),
          events: expect.any(Array),
          latest: expect.objectContaining({
            delivery: expect.any(Object),
          }),
          summary: expect.objectContaining({
            overallVerdict: expect.any(String),
            nextBestAction: expect.any(String),
          }),
        }),
      })
    );
  });

  it('runs password reset email smtp check for authenticated users', async () => {
    const suffix = Date.now();
    const username = `reset-check-${suffix}@example.com`;

    const register = await request(base)
      .post('/auth/register')
      .send({ username, password: 'secret-old' });
    expect(register.status).toBe(201);

    const smtpCheck = await request(base)
      .post('/auth/password-reset-email-check')
      .set('Authorization', `Bearer ${register.body.accessToken}`);

    expect(smtpCheck.status).toBe(201);
    expect(typeof smtpCheck.body.ok).toBe('boolean');
    if (smtpCheck.body.ok) {
      expect(smtpCheck.body.result).toEqual(
        expect.objectContaining({
          transport: 'smtp',
        })
      );
    } else {
      expect(typeof smtpCheck.body.error).toBe('string');
    }
  });

  it('rejects email delivery mode for non-email usernames', async () => {
    const suffix = Date.now();
    const username = `reset-email-invalid-${suffix}`;

    const register = await request(base)
      .post('/auth/register')
      .send({ username, password: 'secret-old' });
    expect(register.status).toBe(201);

    const requestReset = await request(base)
      .post('/auth/request-password-reset')
      .send({ username, deliveryMode: 'email' });
    expect(requestReset.status).toBe(400);
    expect(String(requestReset.body.message)).toContain(
      'Email delivery requires an email-style username'
    );
  });
});

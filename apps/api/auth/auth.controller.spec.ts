import { PasswordResetDeliveryService } from './password-reset-delivery.service';
import { PasswordResetEmailGateway } from './password-reset-email.gateway';
import { AuthController } from './auth.controller';

describe('AuthController', () => {
  it('register creates user and issues token', async () => {
    const prisma = {
      user: {
        create: jest.fn().mockResolvedValue({
          id: 'u1',
          username: 'alice',
          sessionVersion: 0,
        }),
      },
      tenant: {
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({
          id: 'tp1',
          code: 'personal-u1',
          name: 'alice 的个人工作区',
          kind: 'personal',
          personalOwnerUserId: 'u1',
        }),
        findUnique: jest.fn().mockResolvedValue({
          id: 'tp1',
          code: 'personal-u1',
          name: 'alice 的个人工作区',
          kind: 'personal',
          personalOwnerUserId: 'u1',
        }),
      },
      withTenant: jest.fn().mockImplementation(async (_tenantId: string, fn: any) =>
        fn({
          tenantMember: {
            upsert: jest.fn().mockResolvedValue({}),
          },
          questionBank: {
            findFirst: jest.fn().mockResolvedValue(null),
            create: jest.fn().mockResolvedValue({ id: 'bank-1' }),
          },
        }),
      ),
    } as any;
    const auth = {
      issueToken: jest.fn().mockResolvedValue({ accessToken: 't' }),
      hashPassword: jest.fn().mockResolvedValue('hashed-secret')
    } as any;
    const ctrl = new AuthController(
      prisma,
      auth,
      {} as PasswordResetDeliveryService,
      {} as PasswordResetEmailGateway
    );

    const res = await ctrl.register({ username: 'alice', password: 'secret' });

    expect(prisma.user.create).toHaveBeenCalledWith({
      data: { username: 'alice', passwordHash: 'hashed-secret' }
    });
    expect(prisma.tenant.create).toHaveBeenCalledWith({
      data: {
        code: 'personal-u1',
        name: 'alice 的个人工作区',
        kind: 'personal',
        personalOwnerUserId: 'u1',
      },
      select: {
        id: true,
        code: true,
        name: true,
        kind: true,
        personalOwnerUserId: true,
      },
    });
    expect(auth.issueToken).toHaveBeenCalledWith('u1', 0);
    expect(res).toEqual({
      accessToken: 't',
      userId: 'u1',
      username: 'alice',
      accessLevel: 'member'
    });
  });

  it('login verifies password and issues token', async () => {
    const prisma = {
      user: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'u2',
          username: 'bob',
          passwordHash: 'hashed',
          sessionVersion: 3
        })
      },
      tenant: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'tp2',
          code: 'personal-u2',
          name: 'bob 的个人工作区',
          kind: 'personal',
          personalOwnerUserId: 'u2',
        }),
        create: jest.fn(),
        findUnique: jest.fn().mockResolvedValue({
          id: 'tp2',
          code: 'personal-u2',
          name: 'bob 的个人工作区',
          kind: 'personal',
          personalOwnerUserId: 'u2',
        }),
      },
      withTenant: jest.fn().mockImplementation(async (_tenantId: string, fn: any) =>
        fn({
          tenantMember: {
            upsert: jest.fn().mockResolvedValue({}),
          },
          questionBank: {
            findFirst: jest.fn().mockResolvedValue({ id: 'bank-2' }),
            create: jest.fn(),
          },
        }),
      ),
    } as any;
    const auth = {
      issueToken: jest.fn().mockResolvedValue({ accessToken: 't2' }),
      verifyPassword: jest.fn().mockResolvedValue(true)
    } as any;
    const ctrl = new AuthController(
      prisma,
      auth,
      {} as PasswordResetDeliveryService,
      {} as PasswordResetEmailGateway
    );

    const res = await ctrl.login({ username: 'bob', password: 'secret' });

    expect(prisma.user.findUnique).toHaveBeenCalledWith({ where: { username: 'bob' } });
    expect(auth.verifyPassword).toHaveBeenCalledWith('secret', 'hashed');
    expect(prisma.tenant.create).not.toHaveBeenCalled();
    expect(auth.issueToken).toHaveBeenCalledWith('u2', 3);
    expect(res).toEqual({
      accessToken: 't2',
      userId: 'u2',
      username: 'bob',
      accessLevel: 'member'
    });
  });

  it('changePassword verifies current password and bumps session version', async () => {
    const prisma = {
      user: {
        findUnique: jest.fn().mockResolvedValue({ id: 'u3', passwordHash: 'hashed-old' }),
        update: jest.fn().mockResolvedValue({})
      }
    } as any;
    const auth = {
      verifyPassword: jest.fn().mockResolvedValue(true),
      hashPassword: jest.fn().mockResolvedValue('hashed-new')
    } as any;
    const ctrl = new AuthController(
      prisma,
      auth,
      {} as PasswordResetDeliveryService,
      {} as PasswordResetEmailGateway
    );

    const res = await ctrl.changePassword(
      { auth: { userId: 'u3' } } as any,
      { currentPassword: 'old-pass', newPassword: 'new-pass' }
    );

    expect(auth.verifyPassword).toHaveBeenCalledWith('old-pass', 'hashed-old');
    expect(auth.hashPassword).toHaveBeenCalledWith('new-pass');
    expect(prisma.user.update).toHaveBeenCalledWith({
      where: { id: 'u3' },
      data: {
        passwordHash: 'hashed-new',
        sessionVersion: { increment: 1 }
      }
    });
    expect(res).toEqual({ ok: true });
  });

  it('logout bumps session version', async () => {
    const prisma = {
      user: {
        update: jest.fn().mockResolvedValue({})
      }
    } as any;
    const auth = {} as any;
    const ctrl = new AuthController(
      prisma,
      auth,
      {} as PasswordResetDeliveryService,
      {} as PasswordResetEmailGateway
    );

    const res = await ctrl.logout({ auth: { userId: 'u4' } } as any);

    expect(prisma.user.update).toHaveBeenCalledWith({
      where: { id: 'u4' },
      data: {
        sessionVersion: { increment: 1 }
      }
    });
    expect(res).toEqual({ ok: true });
  });

  it('requestPasswordReset returns a preview token for an existing user', async () => {
    const prisma = {
      user: {
        findUnique: jest.fn().mockResolvedValue({ id: 'u5', username: 'alice' }),
      },
      passwordResetToken: {
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({ id: 'prt-1' }),
      },
    } as any;
    const auth = {
      generateResetToken: jest.fn().mockReturnValue('preview-token'),
      hashResetToken: jest.fn().mockReturnValue('hashed-reset-token'),
    } as any;
    const delivery = {
      deliverResetToken: jest.fn().mockResolvedValue({
        deliveryMode: 'preview',
        deliveryTransport: 'inline',
        deliveryTargetHint: '当前页面',
        resetTokenPreview: 'preview-token',
      }),
    } as unknown as PasswordResetDeliveryService;
    const ctrl = new AuthController(
      prisma,
      auth,
      delivery,
      {} as PasswordResetEmailGateway
    );

    const res = await ctrl.requestPasswordReset({ username: 'alice' });

    expect(prisma.passwordResetToken.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        userId: 'u5',
        tokenHash: 'hashed-reset-token',
        previewTail: expect.any(String),
      }),
    });
    expect(res).toEqual(
      expect.objectContaining({
        ok: true,
        requestId: 'prt-1',
        deliveryMode: 'preview',
        deliveryTransport: 'inline',
        deliveryTargetHint: '当前页面',
        resetTokenPreview: 'preview-token',
        previewHint: expect.stringContaining('...'),
        cooldownSeconds: 60,
      }),
    );
  });

  it('requestPasswordReset reuses cooldown window without minting a new token', async () => {
    const createdAt = new Date(Date.now() - 10_000);
    const prisma = {
      user: {
        findUnique: jest.fn().mockResolvedValue({ id: 'u5', username: 'alice' }),
      },
      passwordResetToken: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'prt-2',
          createdAt,
          deliveryMode: 'console',
          previewTail: 'abc123',
        }),
        create: jest.fn(),
      },
    } as any;
    const auth = {} as any;
    const delivery = {
      describeDelivery: jest.fn().mockReturnValue({
        deliveryMode: 'console',
        deliveryTransport: 'console',
        deliveryTargetHint: '服务器日志',
      }),
    } as unknown as PasswordResetDeliveryService;
    const ctrl = new AuthController(
      prisma,
      auth,
      delivery,
      {} as PasswordResetEmailGateway
    );

    const res = await ctrl.requestPasswordReset({ username: 'alice' });

    expect(prisma.passwordResetToken.create).not.toHaveBeenCalled();
    expect(res).toEqual(
      expect.objectContaining({
        ok: true,
        requestId: 'prt-2',
        deliveryMode: 'console',
        deliveryTransport: 'console',
        deliveryTargetHint: '服务器日志',
        previewHint: '...abc123',
      }),
    );
    expect(typeof res.cooldownSeconds).toBe('number');
  });

  it('requestPasswordReset rejects email delivery for non-email usernames', async () => {
    const prisma = {
      user: {
        findUnique: jest.fn().mockResolvedValue({ id: 'u5', username: 'alice' }),
      },
    } as any;
    const auth = {} as any;
    const ctrl = new AuthController(
      prisma,
      auth,
      {} as PasswordResetDeliveryService,
      {} as PasswordResetEmailGateway
    );

    await expect(
      ctrl.requestPasswordReset({ username: 'alice', deliveryMode: 'email' })
    ).rejects.toThrow('Email delivery requires an email-style username');
  });

  it('passwordResetEmailSnapshot returns config, latest events, and summary', async () => {
    const gateway = {
      listRecentEvents: jest.fn().mockReturnValue([
        {
          timestamp: '2026-03-16T00:00:00.000Z',
          type: 'delivery',
          status: 'success',
          transport: 'smtp',
        },
        {
          timestamp: '2026-03-15T23:59:00.000Z',
          type: 'smtp-self-check',
          status: 'success',
          transport: 'smtp',
        },
      ]),
      configSnapshot: jest.fn().mockReturnValue({
        transport: 'smtp',
        from: 'no-reply@shiti.local',
      }),
    } as unknown as PasswordResetEmailGateway;
    const ctrl = new AuthController(
      {} as any,
      {} as any,
      {} as PasswordResetDeliveryService,
      gateway
    );

    const res = await ctrl.passwordResetEmailSnapshot('5');

    expect(gateway.listRecentEvents).toHaveBeenCalledWith(5);
    expect(res).toEqual(
      expect.objectContaining({
        config: expect.objectContaining({ transport: 'smtp' }),
        events: expect.any(Array),
        latest: expect.objectContaining({
          check: expect.objectContaining({ type: 'smtp-self-check' }),
          delivery: expect.objectContaining({ type: 'delivery' }),
          failure: null,
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

  it('passwordResetEmailHandoff returns a text summary with embedded snapshot', async () => {
    const gateway = {
      listRecentEvents: jest.fn().mockReturnValue([
        {
          timestamp: '2026-03-16T00:00:00.000Z',
          type: 'delivery',
          status: 'success',
          transport: 'smtp',
        },
        {
          timestamp: '2026-03-15T23:59:00.000Z',
          type: 'smtp-self-check',
          status: 'success',
          transport: 'smtp',
        },
      ]),
      configSnapshot: jest.fn().mockReturnValue({
        transport: 'smtp',
        from: 'no-reply@shiti.local',
      }),
    } as unknown as PasswordResetEmailGateway;
    const ctrl = new AuthController(
      {} as any,
      {} as any,
      {} as PasswordResetDeliveryService,
      gateway
    );

    const res = await ctrl.passwordResetEmailHandoff('5');

    expect(gateway.listRecentEvents).toHaveBeenCalledWith(5);
    expect(res).toEqual(
      expect.objectContaining({
        generatedAt: expect.any(String),
        summaryText: expect.stringContaining('密码重置邮件链路交接摘要'),
        snapshot: expect.objectContaining({
          config: expect.objectContaining({ transport: 'smtp' }),
          latest: expect.objectContaining({
            delivery: expect.objectContaining({ type: 'delivery' }),
          }),
          summary: expect.objectContaining({
            overallVerdict: expect.any(String),
          }),
        }),
      })
    );
  });

  it('resetPassword updates hash and consumes reset tokens', async () => {
    const prisma = {
      user: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'u6',
          username: 'alice',
          passwordHash: 'hashed-old',
        }),
      },
      passwordResetToken: {
        findFirst: jest.fn().mockResolvedValue({ id: 'prt-1' }),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      $transaction: jest.fn().mockImplementation((queries: unknown[]) => Promise.all(queries)),
    } as any;
    prisma.user.update = jest.fn().mockResolvedValue({});
    const auth = {
      hashResetToken: jest.fn().mockReturnValue('hashed-token'),
      verifyPassword: jest.fn().mockResolvedValue(false),
      hashPassword: jest.fn().mockResolvedValue('hashed-new'),
    } as any;
    const ctrl = new AuthController(
      prisma,
      auth,
      {} as PasswordResetDeliveryService,
      {} as PasswordResetEmailGateway
    );

    const res = await ctrl.resetPassword({
      username: 'alice',
      resetToken: 'token',
      newPassword: 'new-password',
    });

    expect(prisma.passwordResetToken.findFirst).toHaveBeenCalledWith({
      where: expect.objectContaining({
        userId: 'u6',
        tokenHash: 'hashed-token',
        consumedAt: null,
      }),
    });
    expect(prisma.user.update).toHaveBeenCalledWith({
      where: { id: 'u6' },
      data: {
        passwordHash: 'hashed-new',
        sessionVersion: { increment: 1 },
      },
    });
    expect(res).toEqual({ ok: true });
  });

  it('lists recent password reset email events for authenticated users', async () => {
    const prisma = {} as any;
    const auth = {} as any;
    const emailGateway = {
      listRecentEvents: jest.fn().mockReturnValue([
        {
          timestamp: '2026-03-16T08:00:00.000Z',
          type: 'delivery',
          status: 'success',
          transport: 'smtp',
        },
      ]),
      configSnapshot: jest.fn().mockReturnValue({
        transport: 'smtp',
        from: 'no-reply@shiti.local',
      }),
    } as unknown as PasswordResetEmailGateway;
    const ctrl = new AuthController(
      prisma,
      auth,
      {} as PasswordResetDeliveryService,
      emailGateway
    );

    const res = await ctrl.passwordResetEmailEvents('5');

    expect(emailGateway.listRecentEvents).toHaveBeenCalledWith(5);
    expect(emailGateway.configSnapshot).toHaveBeenCalledTimes(1);
    expect(res).toEqual({
      config: {
        transport: 'smtp',
        from: 'no-reply@shiti.local',
      },
      events: [
        {
          timestamp: '2026-03-16T08:00:00.000Z',
          type: 'delivery',
          status: 'success',
          transport: 'smtp',
        },
      ],
    });
  });

  it('runs password reset email smtp check for authenticated users', async () => {
    const prisma = {} as any;
    const auth = {} as any;
    const emailGateway = {
      checkSmtpConnection: jest.fn().mockResolvedValue({
        transport: 'smtp',
        host: 'smtp.example.com',
        port: 587,
        secure: false,
        startTlsUpgraded: true,
        authenticated: true,
        capabilities: ['STARTTLS', 'AUTH LOGIN'],
      }),
    } as unknown as PasswordResetEmailGateway;
    const ctrl = new AuthController(
      prisma,
      auth,
      {} as PasswordResetDeliveryService,
      emailGateway
    );

    const res = await ctrl.passwordResetEmailCheck();

    expect(emailGateway.checkSmtpConnection).toHaveBeenCalledTimes(1);
    expect(res).toEqual({
      ok: true,
      result: {
        transport: 'smtp',
        host: 'smtp.example.com',
        port: 587,
        secure: false,
        startTlsUpgraded: true,
        authenticated: true,
        capabilities: ['STARTTLS', 'AUTH LOGIN'],
      },
    });
  });

  it('returns structured smtp check failure without throwing', async () => {
    const prisma = {} as any;
    const auth = {} as any;
    const emailGateway = {
      checkSmtpConnection: jest.fn().mockRejectedValue(new Error('smtp not configured')),
    } as unknown as PasswordResetEmailGateway;
    const ctrl = new AuthController(
      prisma,
      auth,
      {} as PasswordResetDeliveryService,
      emailGateway
    );

    const res = await ctrl.passwordResetEmailCheck();

    expect(res).toEqual({
      ok: false,
      error: 'smtp not configured',
    });
  });
});

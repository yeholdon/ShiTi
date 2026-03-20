import { existsSync, readFileSync, rmSync } from 'fs';
import { resolve } from 'path';
import { PasswordResetEmailGateway } from './password-reset-email.gateway';

describe('PasswordResetEmailGateway', () => {
  afterEach(() => {
    delete process.env.AUTH_RESET_EMAIL_TRANSPORT;
    delete process.env.AUTH_RESET_EMAIL_OUTBOX_FILE;
    delete process.env.AUTH_RESET_EMAIL_FROM;
    delete process.env.AUTH_RESET_EMAIL_SMTP_HOST;
    delete process.env.AUTH_RESET_EMAIL_SMTP_PORT;
    delete process.env.AUTH_RESET_EMAIL_SMTP_SECURE;
    delete process.env.AUTH_RESET_EMAIL_SMTP_USERNAME;
    delete process.env.AUTH_RESET_EMAIL_SMTP_PASSWORD;
    delete process.env.AUTH_RESET_EMAIL_SMTP_HELO_NAME;
    delete process.env.AUTH_RESET_EMAIL_SMTP_REQUIRE_STARTTLS;
    delete process.env.AUTH_RESET_EMAIL_EVENTS_FILE;
    const outboxFile = resolve(
      '/Users/honcy/Project/ShiTi/tmp/test-auth-reset-email-outbox.jsonl'
    );
    const eventsFile = resolve(
      '/Users/honcy/Project/ShiTi/tmp/test-auth-reset-email-events.jsonl'
    );
    rmSync(outboxFile, { force: true });
    rmSync(eventsFile, { force: true });
  });

  it('builds a complete reset email message', () => {
    const gateway = new PasswordResetEmailGateway();

    const message = gateway.buildMessage({
      to: 'teacher@example.com',
      token: 'reset-token',
      expiresAt: new Date('2026-03-16T06:00:00.000Z'),
    });

    expect(message.to).toBe('teacher@example.com');
    expect(message.from).toBe('no-reply@shiti.local');
    expect(message.subject).toContain('密码重置码');
    expect(message.text).toContain('reset-token');
    expect(message.html).toContain('<strong>reset-token</strong>');
  });

  it('reports the active transport', () => {
    const gateway = new PasswordResetEmailGateway();
    expect(gateway.currentTransport()).toBe('console');
  });

  it('writes email payloads to a file outbox when file transport is enabled', async () => {
    const outboxFile = resolve(
      '/Users/honcy/Project/ShiTi/tmp/test-auth-reset-email-outbox.jsonl'
    );
    const eventsFile = resolve(
      '/Users/honcy/Project/ShiTi/tmp/test-auth-reset-email-events.jsonl'
    );
    process.env.AUTH_RESET_EMAIL_TRANSPORT = 'file';
    process.env.AUTH_RESET_EMAIL_OUTBOX_FILE = outboxFile;
    process.env.AUTH_RESET_EMAIL_EVENTS_FILE = eventsFile;

    const gateway = new PasswordResetEmailGateway();
    const sent = await gateway.send({
      to: 'teacher@example.com',
      from: 'no-reply@shiti.local',
      subject: 'ShiTi 密码重置码',
      text: 'plain text body',
      html: '<p>plain text body</p>',
    });

    expect(sent.transport).toBe('file');
    expect(existsSync(outboxFile)).toBe(true);
    const content = readFileSync(outboxFile, 'utf8');
    expect(content).toContain('"transport":"file"');
    expect(content).toContain('"to":"teacher@example.com"');
    expect(content).toContain('"subject":"ShiTi 密码重置码"');
    const events = readFileSync(eventsFile, 'utf8');
    expect(events).toContain('"type":"delivery"');
    expect(events).toContain('"status":"success"');
    expect(events).toContain('"recipientHint":"t***r@example.com"');
  });

  it('routes smtp transport through the smtp sender path', async () => {
    process.env.AUTH_RESET_EMAIL_TRANSPORT = 'smtp';
    process.env.AUTH_RESET_EMAIL_SMTP_HOST = 'smtp.example.com';
    process.env.AUTH_RESET_EMAIL_SMTP_PORT = '465';
    process.env.AUTH_RESET_EMAIL_SMTP_SECURE = 'true';

    const gateway = new PasswordResetEmailGateway();
    const smtpSpy = jest
      .spyOn(gateway, 'sendWithSmtp')
      .mockResolvedValue({ transport: 'smtp' });

    const sent = await gateway.send({
      to: 'teacher@example.com',
      from: 'no-reply@shiti.local',
      subject: 'ShiTi 密码重置码',
      text: 'plain text body',
      html: '<p>plain text body</p>',
    });

    expect(sent.transport).toBe('smtp');
    expect(smtpSpy).toHaveBeenCalled();
  });

  it('reports smtp connectivity details through the self-check path', async () => {
    const eventsFile = resolve(
      '/Users/honcy/Project/ShiTi/tmp/test-auth-reset-email-events.jsonl'
    );
    process.env.AUTH_RESET_EMAIL_SMTP_HOST = 'smtp.example.com';
    process.env.AUTH_RESET_EMAIL_SMTP_PORT = '587';
    process.env.AUTH_RESET_EMAIL_SMTP_SECURE = 'false';
    process.env.AUTH_RESET_EMAIL_EVENTS_FILE = eventsFile;

    const gateway = new PasswordResetEmailGateway();
    const socket = { destroy: jest.fn() } as any;
    const sessionSpy = jest.spyOn(gateway as any, 'openAuthenticatedSmtpSession');
    sessionSpy.mockResolvedValue({
      socket,
      capabilities: ['250-localhost', '250 STARTTLS'],
      startTlsUpgraded: true,
      authenticated: false,
    });
    const commandSpy = jest.spyOn(gateway as any, 'sendCommand');
    commandSpy.mockResolvedValue({
      code: 221,
      lines: ['221 Bye'],
    });

    const result = await gateway.checkSmtpConnection();

    expect(result).toEqual({
      transport: 'smtp',
      host: 'smtp.example.com',
      port: 587,
      secure: false,
      startTlsUpgraded: true,
      authenticated: false,
      capabilities: ['250-localhost', '250 STARTTLS'],
    });
    expect(commandSpy).toHaveBeenCalledWith(socket, 'QUIT', [221]);
    expect(socket.destroy).toHaveBeenCalled();
    const events = readFileSync(eventsFile, 'utf8');
    expect(events).toContain('"type":"smtp-self-check"');
    expect(events).toContain('"status":"success"');
    expect(events).toContain('"host":"smtp.example.com"');
  });
});

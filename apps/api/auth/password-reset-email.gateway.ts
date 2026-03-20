import { appendFileSync, mkdirSync, readFileSync } from 'fs';
import { Injectable } from '@nestjs/common';
import { Socket, connect as connectTcp } from 'net';
import { dirname, resolve } from 'path';
import { TLSSocket, connect as connectTls } from 'tls';

export interface PasswordResetEmailMessage {
  to: string;
  from: string;
  subject: string;
  text: string;
  html: string;
}

export interface PasswordResetEmailSendResult {
  transport: string;
}

export interface PasswordResetEmailHealthResult {
  transport: 'smtp';
  host: string;
  port: number;
  secure: boolean;
  startTlsUpgraded: boolean;
  authenticated: boolean;
  capabilities: string[];
}

export interface PasswordResetEmailConfigSnapshot {
  transport: string;
  from: string;
  eventsFile: string;
  outboxFile?: string;
  smtpHost?: string;
  smtpPort?: number;
  smtpSecure?: boolean;
  smtpHeloName?: string;
  smtpRequireStartTls?: boolean;
  smtpUsernameConfigured?: boolean;
}

interface PasswordResetSmtpConfig {
  host: string;
  port: number;
  secure: boolean;
  username?: string;
  password?: string;
  heloName: string;
  requireStartTls: boolean;
}

export interface PasswordResetEmailEvent {
  timestamp: string;
  type: 'delivery' | 'smtp-self-check';
  status: 'success' | 'error';
  transport: string;
  recipientHint?: string;
  subject?: string;
  host?: string;
  port?: number;
  secure?: boolean;
  startTlsUpgraded?: boolean;
  authenticated?: boolean;
  capabilities?: string[];
  error?: string;
}

@Injectable()
export class PasswordResetEmailGateway {
  buildMessage(params: {
    to: string;
    token: string;
    expiresAt: Date;
  }): PasswordResetEmailMessage {
    const from = (process.env.AUTH_RESET_EMAIL_FROM || 'no-reply@shiti.local').trim();
    const expiresAtLabel = params.expiresAt.toISOString();
    const subject = 'ShiTi 密码重置码';
    const text =
      `你的密码重置码是：${params.token}\n` +
      `有效期至：${expiresAtLabel}\n` +
      '如果这不是你本人发起，请忽略此邮件。';
    const html =
      `<p>你的密码重置码是：<strong>${params.token}</strong></p>` +
      `<p>有效期至：${expiresAtLabel}</p>` +
      '<p>如果这不是你本人发起，请忽略此邮件。</p>';
    return {
      to: params.to,
      from,
      subject,
      text,
      html,
    };
  }

  currentTransport(): string {
    return (process.env.AUTH_RESET_EMAIL_TRANSPORT || 'console').trim();
  }

  async send(
    message: PasswordResetEmailMessage
  ): Promise<PasswordResetEmailSendResult> {
    const transport = this.currentTransport();
    try {
      if (transport === 'file') {
        const outboxFile = resolve(
          process.env.AUTH_RESET_EMAIL_OUTBOX_FILE || 'tmp/auth-reset-email-outbox.jsonl'
        );
        mkdirSync(dirname(outboxFile), { recursive: true });
        appendFileSync(
          outboxFile,
          `${JSON.stringify({
            sentAt: new Date().toISOString(),
            transport: 'file',
            ...message,
          })}\n`,
          'utf8'
        );
        console.info(
          `[auth.reset-password.email] transport=file path=${outboxFile} to=${message.to} subject=${message.subject}`
        );
        const result = { transport: 'file' };
        this.appendEvent({
          timestamp: new Date().toISOString(),
          type: 'delivery',
          status: 'success',
          transport: result.transport,
          recipientHint: this.maskRecipient(message.to),
          subject: message.subject,
        });
        return result;
      }
      if (transport === 'smtp') {
        const result = await this.sendWithSmtp(message);
        this.appendEvent({
          timestamp: new Date().toISOString(),
          type: 'delivery',
          status: 'success',
          transport: result.transport,
          recipientHint: this.maskRecipient(message.to),
          subject: message.subject,
        });
        return result;
      }

      console.info(
        `[auth.reset-password.email] transport=console from=${message.from} to=${message.to} subject=${message.subject}`
      );
      console.info(message.text);
      const result = { transport: 'console' };
      this.appendEvent({
        timestamp: new Date().toISOString(),
        type: 'delivery',
        status: 'success',
        transport: result.transport,
        recipientHint: this.maskRecipient(message.to),
        subject: message.subject,
      });
      return result;
    } catch (error) {
      this.appendEvent({
        timestamp: new Date().toISOString(),
        type: 'delivery',
        status: 'error',
        transport,
        recipientHint: this.maskRecipient(message.to),
        subject: message.subject,
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  }

  smtpConfig(): PasswordResetSmtpConfig {
    const host = (process.env.AUTH_RESET_EMAIL_SMTP_HOST || '').trim();
    if (!host) {
      throw new Error('AUTH_RESET_EMAIL_SMTP_HOST is required for smtp transport');
    }
    const port = Number(process.env.AUTH_RESET_EMAIL_SMTP_PORT || 587);
    if (!Number.isFinite(port) || port <= 0) {
      throw new Error('AUTH_RESET_EMAIL_SMTP_PORT must be a positive number');
    }

    return {
      host,
      port,
      secure:
        (process.env.AUTH_RESET_EMAIL_SMTP_SECURE || '').trim().toLowerCase() ===
        'true',
      username: (process.env.AUTH_RESET_EMAIL_SMTP_USERNAME || '').trim() || undefined,
      password: (process.env.AUTH_RESET_EMAIL_SMTP_PASSWORD || '').trim() || undefined,
      heloName:
        (process.env.AUTH_RESET_EMAIL_SMTP_HELO_NAME || 'localhost').trim(),
      requireStartTls:
        (process.env.AUTH_RESET_EMAIL_SMTP_REQUIRE_STARTTLS || 'true')
          .trim()
          .toLowerCase() !== 'false',
    };
  }

  async sendWithSmtp(
    message: PasswordResetEmailMessage
  ): Promise<PasswordResetEmailSendResult> {
    const config = this.smtpConfig();
    const session = await this.openAuthenticatedSmtpSession(config);
    try {
      await this.sendCommand(session.socket, `MAIL FROM:<${message.from}>`, [250]);
      await this.sendCommand(session.socket, `RCPT TO:<${message.to}>`, [250, 251]);
      await this.sendCommand(session.socket, 'DATA', [354]);
      await this.writeLine(session.socket, this.smtpMessageBody(message));
      await this.writeLine(session.socket, '.');
      await this.readResponse(session.socket, [250]);
      await this.sendCommand(session.socket, 'QUIT', [221]);
      console.info(
        `[auth.reset-password.email] transport=smtp host=${config.host}:${config.port} to=${message.to} subject=${message.subject}`
      );
      return { transport: 'smtp' };
    } finally {
      session.socket.destroy();
    }
  }

  async checkSmtpConnection(): Promise<PasswordResetEmailHealthResult> {
    const config = this.smtpConfig();
    try {
      const session = await this.openAuthenticatedSmtpSession(config);
      try {
        await this.sendCommand(session.socket, 'QUIT', [221]);
        const result = {
          transport: 'smtp' as const,
          host: config.host,
          port: config.port,
          secure: config.secure,
          startTlsUpgraded: session.startTlsUpgraded,
          authenticated: session.authenticated,
          capabilities: session.capabilities,
        };
        this.appendEvent({
          timestamp: new Date().toISOString(),
          type: 'smtp-self-check',
          status: 'success',
          transport: 'smtp',
          host: config.host,
          port: config.port,
          secure: config.secure,
          startTlsUpgraded: session.startTlsUpgraded,
          authenticated: session.authenticated,
          capabilities: session.capabilities,
        });
        return result;
      } finally {
        session.socket.destroy();
      }
    } catch (error) {
      this.appendEvent({
        timestamp: new Date().toISOString(),
        type: 'smtp-self-check',
        status: 'error',
        transport: 'smtp',
        host: config.host,
        port: config.port,
        secure: config.secure,
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  }

  eventsFile(): string {
    return resolve(
      process.env.AUTH_RESET_EMAIL_EVENTS_FILE || 'tmp/auth-reset-email-events.jsonl'
    );
  }

  configSnapshot(): PasswordResetEmailConfigSnapshot {
    const transport = this.currentTransport();
    const snapshot: PasswordResetEmailConfigSnapshot = {
      transport,
      from: (process.env.AUTH_RESET_EMAIL_FROM || 'no-reply@shiti.local').trim(),
      eventsFile: this.eventsFile(),
    };

    if (transport === 'file') {
      snapshot.outboxFile = resolve(
        process.env.AUTH_RESET_EMAIL_OUTBOX_FILE || 'tmp/auth-reset-email-outbox.jsonl'
      );
    }

    if (transport === 'smtp') {
      try {
        const config = this.smtpConfig();
        snapshot.smtpHost = config.host;
        snapshot.smtpPort = config.port;
        snapshot.smtpSecure = config.secure;
        snapshot.smtpHeloName = config.heloName;
        snapshot.smtpRequireStartTls = config.requireStartTls;
        snapshot.smtpUsernameConfigured = Boolean(config.username);
      } catch {
        snapshot.smtpUsernameConfigured = Boolean(
          (process.env.AUTH_RESET_EMAIL_SMTP_USERNAME || '').trim()
        );
      }
    }

    return snapshot;
  }

  listRecentEvents(limit: number): PasswordResetEmailEvent[] {
    const eventsFile = this.eventsFile();
    try {
      const content = readFileSync(eventsFile, 'utf8');
      return content
        .split('\n')
        .map((line) => line.trim())
        .filter(Boolean)
        .slice(-Math.max(1, limit))
        .reverse()
        .flatMap((line) => {
          try {
            return [JSON.parse(line) as PasswordResetEmailEvent];
          } catch {
            return [];
          }
        });
    } catch {
      return [];
    }
  }

  private appendEvent(event: PasswordResetEmailEvent): void {
    const eventsFile = this.eventsFile();
    mkdirSync(dirname(eventsFile), { recursive: true });
    appendFileSync(eventsFile, `${JSON.stringify(event)}\n`, 'utf8');
  }

  private maskRecipient(value: string): string {
    const parts = value.split('@');
    if (parts.length !== 2) {
      return value;
    }
    const local = parts[0];
    const domain = parts[1];
    if (local.length <= 2) {
      return `${local[0] ?? '*'}*@${domain}`;
    }
    return `${local[0]}***${local[local.length - 1]}@${domain}`;
  }

  private async openAuthenticatedSmtpSession(config: PasswordResetSmtpConfig): Promise<{
    socket: Socket | TLSSocket;
    capabilities: string[];
    startTlsUpgraded: boolean;
    authenticated: boolean;
  }> {
    let socket: Socket | TLSSocket = await this.openSmtpSocket(config);
    await this.readResponse(socket, [220]);
    let ehlo = await this.sendCommand(socket, `EHLO ${config.heloName}`, [250]);
    let startTlsUpgraded = false;

    if (!config.secure && config.requireStartTls) {
      const supportsStartTls = ehlo.lines.some((line) =>
        line.toUpperCase().includes('STARTTLS')
      );
      if (supportsStartTls) {
        await this.sendCommand(socket, 'STARTTLS', [220]);
        socket = await this.upgradeToTls(socket, config);
        ehlo = await this.sendCommand(socket, `EHLO ${config.heloName}`, [250]);
        startTlsUpgraded = true;
      }
    }

    let authenticated = false;
    if (config.username && config.password) {
      await this.sendCommand(socket, 'AUTH LOGIN', [334]);
      await this.sendCommand(
        socket,
        Buffer.from(config.username, 'utf8').toString('base64'),
        [334]
      );
      await this.sendCommand(
        socket,
        Buffer.from(config.password, 'utf8').toString('base64'),
        [235]
      );
      authenticated = true;
    }

    return {
      socket,
      capabilities: ehlo.lines,
      startTlsUpgraded,
      authenticated,
    };
  }

  private openSmtpSocket(config: PasswordResetSmtpConfig): Promise<Socket | TLSSocket> {
    return new Promise((resolvePromise, reject) => {
      const onError = (error: Error) => reject(error);
      if (config.secure) {
        const socket = connectTls({
          host: config.host,
          port: config.port,
          servername: config.host,
        });
        socket.once('secureConnect', () => resolvePromise(socket));
        socket.once('error', onError);
        return;
      }

      const socket = connectTcp({
        host: config.host,
        port: config.port,
      });
      socket.once('connect', () => resolvePromise(socket));
      socket.once('error', onError);
    });
  }

  private upgradeToTls(
    socket: Socket | TLSSocket,
    config: PasswordResetSmtpConfig
  ): Promise<TLSSocket> {
    return new Promise((resolvePromise, reject) => {
      const secureSocket = connectTls({
        socket,
        servername: config.host,
      });
      secureSocket.once('secureConnect', () => resolvePromise(secureSocket));
      secureSocket.once('error', reject);
    });
  }

  private sendCommand(
    socket: Socket | TLSSocket,
    command: string,
    expectedCodes: number[]
  ): Promise<{ code: number; lines: string[] }> {
    return new Promise((resolvePromise, reject) => {
      this.writeLine(socket, command)
        .then(() => this.readResponse(socket, expectedCodes))
        .then(resolvePromise)
        .catch(reject);
    });
  }

  private writeLine(socket: Socket | TLSSocket, line: string): Promise<void> {
    return new Promise((resolvePromise, reject) => {
      socket.write(`${line}\r\n`, 'utf8', (error) => {
        if (error) {
          reject(error);
          return;
        }
        resolvePromise();
      });
    });
  }

  private readResponse(
    socket: Socket | TLSSocket,
    expectedCodes: number[]
  ): Promise<{ code: number; lines: string[] }> {
    return new Promise((resolvePromise, reject) => {
      let buffer = '';
      const lines: string[] = [];

      const cleanup = () => {
        socket.off('data', onData);
        socket.off('error', onError);
        socket.off('close', onClose);
      };

      const finish = (line: string) => {
        const code = Number(line.slice(0, 3));
        cleanup();
        if (!expectedCodes.includes(code)) {
          reject(
            new Error(
              `Unexpected SMTP response ${code}: ${lines.join(' | ')}`
            )
          );
          return;
        }
        resolvePromise({
          code,
          lines: [...lines],
        });
      };

      const onData = (chunk: Buffer | string) => {
        buffer += chunk.toString();
        while (buffer.includes('\n')) {
          const newlineIndex = buffer.indexOf('\n');
          const rawLine = buffer.slice(0, newlineIndex).replace(/\r$/, '');
          buffer = buffer.slice(newlineIndex + 1);
          if (!/^\d{3}[- ]/.test(rawLine)) {
            continue;
          }
          lines.push(rawLine);
          if (rawLine[3] === ' ') {
            finish(rawLine);
            return;
          }
        }
      };

      const onError = (error: Error) => {
        cleanup();
        reject(error);
      };

      const onClose = () => {
        cleanup();
        reject(new Error('SMTP connection closed unexpectedly'));
      };

      socket.on('data', onData);
      socket.once('error', onError);
      socket.once('close', onClose);
    });
  }

  private smtpMessageBody(message: PasswordResetEmailMessage): string {
    const boundary = 'shiti-password-reset-boundary';
    return [
      `From: ${message.from}`,
      `To: ${message.to}`,
      `Subject: ${message.subject}`,
      'MIME-Version: 1.0',
      `Content-Type: multipart/alternative; boundary="${boundary}"`,
      '',
      `--${boundary}`,
      'Content-Type: text/plain; charset=utf-8',
      '',
      message.text,
      `--${boundary}`,
      'Content-Type: text/html; charset=utf-8',
      '',
      message.html,
      `--${boundary}--`,
      '',
    ].join('\r\n');
  }
}

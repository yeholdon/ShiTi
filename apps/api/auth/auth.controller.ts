import {
  Body,
  ConflictException,
  Controller,
  BadRequestException,
  Get,
  NotFoundException,
  Post,
  Query,
  Req,
  UnauthorizedException,
  UseGuards
} from '@nestjs/common';
import { RateLimit } from '../../../src/common/rate-limit/rate-limit.decorator';
import { RateLimitGuard } from '../../../src/common/rate-limit/rate-limit.guard';
import { PrismaService } from '../../../src/prisma/prisma.service';
import { requireUserId } from '../../../src/tenant/tenant-guards';
import { ensurePersonalTenant } from '../../../src/domain/tenants/personal-tenant';
import { AuthService } from './auth.service';
import { ChangePasswordDto } from './dto/change-password.dto';
import { RequestPasswordResetDto } from './dto/request-password-reset.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import { UsernamePasswordDto } from './dto/username-password.dto';
import { JwtAuthGuard } from './jwt-auth.guard';
import { PasswordResetDeliveryService } from './password-reset-delivery.service';
import { PasswordResetEmailGateway } from './password-reset-email.gateway';

function summarizePasswordResetEmailTrend(events: Array<Record<string, any>>) {
  const recent = events.slice(0, 5);
  if (recent.length === 0) {
    return 'No recent password-reset email events yet.';
  }

  const checks = recent.filter((event) => event.type === 'smtp-self-check');
  const deliveries = recent.filter((event) => event.type === 'delivery');
  const checkSuccess = checks.filter((event) => event.status === 'success').length;
  const deliverySuccess = deliveries.filter((event) => event.status === 'success').length;
  const latest = recent[0];
  const latestLabel =
    latest.type === 'smtp-self-check' ? 'smtp-self-check' : 'delivery';
  return `Recent 5 events: checks ${checkSuccess}/${checks.length}, deliveries ${deliverySuccess}/${deliveries.length}, latest ${latestLabel}=${latest.status}.`;
}

function derivePasswordResetEmailSnapshotSummary(
  config: Record<string, any> | null,
  events: Array<Record<string, any>>
) {
  const latestCheck = events.find((event) => event.type === 'smtp-self-check') || null;
  const latestDelivery = events.find((event) => event.type === 'delivery') || null;
  const latestFailure = events.find((event) => event.status === 'error') || null;
  const latestEvent = events[0] || null;

  const anomalyHint = latestFailure
    ? latestFailure.type === 'smtp-self-check'
      ? 'Latest anomaly: SMTP self-check failed.'
      : 'Latest anomaly: reset-email delivery failed.'
    : latestCheck
      ? latestDelivery
        ? 'Mail channel has both self-check and delivery history.'
        : 'SMTP self-check exists, but delivery history is still missing.'
      : 'No SMTP self-check has been recorded yet.';

  const overallVerdict =
    config?.transport === 'console' || config?.transport === 'file'
      ? `Mail channel is still on rehearsal transport (${config.transport}).`
      : latestFailure?.type === 'smtp-self-check'
        ? 'Mail channel is currently blocked at the SMTP connectivity layer.'
        : latestFailure?.type === 'delivery'
          ? 'Mail channel reaches delivery but the latest reset email still failed.'
          : latestCheck?.status === 'success' && latestDelivery?.status === 'success'
            ? 'Mail channel looks healthy based on the latest self-check and delivery.'
            : latestCheck?.status === 'success'
              ? 'SMTP connectivity is healthy, but a successful reset-email delivery is still missing.'
              : 'Mail channel still needs a fresh self-check or delivery signal.';

  const nextBestAction =
    config?.transport === 'console' || config?.transport === 'file'
      ? 'Switch to real SMTP before running more smoke tests.'
      : latestFailure?.type === 'smtp-self-check'
        ? 'Fix SMTP connectivity or auth, then run another self-check.'
        : latestFailure?.type === 'delivery'
          ? 'Review the latest failed delivery before rerunning a smoke test.'
          : !latestCheck
            ? 'Run the first SMTP self-check.'
            : !latestDelivery
              ? 'Run a forgot-password smoke test to produce a real delivery event.'
              : 'Verify recipient hint and transport before rerunning.';

  return {
    anomalyHint,
    overallVerdict,
    nextBestAction,
    latestActivity: latestEvent
      ? `Latest event: ${latestEvent.type} ${latestEvent.status} at ${latestEvent.timestamp}.`
      : 'No latest event yet.',
    trend: summarizePasswordResetEmailTrend(events),
  };
}

function buildPasswordResetEmailSnapshotPayload(
  config: Record<string, any> | null,
  events: Array<Record<string, any>>
) {
  const latestCheck = events.find((event) => event.type === 'smtp-self-check') || null;
  const latestDelivery = events.find((event) => event.type === 'delivery') || null;
  const latestFailure = events.find((event) => event.status === 'error') || null;

  return {
    generatedAt: new Date().toISOString(),
    config,
    events,
    latest: {
      check: latestCheck,
      delivery: latestDelivery,
      failure: latestFailure,
    },
    summary: derivePasswordResetEmailSnapshotSummary(config, events),
  };
}

function buildPasswordResetEmailHandoffSummary(snapshot: Record<string, any>) {
  const latest = snapshot.latest || {};
  const summary = snapshot.summary || {};
  const lines = [
    '密码重置邮件链路交接摘要',
    `生成时间：${snapshot.generatedAt || '-'}`,
    `当前 transport：${snapshot.config?.transport || 'unknown'}`,
    `当前链路结论：${summary.overallVerdict || '-'}`,
    `当前最该做的一步：${summary.nextBestAction || '-'}`,
    `异常提示：${summary.anomalyHint || '-'}`,
    `最近活动：${summary.latestActivity || '-'}`,
    `最近趋势：${summary.trend || '-'}`,
    `最近自检：${
      latest.check
        ? `${latest.check.status} @ ${latest.check.timestamp}`
        : '暂无'
    }`,
    `最近投递：${
      latest.delivery
        ? `${latest.delivery.status} @ ${latest.delivery.timestamp}`
        : '暂无'
    }`,
    `最近失败：${
      latest.failure
        ? `${latest.failure.type} ${latest.failure.error || latest.failure.status}`
        : '暂无'
    }`,
  ];
  return `${lines.join('\n')}\n`;
}

@Controller('auth')
export class AuthController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auth: AuthService,
    private readonly passwordResetDelivery: PasswordResetDeliveryService,
    private readonly passwordResetEmailGateway: PasswordResetEmailGateway
  ) {}

  @Post('register')
  @UseGuards(RateLimitGuard)
  @RateLimit({ limit: 5, windowMs: 60_000, keyPrefix: 'auth-register' })
  async register(@Body() body: UsernamePasswordDto) {
    let user;
    const passwordHash = await this.auth.hashPassword(body.password);
    try {
      user = await this.prisma.user.create({
        data: { username: body.username, passwordHash }
      });
    } catch (e: any) {
      if (e?.code !== 'P2002') throw e;
      user = await this.prisma.user.findUnique({ where: { username: body.username } });
      if (!user) throw e;
      const matches = await this.auth.verifyPassword(body.password, user.passwordHash);
      if (!matches) {
        throw new ConflictException('Username already exists');
      }
    }

    await ensurePersonalTenant(this.prisma, user.id, user.username);

    const token = await this.auth.issueToken(user.id, user.sessionVersion ?? 0);
    return {
      ...token,
      userId: user.id,
      username: user.username,
      accessLevel: 'member',
    };
  }

  @Post('login')
  @UseGuards(RateLimitGuard)
  @RateLimit({ limit: 10, windowMs: 60_000, keyPrefix: 'auth-login' })
  async login(@Body() body: UsernamePasswordDto) {
    const user = await this.prisma.user.findUnique({ where: { username: body.username } });
    if (!user) throw new NotFoundException('User not found');
    const matches = await this.auth.verifyPassword(body.password, user.passwordHash);
    if (!matches) {
      throw new UnauthorizedException('Invalid password');
    }

    await ensurePersonalTenant(this.prisma, user.id, user.username);

    const token = await this.auth.issueToken(user.id, user.sessionVersion ?? 0);
    return {
      ...token,
      userId: user.id,
      username: user.username,
      accessLevel: 'member',
    };
  }

  @Post('request-password-reset')
  @UseGuards(RateLimitGuard)
  @RateLimit({ limit: 5, windowMs: 60_000, keyPrefix: 'auth-request-password-reset' })
  async requestPasswordReset(@Body() body: RequestPasswordResetDto) {
    const user = await this.prisma.user.findUnique({
      where: { username: body.username },
    });
    if (!user) {
      return { ok: true };
    }

    const deliveryMode =
      body.deliveryMode === 'console'
        ? 'console'
        : body.deliveryMode === 'email'
          ? 'email'
          : 'preview';
    if (deliveryMode === 'email' && !body.username.includes('@')) {
      throw new BadRequestException(
        'Email delivery requires an email-style username'
      );
    }
    const now = new Date();
    const cooldownStartedAt = new Date(now.getTime() - 60_000);
    const recentRequest = await this.prisma.passwordResetToken.findFirst({
      where: {
        userId: user.id,
        consumedAt: null,
        expiresAt: { gt: now },
        createdAt: { gt: cooldownStartedAt },
      },
      orderBy: { createdAt: 'desc' },
    });
    if (recentRequest) {
      const cooldownSeconds = Math.max(
        1,
        Math.ceil((recentRequest.createdAt.getTime() + 60_000 - now.getTime()) / 1000),
      );
      return {
        ok: true,
        requestId: recentRequest.id,
        ...this.passwordResetDelivery.describeDelivery(
          recentRequest.deliveryMode as any,
          user.username
        ),
        previewHint: recentRequest.previewTail ? `...${recentRequest.previewTail}` : null,
        cooldownSeconds,
      };
    }

    const rawToken = this.auth.generateResetToken();
    const tokenHash = this.auth.hashResetToken(rawToken);
    const expiresAt = new Date(now.getTime() + 15 * 60_000);
    const previewTail = rawToken.substring(rawToken.length - 6);

    const resetRequest = await this.prisma.passwordResetToken.create({
      data: {
        userId: user.id,
        tokenHash,
        deliveryMode,
        previewTail,
        expiresAt,
      },
    });
    const delivery = await this.passwordResetDelivery.deliverResetToken({
      username: user.username,
      token: rawToken,
      expiresAt,
      deliveryMode,
    });

    return <Record<string, unknown>>{
      ok: true,
      requestId: resetRequest.id,
      deliveryMode: delivery.deliveryMode,
      deliveryTransport: delivery.deliveryTransport,
      deliveryTargetHint: delivery.deliveryTargetHint,
      ...(delivery.resetTokenPreview != null
          ? { resetTokenPreview: delivery.resetTokenPreview }
          : {}),
      previewHint: `...${previewTail}`,
      cooldownSeconds: 60,
      expiresAt: expiresAt.toISOString(),
    };
  }

  @Post('reset-password')
  @UseGuards(RateLimitGuard)
  @RateLimit({ limit: 10, windowMs: 60_000, keyPrefix: 'auth-reset-password' })
  async resetPassword(@Body() body: ResetPasswordDto) {
    const user = await this.prisma.user.findUnique({
      where: { username: body.username },
    });
    if (!user) {
      throw new UnauthorizedException('Invalid or expired reset token');
    }

    const tokenHash = this.auth.hashResetToken(body.resetToken);
    const resetRecord = await this.prisma.passwordResetToken.findFirst({
      where: {
        userId: user.id,
        tokenHash,
        consumedAt: null,
        expiresAt: { gt: new Date() },
      },
    });
    if (!resetRecord) {
      throw new UnauthorizedException('Invalid or expired reset token');
    }
    const sameAsCurrent = await this.auth.verifyPassword(
      body.newPassword,
      user.passwordHash
    );
    if (sameAsCurrent) {
      throw new ConflictException('New password must be different');
    }

    const passwordHash = await this.auth.hashPassword(body.newPassword);
    const now = new Date();
    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: user.id },
        data: {
          passwordHash,
          sessionVersion: { increment: 1 },
        },
      }),
      this.prisma.passwordResetToken.updateMany({
        where: {
          userId: user.id,
          consumedAt: null,
        },
        data: {
          consumedAt: now,
        },
      }),
    ]);

    return { ok: true };
  }

  @Post('change-password')
  @UseGuards(JwtAuthGuard)
  async changePassword(@Req() req: any, @Body() body: ChangePasswordDto) {
    const userId = requireUserId(req);
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    const matches = await this.auth.verifyPassword(
      body.currentPassword,
      user.passwordHash
    );
    if (!matches) {
      throw new UnauthorizedException('Invalid current password');
    }
    if (body.currentPassword === body.newPassword) {
      throw new ConflictException('New password must be different');
    }

    const passwordHash = await this.auth.hashPassword(body.newPassword);
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        passwordHash,
        sessionVersion: { increment: 1 },
      },
    });

    return { ok: true };
  }

  @Post('logout')
  @UseGuards(JwtAuthGuard)
  async logout(@Req() req: any) {
    const userId = requireUserId(req);
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        sessionVersion: { increment: 1 },
      },
    });

    return { ok: true };
  }

  @Get('password-reset-email-events')
  @UseGuards(JwtAuthGuard)
  async passwordResetEmailEvents(@Query('limit') limit?: string) {
    const parsedLimit = Number(limit || 20);
    const normalizedLimit = Number.isFinite(parsedLimit)
      ? Math.min(Math.max(Math.trunc(parsedLimit), 1), 100)
      : 20;
    return {
      events: this.passwordResetEmailGateway.listRecentEvents(normalizedLimit),
      config: this.passwordResetEmailGateway.configSnapshot(),
    };
  }

  @Get('password-reset-email-snapshot')
  @UseGuards(JwtAuthGuard)
  async passwordResetEmailSnapshot(@Query('limit') limit?: string) {
    const parsedLimit = Number(limit || 20);
    const normalizedLimit = Number.isFinite(parsedLimit)
      ? Math.min(Math.max(Math.trunc(parsedLimit), 1), 100)
      : 20;
    const events = this.passwordResetEmailGateway.listRecentEvents(normalizedLimit);
    const config = this.passwordResetEmailGateway.configSnapshot();
    return buildPasswordResetEmailSnapshotPayload(config as any, events as any);
  }

  @Get('password-reset-email-handoff')
  @UseGuards(JwtAuthGuard)
  async passwordResetEmailHandoff(@Query('limit') limit?: string) {
    const parsedLimit = Number(limit || 20);
    const normalizedLimit = Number.isFinite(parsedLimit)
      ? Math.min(Math.max(Math.trunc(parsedLimit), 1), 100)
      : 20;
    const events = this.passwordResetEmailGateway.listRecentEvents(normalizedLimit);
    const config = this.passwordResetEmailGateway.configSnapshot();
    const snapshot = buildPasswordResetEmailSnapshotPayload(config as any, events as any);

    return {
      generatedAt: snapshot.generatedAt,
      summaryText: buildPasswordResetEmailHandoffSummary(snapshot),
      snapshot,
    };
  }

  @Post('password-reset-email-check')
  @UseGuards(JwtAuthGuard)
  async passwordResetEmailCheck() {
    try {
      return {
        ok: true,
        result: await this.passwordResetEmailGateway.checkSmtpConnection(),
      };
    } catch (error) {
      return {
        ok: false,
        error: error instanceof Error ? error.message : String(error),
      };
    }
  }
}

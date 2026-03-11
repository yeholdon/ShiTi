import { Body, Controller, NotFoundException, Post, UseGuards } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { RateLimit } from '../../common/rate-limit/rate-limit.decorator';
import { RateLimitGuard } from '../../common/rate-limit/rate-limit.guard';
import { AuthService } from './auth.service';
import { UsernameDto } from './dto/username.dto';

@Controller('auth')
export class AuthController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auth: AuthService
  ) {}

  @Post('register')
  @UseGuards(RateLimitGuard)
  @RateLimit({ limit: 5, windowMs: 60_000, keyPrefix: 'auth-register' })
  async register(@Body() body: UsernameDto) {
    // Prisma upsert can still throw P2002 under concurrent register calls.
    // Make register idempotent by falling back to lookup when username already exists.
    let user;
    try {
      user = await this.prisma.user.create({ data: { username: body.username, passwordHash: 'dev' } });
    } catch (e: any) {
      if (e?.code !== 'P2002') throw e;
      user = await this.prisma.user.findUnique({ where: { username: body.username } });
      if (!user) throw e;
    }

    return this.auth.issueToken(user.id);
  }

  // Minimal dev-friendly login: exchange a username for a JWT.
  @Post('login')
  @UseGuards(RateLimitGuard)
  @RateLimit({ limit: 10, windowMs: 60_000, keyPrefix: 'auth-login' })
  async login(@Body() body: UsernameDto) {
    const user = await this.prisma.user.findUnique({ where: { username: body.username } });
    if (!user) throw new NotFoundException('User not found');

    return this.auth.issueToken(user.id);
  }
}

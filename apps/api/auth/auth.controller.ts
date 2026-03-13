import { Body, Controller, NotFoundException, Post, UseGuards } from '@nestjs/common';
import { RateLimit } from '../../../src/common/rate-limit/rate-limit.decorator';
import { RateLimitGuard } from '../../../src/common/rate-limit/rate-limit.guard';
import { PrismaService } from '../../../src/prisma/prisma.service';
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

  @Post('login')
  @UseGuards(RateLimitGuard)
  @RateLimit({ limit: 10, windowMs: 60_000, keyPrefix: 'auth-login' })
  async login(@Body() body: UsernameDto) {
    const user = await this.prisma.user.findUnique({ where: { username: body.username } });
    if (!user) throw new NotFoundException('User not found');

    return this.auth.issueToken(user.id);
  }
}

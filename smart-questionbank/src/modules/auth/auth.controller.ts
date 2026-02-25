import { Body, Controller, Post } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { AuthService } from './auth.service';

@Controller('auth')
export class AuthController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auth: AuthService
  ) {}

  @Post('register')
  async register(@Body() body: { username?: string }) {
    const username = (body?.username || '').trim();
    if (!username) throw new Error('Missing username');

    const user = await this.prisma.user.upsert({
      where: { username },
      update: {},
      create: { username, passwordHash: 'dev' }
    });

    return this.auth.issueToken(user.id);
  }

  // Minimal dev-friendly login: exchange a username for a JWT.
  @Post('login')
  async login(@Body() body: { username?: string }) {
    const username = (body?.username || '').trim();
    if (!username) throw new Error('Missing username');

    const user = await this.prisma.user.findUnique({ where: { username } });
    if (!user) throw new Error('User not found');

    return this.auth.issueToken(user.id);
  }
}

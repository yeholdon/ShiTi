import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { PrismaService } from '../../../src/prisma/prisma.service';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(private readonly prisma: PrismaService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: process.env.JWT_SECRET || 'dev-secret-change-me'
    });
  }

  async validate(payload: any) {
    const userId = payload?.sub as string | undefined;
    if (!userId) {
      throw new UnauthorizedException('Invalid token');
    }
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, sessionVersion: true },
    });
    if (!user) {
      throw new UnauthorizedException('User not found');
    }
    if ((payload?.ver ?? 0) !== user.sessionVersion) {
      throw new UnauthorizedException('Session expired');
    }
    return { userId: payload?.sub };
  }
}

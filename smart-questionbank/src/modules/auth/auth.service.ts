import { Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';

@Injectable()
export class AuthService {
  constructor(private readonly jwt: JwtService) {}

  async issueToken(userId: string): Promise<{ accessToken: string }> {
    if (!userId) throw new Error('Missing userId');

    const accessToken = await this.jwt.signAsync(
      { sub: userId },
      {
        // Keep payload stable; secret/expiry come from global JwtModule config.
      }
    );

    return { accessToken };
  }
}

import { Injectable } from '@nestjs/common';
import { randomBytes, createHash } from 'crypto';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';

@Injectable()
export class AuthService {
  constructor(private readonly jwt: JwtService) {}

  async hashPassword(password: string): Promise<string> {
    return bcrypt.hash(password, 10);
  }

  async verifyPassword(password: string, passwordHash: string): Promise<boolean> {
    if (!passwordHash) return false;
    return bcrypt.compare(password, passwordHash);
  }

  generateResetToken(): string {
    return randomBytes(24).toString('hex');
  }

  hashResetToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  async issueToken(
    userId: string,
    sessionVersion = 0
  ): Promise<{ accessToken: string }> {
    if (!userId) throw new Error('Missing userId');

    const accessToken = await this.jwt.signAsync(
      { sub: userId, ver: sessionVersion },
      {
      }
    );

    return { accessToken };
  }
}

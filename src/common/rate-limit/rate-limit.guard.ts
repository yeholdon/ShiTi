import { CanActivate, ExecutionContext, HttpException, HttpStatus, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import type { Request } from 'express';
import { RATE_LIMIT_METADATA_KEY, type RateLimitOptions } from './rate-limit.decorator';
import { RateLimitService } from './rate-limit.service';

@Injectable()
export class RateLimitGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly rateLimitService: RateLimitService
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const options = this.reflector.getAllAndOverride<RateLimitOptions | undefined>(RATE_LIMIT_METADATA_KEY, [
      context.getHandler(),
      context.getClass()
    ]);
    if (!options) return true;

    const req = context.switchToHttp().getRequest<Request>();
    if (process.env.NODE_ENV === 'test' && req.headers['x-test-rate-limit'] !== 'on') {
      return true;
    }

    const key = this.buildKey(req, options);
    const count = await this.rateLimitService.hit(key, options.windowMs);

    if (count > options.limit) {
      throw new HttpException({
        code: 'too_many_requests',
        message: 'Rate limit exceeded'
      }, HttpStatus.TOO_MANY_REQUESTS);
    }

    return true;
  }

  private buildKey(req: Request, options: RateLimitOptions): string {
    const forwardedFor = req.headers['x-forwarded-for'];
    const rawIp = Array.isArray(forwardedFor) ? forwardedFor[0] : forwardedFor;
    const ip = typeof rawIp === 'string' && rawIp.trim() ? rawIp.split(',')[0].trim() : req.ip || 'unknown';
    const prefix = options.keyPrefix || req.route?.path || req.path || 'global';
    return `${prefix}:${ip}`;
  }
}

import { Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import Redis from 'ioredis';

type MemoryEntry = {
  count: number;
  resetAt: number;
};

@Injectable()
export class RateLimitService implements OnModuleDestroy {
  private readonly logger = new Logger(RateLimitService.name);
  private readonly memoryBuckets = new Map<string, MemoryEntry>();
  private redis: Redis | null = null;
  private redisReady = false;
  private redisWarned = false;

  constructor() {
    const redisUrl = (process.env.REDIS_URL || '').trim();
    if (!redisUrl) return;

    this.redis = new Redis(redisUrl, {
      lazyConnect: true,
      maxRetriesPerRequest: 1
    });

    this.redis.on('ready', () => {
      this.redisReady = true;
      this.redisWarned = false;
    });

    this.redis.on('end', () => {
      this.redisReady = false;
    });

    this.redis.on('error', () => {
      this.redisReady = false;
      if (!this.redisWarned) {
        this.redisWarned = true;
        this.logger.warn('Redis-backed rate limiting unavailable; falling back to in-memory buckets');
      }
    });
  }

  async hit(key: string, windowMs: number) {
    if (this.redis) {
      const redisCount = await this.tryRedisHit(key, windowMs);
      if (redisCount != null) return redisCount;
    }

    return this.hitMemory(key, windowMs);
  }

  async onModuleDestroy() {
    if (this.redis) {
      await this.redis.quit().catch(() => this.redis?.disconnect());
    }
  }

  private async tryRedisHit(key: string, windowMs: number) {
    try {
      if (this.redis && this.redis.status === 'wait') {
        await this.redis.connect();
      }

      if (!this.redis) return null;

      const count = await this.redis.incr(key);
      if (count === 1) {
        await this.redis.pexpire(key, windowMs);
      }
      this.redisReady = true;
      return count;
    } catch {
      this.redisReady = false;
      if (!this.redisWarned) {
        this.redisWarned = true;
        this.logger.warn('Redis-backed rate limiting unavailable; falling back to in-memory buckets');
      }
      return null;
    }
  }

  private hitMemory(key: string, windowMs: number) {
    const now = Date.now();
    const current = this.memoryBuckets.get(key);

    if (!current || current.resetAt <= now) {
      this.memoryBuckets.set(key, { count: 1, resetAt: now + windowMs });
      this.gc(now);
      return 1;
    }

    current.count += 1;
    return current.count;
  }

  private gc(now: number) {
    if (this.memoryBuckets.size < 1000) return;
    for (const [key, value] of this.memoryBuckets.entries()) {
      if (value.resetAt <= now) this.memoryBuckets.delete(key);
    }
  }
}

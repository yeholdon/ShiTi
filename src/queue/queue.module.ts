import { Module } from '@nestjs/common';
import { QUEUE_CONNECTION } from './queue.constants';

function parseRedisUrl(redisUrl: string) {
  const url = new URL(redisUrl);
  const host = url.hostname;
  const port = url.port ? Number(url.port) : 6379;
  const password = url.password || undefined;
  const db = url.pathname && url.pathname !== '/' ? Number(url.pathname.slice(1)) : undefined;

  return { host, port, password, db };
}

@Module({
  providers: [
    {
      provide: QUEUE_CONNECTION,
      useFactory: () => {
        const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379';
        return parseRedisUrl(redisUrl);
      }
    }
  ],
  exports: [QUEUE_CONNECTION]
})
export class QueueModule {}

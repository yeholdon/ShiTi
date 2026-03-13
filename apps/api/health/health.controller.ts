import { Controller, Get, ServiceUnavailableException } from '@nestjs/common';
import { Client as MinioClient } from 'minio';
import Redis from 'ioredis';
import { PrismaService } from '../../../src/prisma/prisma.service';

@Controller('health')
export class HealthController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  getHealth() {
    return { status: 'ok' };
  }

  @Get('ready')
  async getReady() {
    const checks: Record<string, any> = {};

    checks.database = await this.checkDatabase();
    checks.redis = await this.checkRedis();
    checks.minio = await this.checkMinio();

    const failed = Object.values(checks).some((check: any) => check.status !== 'ok');
    const body = {
      status: failed ? 'not_ready' : 'ready',
      checks
    };

    if (failed) {
      throw new ServiceUnavailableException(body);
    }

    return body;
  }

  private async checkDatabase() {
    try {
      await this.prisma.$queryRawUnsafe('SELECT 1');
      return { status: 'ok' };
    } catch (error: any) {
      return { status: 'error', message: String(error?.message || error) };
    }
  }

  private async checkRedis() {
    const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379';
    const client = new Redis(redisUrl, { lazyConnect: true, maxRetriesPerRequest: 1 });

    try {
      await client.connect();
      const pong = await client.ping();
      return { status: pong === 'PONG' ? 'ok' : 'error', response: pong };
    } catch (error: any) {
      return { status: 'error', message: String(error?.message || error) };
    } finally {
      client.disconnect();
    }
  }

  private async checkMinio() {
    const endPoint = (process.env.MINIO_ENDPOINT || 'localhost').trim();
    const port = Number(process.env.MINIO_PORT || '9000');
    const useSSL = (process.env.MINIO_USE_SSL || 'false') === 'true';
    const accessKey = (process.env.MINIO_ACCESS_KEY || 'minioadmin').trim();
    const secretKey = (process.env.MINIO_SECRET_KEY || 'minioadmin').trim();
    const bucket = (process.env.MINIO_BUCKET || 'questionbank').trim();

    try {
      const client = new MinioClient({ endPoint, port, useSSL, accessKey, secretKey });
      const bucketExists = await client.bucketExists(bucket).catch(() => false);
      return { status: 'ok', bucketExists };
    } catch (error: any) {
      return { status: 'error', message: String(error?.message || error) };
    }
  }
}

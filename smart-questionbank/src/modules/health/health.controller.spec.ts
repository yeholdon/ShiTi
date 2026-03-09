import { HealthController } from './health.controller';

describe('HealthController', () => {
  it('returns ready when all checks pass', async () => {
    const controller = new HealthController({} as any);

    jest.spyOn<any, any>(controller as any, 'checkDatabase').mockResolvedValue({ status: 'ok' });
    jest.spyOn<any, any>(controller as any, 'checkRedis').mockResolvedValue({ status: 'ok' });
    jest.spyOn<any, any>(controller as any, 'checkMinio').mockResolvedValue({ status: 'ok', bucketExists: true });

    await expect(controller.getReady()).resolves.toEqual({
      status: 'ready',
      checks: {
        database: { status: 'ok' },
        redis: { status: 'ok' },
        minio: { status: 'ok', bucketExists: true }
      }
    });
  });

  it('returns 503 readiness payload when any dependency check fails', async () => {
    const controller = new HealthController({} as any);

    jest.spyOn<any, any>(controller as any, 'checkDatabase').mockResolvedValue({ status: 'ok' });
    jest.spyOn<any, any>(controller as any, 'checkRedis').mockResolvedValue({
      status: 'error',
      message: 'ECONNREFUSED redis'
    });
    jest.spyOn<any, any>(controller as any, 'checkMinio').mockResolvedValue({ status: 'ok', bucketExists: true });

    await expect(controller.getReady()).rejects.toMatchObject({
      response: {
        status: 'not_ready',
        checks: {
          database: { status: 'ok' },
          redis: { status: 'error', message: 'ECONNREFUSED redis' },
          minio: { status: 'ok', bucketExists: true }
        }
      }
    });
  });
});

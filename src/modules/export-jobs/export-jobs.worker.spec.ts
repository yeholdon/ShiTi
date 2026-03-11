const workerInstances: Array<{
  processor: (job: any) => Promise<any>;
  handlers: Record<string, (...args: any[]) => any>;
}> = [];

jest.mock('bullmq', () => ({
  Worker: jest.fn().mockImplementation((_queueName: string, processor: (job: any) => Promise<any>) => {
    const handlers: Record<string, (...args: any[]) => any> = {};
    const instance = {
      processor,
      handlers
    };
    workerInstances.push(instance);

    return {
      on: jest.fn((event: string, handler: (...args: any[]) => any) => {
        handlers[event] = handler;
      }),
      close: jest.fn().mockResolvedValue(undefined)
    };
  })
}));

import { ExportJobsWorker } from './export-jobs.worker';

function makePrisma(overrides: Partial<any> = {}) {
  return {
    withTenant: jest.fn(),
    ...overrides
  } as any;
}

describe('ExportJobsWorker', () => {
  beforeEach(() => {
    workerInstances.length = 0;
    delete process.env.MINIO_ENDPOINT;
    delete process.env.MINIO_ACCESS_KEY;
    delete process.env.MINIO_SECRET_KEY;
    delete process.env.MINIO_BUCKET;
    delete process.env.EXPORT_JOBS_WORKER_ENABLED;
  });

  it('does not start a worker when EXPORT_JOBS_WORKER_ENABLED=0', async () => {
    process.env.EXPORT_JOBS_WORKER_ENABLED = '0';

    const worker = new ExportJobsWorker(makePrisma(), {});
    await worker.onModuleInit();

    expect(workerInstances).toHaveLength(0);
  });

  it('falls back to local export mode when MinIO init fails', async () => {
    const worker = new ExportJobsWorker(makePrisma(), {});

    await worker.onModuleInit();

    expect(workerInstances).toHaveLength(1);
    expect((worker as any).minio).toBeUndefined();
  });

  it('skips canceled jobs without moving them back through running/succeeded', async () => {
    const prisma = makePrisma();
    prisma.withTenant.mockImplementation(async (_tenantId: string, fn: any) =>
      fn({
        exportJob: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'job-1',
            status: 'canceled',
            documentId: 'doc-1'
          }),
          update: jest.fn()
        },
        asset: {
          create: jest.fn()
        }
      })
    );

    const worker = new ExportJobsWorker(prisma, {});
    await worker.onModuleInit();

    expect(workerInstances).toHaveLength(1);
    await expect(workerInstances[0].processor({ data: { tenantId: 't1', exportJobId: 'job-1' } })).resolves.toBeUndefined();

    expect(prisma.withTenant).toHaveBeenCalledTimes(1);
  });

  it('records failed status when the worker failed hook fires', async () => {
    const prisma = makePrisma();
    const update = jest.fn().mockResolvedValue({ id: 'job-1', status: 'failed' });
    prisma.withTenant.mockImplementation(async (_tenantId: string, fn: any) =>
      fn({
        exportJob: {
          update
        }
      })
    );

    const worker = new ExportJobsWorker(prisma, {});
    await worker.onModuleInit();

    expect(workerInstances).toHaveLength(1);
    await workerInstances[0].handlers.failed?.({ data: { tenantId: 't1', exportJobId: 'job-1' } }, new Error('render boom'));

    expect(update).toHaveBeenCalledWith({
      where: { tenantId_id: { tenantId: 't1', id: 'job-1' } },
      data: { status: 'failed', errorMessage: 'render boom' }
    });
  });
});

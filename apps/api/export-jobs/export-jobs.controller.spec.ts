import * as fs from 'node:fs/promises';
import { ServiceUnavailableException } from '@nestjs/common';
import { ExportJobsController } from './export-jobs.controller';

jest.mock('node:fs/promises', () => ({
  readFile: jest.fn()
}));

function makePrisma(overrides: Partial<any> = {}) {
  return {
    withTenant: jest.fn(),
    ...overrides
  } as any;
}

function makeAudit(overrides: Partial<any> = {}) {
  return {
    record: jest.fn(),
    ...overrides
  } as any;
}

describe('ExportJobsController', () => {
  it('marks created export jobs as failed when queue enqueue fails', async () => {
    const prisma = makePrisma();
    const failedUpdate = jest.fn().mockResolvedValue({ id: 'job-1', status: 'failed' });
    prisma.withTenant
      .mockImplementationOnce(async (_tenantId: string, fn: any) =>
        fn({
          tenantMember: { findFirst: jest.fn().mockResolvedValue({ id: 'm1', role: 'owner', status: 'active' }) }
        })
      )
      .mockImplementationOnce(async (_tenantId: string, fn: any) =>
        fn({
          document: { findUnique: jest.fn().mockResolvedValue({ id: 'doc-1' }) },
          exportJob: { create: jest.fn().mockResolvedValue({ id: 'job-1', documentId: 'doc-1' }) }
        })
      )
      .mockImplementationOnce(async (_tenantId: string, fn: any) =>
        fn({
          exportJob: { update: failedUpdate }
        })
      );

    const controller = new ExportJobsController(prisma, {}, makeAudit());
    jest.spyOn<any, any>(controller as any, 'openQueue').mockResolvedValue({
      add: jest.fn().mockRejectedValue(new Error('redis down')),
      close: jest.fn().mockResolvedValue(undefined)
    });

    await expect(
      controller.create(
        { tenant: { tenantId: 't1' }, auth: { userId: 'u1' } } as any,
        { documentId: 'doc-1' }
      )
    ).rejects.toBeInstanceOf(ServiceUnavailableException);

    expect(failedUpdate).toHaveBeenCalledWith({
      where: { tenantId_id: { tenantId: 't1', id: 'job-1' } },
      data: {
        status: 'failed',
        errorMessage: 'Queue enqueue failed: redis down'
      }
    });
  });

  it('marks retried export jobs as failed when re-queueing fails', async () => {
    const prisma = makePrisma();
    const failedUpdate = jest.fn().mockResolvedValue({ id: 'job-1', status: 'failed' });
    prisma.withTenant
      .mockImplementationOnce(async (_tenantId: string, fn: any) =>
        fn({
          tenantMember: { findFirst: jest.fn().mockResolvedValue({ id: 'm1', role: 'owner', status: 'active' }) }
        })
      )
      .mockImplementationOnce(async (_tenantId: string, fn: any) =>
        fn({
          exportJob: {
            findUnique: jest.fn().mockResolvedValue({
              id: 'job-1',
              status: 'failed',
              documentId: 'doc-1'
            })
          }
        })
      )
      .mockImplementationOnce(async (_tenantId: string, fn: any) =>
        fn({
          exportJob: {
            update: jest.fn().mockResolvedValue({
              id: 'job-1',
              status: 'pending',
              documentId: 'doc-1'
            })
          }
        })
      )
      .mockImplementationOnce(async (_tenantId: string, fn: any) =>
        fn({
          exportJob: { update: failedUpdate }
        })
      );

    const controller = new ExportJobsController(prisma, {}, makeAudit());
    const openQueueSpy = jest.spyOn<any, any>(controller as any, 'openQueue');
    openQueueSpy
      .mockResolvedValueOnce({
        getJob: jest.fn().mockResolvedValue(null),
        close: jest.fn().mockResolvedValue(undefined)
      })
      .mockResolvedValueOnce({
        add: jest.fn().mockRejectedValue(new Error('redis down')),
        close: jest.fn().mockResolvedValue(undefined)
      });

    await expect(
      controller.retry(
        { tenant: { tenantId: 't1' }, auth: { userId: 'u1' } } as any,
        { id: 'job-1' }
      )
    ).rejects.toBeInstanceOf(ServiceUnavailableException);

    expect(failedUpdate).toHaveBeenCalledWith({
      where: { tenantId_id: { tenantId: 't1', id: 'job-1' } },
      data: {
        status: 'failed',
        errorMessage: 'Queue enqueue failed: redis down'
      }
    });
  });

  it('rejects result download while export is not ready', async () => {
    const prisma = makePrisma();
    prisma.withTenant.mockImplementation(async (_tenantId: string, fn: any) =>
      fn({
        tenantMember: { findFirst: jest.fn().mockResolvedValue({ id: 'm1', role: 'owner', status: 'active' }) },
        exportJob: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'job-1',
            status: 'pending',
            resultAssetId: null
          })
        }
      })
    );

    const controller = new ExportJobsController(prisma, {}, makeAudit());

    await expect(
      controller.getResult(
        { tenant: { tenantId: 't1' }, auth: { userId: 'u1' } } as any,
        {} as any,
        { id: 'job-1' }
      )
    ).rejects.toThrow('Export result not ready');
  });

  it('returns not found when export metadata exists but result asset is missing', async () => {
    const prisma = makePrisma();
    prisma.withTenant.mockImplementation(async (_tenantId: string, fn: any) =>
      fn({
        tenantMember: { findFirst: jest.fn().mockResolvedValue({ id: 'm1', role: 'owner', status: 'active' }) },
        exportJob: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'job-1',
            status: 'succeeded',
            resultAssetId: 'asset-1'
          })
        },
        asset: {
          findUnique: jest.fn().mockResolvedValue(null)
        }
      })
    );

    const controller = new ExportJobsController(prisma, {}, makeAudit());

    await expect(
      controller.getResult(
        { tenant: { tenantId: 't1' }, auth: { userId: 'u1' } } as any,
        {} as any,
        { id: 'job-1' }
      )
    ).rejects.toThrow('Asset not found');
  });

  it('returns service unavailable when a local export file cannot be read', async () => {
    const prisma = makePrisma();
    prisma.withTenant.mockImplementation(async (_tenantId: string, fn: any) =>
      fn({
        tenantMember: { findFirst: jest.fn().mockResolvedValue({ id: 'm1', role: 'owner', status: 'active' }) },
        exportJob: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'job-1',
            status: 'succeeded',
            resultAssetId: 'asset-1'
          })
        },
        asset: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'asset-1',
            storageKey: '/tmp/missing-export.pdf',
            mime: 'application/pdf'
          })
        }
      })
    );

    const controller = new ExportJobsController(prisma, {}, makeAudit());
    jest.mocked(fs.readFile).mockRejectedValueOnce(new Error('ENOENT'));

    await expect(
      controller.getResult(
        { tenant: { tenantId: 't1' }, auth: { userId: 'u1' } } as any,
        {} as any,
        { id: 'job-1' }
      )
    ).rejects.toBeInstanceOf(ServiceUnavailableException);
  });
});

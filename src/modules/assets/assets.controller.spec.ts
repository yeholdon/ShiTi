import { ServiceUnavailableException } from '@nestjs/common';
import { AssetsController } from './assets.controller';

jest.mock('../../tenant/tenant-guards', () => ({
  requireTenantId: jest.fn(() => 'tenant-1'),
  requireUserId: jest.fn(() => 'user-1'),
  requireTenantRole: jest.fn().mockResolvedValue(undefined),
  requireActiveTenantMember: jest.fn().mockResolvedValue(undefined)
}));

describe('AssetsController', () => {
  const tenantReq = {
    tenantId: 'tenant-1',
    tenantCode: 'tenant-a',
    user: { sub: 'user-1' }
  } as any;

  it('returns service unavailable and records a failed audit when bucket initialization fails', async () => {
    const auditRecord = jest.fn().mockResolvedValue(undefined);
    const prisma = {} as any;
    const controller = new AssetsController(prisma, { record: auditRecord } as any);

    jest.spyOn<any, any>(controller as any, 'ensureBucket').mockRejectedValue(new Error('minio down'));

    await expect(
      controller.createUpload(tenantReq, {
        filename: 'figure.png',
        mime: 'image/png',
        size: 123,
        kind: 'image'
      } as any)
    ).rejects.toBeInstanceOf(ServiceUnavailableException);

    expect(auditRecord).toHaveBeenCalledWith({
      tenantId: 'tenant-1',
      userId: 'user-1',
      action: 'asset.upload_failed',
      targetType: 'asset',
      details: {
        filename: 'figure.png',
        reason: 'bucket_unavailable:minio down'
      }
    });
  });

  it('rolls back asset metadata when presign generation fails', async () => {
    const createdAsset = { id: 'asset-1' };
    const assetCreate = jest.fn().mockResolvedValue(createdAsset);
    const assetDelete = jest.fn().mockResolvedValue(undefined);
    const auditRecord = jest.fn().mockResolvedValue(undefined);
    const prisma = {
      withTenant: jest.fn(async (_tenantId: string, run: (tx: any) => Promise<any>) =>
        run({
          asset: {
            create: assetCreate,
            delete: assetDelete
          }
        })
      )
    } as any;
    const controller = new AssetsController(prisma, { record: auditRecord } as any);

    jest.spyOn<any, any>(controller as any, 'ensureBucket').mockResolvedValue(undefined);
    (controller as any).minio = {
      presignedPutObject: jest.fn().mockRejectedValue(new Error('presign unavailable'))
    };

    await expect(
      controller.createUpload(tenantReq, {
        filename: 'figure.png',
        mime: 'image/png',
        size: 123,
        kind: 'image'
      } as any)
    ).rejects.toBeInstanceOf(ServiceUnavailableException);

    expect(assetCreate).toHaveBeenCalled();
    expect(assetDelete).toHaveBeenCalledWith({
      where: { tenantId_id: { tenantId: 'tenant-1', id: 'asset-1' } }
    });
    expect(auditRecord).toHaveBeenCalledWith({
      tenantId: 'tenant-1',
      userId: 'user-1',
      action: 'asset.upload_failed',
      targetType: 'asset',
      targetId: 'asset-1',
      details: {
        filename: 'figure.png',
        reason: 'presign_failed:presign unavailable'
      }
    });
  });
});

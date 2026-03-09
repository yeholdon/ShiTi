import { BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

function collectAssetIds(value: unknown, assetIds: Set<string>) {
  if (Array.isArray(value)) {
    for (const item of value) collectAssetIds(item, assetIds);
    return;
  }

  if (value && typeof value === 'object') {
    for (const [key, nestedValue] of Object.entries(value as Record<string, unknown>)) {
      if (key === 'assetId' && typeof nestedValue === 'string' && nestedValue.trim()) {
        assetIds.add(nestedValue.trim());
      } else {
        collectAssetIds(nestedValue, assetIds);
      }
    }
  }
}

export function valueContainsAssetId(value: unknown, assetId: string) {
  const assetIds = new Set<string>();
  collectAssetIds(value, assetIds);
  return assetIds.has(assetId);
}

export async function validateAssetReferences(prisma: PrismaService, tenantId: string, ...values: unknown[]) {
  const assetIds = new Set<string>();
  for (const value of values) collectAssetIds(value, assetIds);

  const ids = [...assetIds];
  if (ids.length === 0) return;

  const existingAssets = await prisma.withTenant(tenantId, (tx) =>
    tx.asset.findMany({ where: { tenantId, id: { in: ids } }, select: { id: true } })
  );

  if (existingAssets.length !== ids.length) {
    throw new BadRequestException('Some assetId references are invalid for current tenant');
  }
}

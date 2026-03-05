import { Injectable } from '@nestjs/common';
import { Prisma, PrismaClient } from '@prisma/client';

const UUID_V4_OR_V1_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

@Injectable()
export class PrismaService extends PrismaClient {
  async withTenant<T>(tenantId: string, fn: (tx: Prisma.TransactionClient) => Promise<T>): Promise<T> {
    if (!UUID_V4_OR_V1_RE.test(tenantId)) {
      throw new Error('Invalid tenantId');
    }

    return this.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT set_config('app.tenant_id', ${tenantId}, true)`;
      return fn(tx);
    });
  }
}

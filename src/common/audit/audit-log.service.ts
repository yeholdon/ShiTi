import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

type AuditQueryOptions = {
  action?: string;
  targetType?: string;
  userId?: string;
  limit?: number;
  offset?: number;
  sortOrder?: 'asc' | 'desc';
  since?: Date;
  until?: Date;
};

export type AuditLogEntry = {
  id: string;
  at: string;
  tenantId: string | null;
  userId: string | null;
  username?: string | null;
  action: string;
  targetType: string;
  targetId: string | null;
  details?: Prisma.JsonValue;
};

export type AuditLogStats = {
  total: number;
  byAction: Array<{ action: string; count: number }>;
  byTargetType: Array<{ targetType: string; count: number }>;
  byUser: Array<{ userId: string | null; username: string | null; count: number }>;
};

type RecordAuditInput = {
  tenantId?: string | null;
  userId?: string | null;
  action: string;
  targetType: string;
  targetId?: string | null;
  details?: Prisma.InputJsonValue;
};

@Injectable()
export class AuditLogService {
  constructor(private readonly prisma: PrismaService) {}

  async record(input: RecordAuditInput): Promise<void> {
    if (!input.tenantId) return;
    await this.prisma.withTenant(input.tenantId, (tx) =>
      tx.auditLog.create({
        data: {
          tenantId: input.tenantId!,
          userId: input.userId ?? null,
          action: input.action,
          targetType: input.targetType,
          targetId: input.targetId ?? null,
          details: input.details
        }
      })
    );
  }

  async listForTenant(
    tenantId: string,
    options?: AuditQueryOptions
  ): Promise<{ logs: AuditLogEntry[]; total: number; limit: number; offset: number; sortBy: 'createdAt'; sortOrder: 'asc' | 'desc' }> {
    const limit = Math.min(Math.max(options?.limit ?? 50, 1), 200);
    const offset = Math.max(options?.offset ?? 0, 0);
    const sortOrder = options?.sortOrder === 'asc' ? 'asc' : 'desc';
    const where = buildAuditWhere(tenantId, options);

    const [logs, total] = await this.prisma.withTenant(tenantId, (tx) =>
      Promise.all([
        tx.auditLog.findMany({
          where,
          orderBy: { createdAt: sortOrder },
          skip: offset,
          take: limit
        }),
        tx.auditLog.count({ where })
      ])
    );
    const usernames = await this.loadUsernames(logs.map((entry) => entry.userId));

    return {
      logs: logs.map((entry) => ({
        id: entry.id,
        at: entry.createdAt.toISOString(),
        tenantId: entry.tenantId,
        userId: entry.userId,
        username: entry.userId ? (usernames.get(entry.userId) ?? null) : null,
        action: entry.action,
        targetType: entry.targetType,
        targetId: entry.targetId,
        details: entry.details ?? undefined
      })),
      total,
      limit,
      offset,
      sortBy: 'createdAt',
      sortOrder
    };
  }

  async statsForTenant(tenantId: string, options?: AuditQueryOptions): Promise<AuditLogStats> {
    const where = buildAuditWhere(tenantId, options);

    const [total, byAction, byTargetType, byUser] = await this.prisma.withTenant(tenantId, async (tx) =>
      Promise.all([
        tx.auditLog.count({ where }),
        tx.auditLog.groupBy({
          by: ['action'],
          where,
          _count: { _all: true },
          orderBy: { _count: { action: 'desc' } }
        }),
        tx.auditLog.groupBy({
          by: ['targetType'],
          where,
          _count: { _all: true },
          orderBy: { _count: { targetType: 'desc' } }
        }),
        tx.auditLog.groupBy({
          by: ['userId'],
          where,
          _count: { _all: true },
          orderBy: { _count: { userId: 'desc' } }
        })
      ])
    );
    const usernames = await this.loadUsernames(byUser.map((entry) => entry.userId));

    return {
      total,
      byAction: byAction.map((entry) => ({
        action: entry.action,
        count: entry._count._all
      })),
      byTargetType: byTargetType.map((entry) => ({
        targetType: entry.targetType,
        count: entry._count._all
      })),
      byUser: byUser.map((entry) => ({
        userId: entry.userId,
        username: entry.userId ? (usernames.get(entry.userId) ?? null) : null,
        count: entry._count._all
      }))
    };
  }

  private async loadUsernames(userIds: Array<string | null>): Promise<Map<string, string>> {
    const uniqueIds = Array.from(new Set(userIds.filter(Boolean))) as string[];
    const users =
      uniqueIds.length > 0
        ? await this.prisma.user.findMany({
            where: { id: { in: uniqueIds } },
            select: { id: true, username: true }
          })
        : [];

    return new Map(users.map((user) => [user.id, user.username]));
  }
}

function buildAuditWhere(tenantId: string, options?: AuditQueryOptions): Prisma.AuditLogWhereInput {
  const action = options?.action?.trim();
  const targetType = options?.targetType?.trim();
  const userId = options?.userId?.trim();
  const createdAt =
    options?.since || options?.until
      ? {
          ...(options.since ? { gte: options.since } : {}),
          ...(options.until ? { lte: options.until } : {})
        }
      : undefined;

  return {
    tenantId,
    ...(action ? { action } : {}),
    ...(targetType ? { targetType } : {}),
    ...(userId ? { userId } : {}),
    ...(createdAt ? { createdAt } : {})
  };
}

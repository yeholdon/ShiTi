import { BadRequestException, Controller, Get, Query, Req, UseGuards } from '@nestjs/common';
import type { Request } from 'express';
import { JwtAuthGuard } from '../../modules/auth/jwt-auth.guard';
import { PrismaService } from '../../prisma/prisma.service';
import { requireTenantId, requireTenantRole, requireUserId } from '../../tenant/tenant-guards';
import { AuditLogService } from './audit-log.service';

@Controller('audit-logs')
@UseGuards(JwtAuthGuard)
export class AuditLogsController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditLogService
  ) {}

  @Get('stats')
  async stats(
    @Req() req: Request,
    @Query('action') action?: string,
    @Query('targetType') targetType?: string,
    @Query('userId') filterUserId?: string,
    @Query('since') since?: string,
    @Query('until') until?: string
  ) {
    const { tenantId, action: normalizedAction, targetType: normalizedTargetType, filterUserId: normalizedUserId, sinceDate, untilDate } =
      await this.resolveAuditQueryContext(req, action, targetType, filterUserId, since, until);

    const stats = await this.audit.statsForTenant(tenantId, {
      action: normalizedAction,
      targetType: normalizedTargetType,
      userId: normalizedUserId,
      since: sinceDate ?? undefined,
      until: untilDate ?? undefined
    });

    return {
      stats,
      meta: {
        action: normalizedAction || null,
        targetType: normalizedTargetType || null,
        userId: normalizedUserId || null,
        since: sinceDate?.toISOString() ?? null,
        until: untilDate?.toISOString() ?? null
      }
    };
  }

  @Get()
  async list(
    @Req() req: Request,
    @Query('action') action?: string,
    @Query('targetType') targetType?: string,
    @Query('userId') filterUserId?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
    @Query('sortBy') sortBy?: string,
    @Query('sortOrder') sortOrder?: string,
    @Query('since') since?: string,
    @Query('until') until?: string
  ) {
    const { tenantId, action: normalizedAction, targetType: normalizedTargetType, filterUserId: normalizedUserId, sinceDate, untilDate } =
      await this.resolveAuditQueryContext(req, action, targetType, filterUserId, since, until);
    const numericLimit = typeof limit === 'string' && limit.trim() ? Number(limit.trim()) : 50;
    const numericOffset = typeof offset === 'string' && offset.trim() ? Number(offset.trim()) : 0;
    const normalizedSortBy = sortBy?.trim() === 'createdAt' ? 'createdAt' : 'createdAt';
    const normalizedSortOrder = sortOrder?.trim() === 'asc' ? 'asc' : 'desc';
    const result = await this.audit.listForTenant(tenantId, {
      action: normalizedAction,
      targetType: normalizedTargetType,
      userId: normalizedUserId,
      limit: Number.isFinite(numericLimit) ? numericLimit : 50,
      offset: Number.isFinite(numericOffset) ? numericOffset : 0,
      sortOrder: normalizedSortOrder,
      since: sinceDate ?? undefined,
      until: untilDate ?? undefined
    });

    return {
      logs: result.logs,
      meta: {
        returned: result.logs.length,
        total: result.total,
        limit: result.limit,
        offset: result.offset,
        hasMore: result.offset + result.logs.length < result.total,
        sortBy: normalizedSortBy,
        sortOrder: result.sortOrder,
        action: normalizedAction || null,
        targetType: normalizedTargetType || null,
        userId: normalizedUserId || null,
        since: sinceDate?.toISOString() ?? null,
        until: untilDate?.toISOString() ?? null
      }
    };
  }

  private async resolveAuditQueryContext(
    req: Request,
    action?: string,
    targetType?: string,
    filterUserId?: string,
    since?: string,
    until?: string
  ) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    const sinceDate = parseDateQueryValue(since, 'since');
    const untilDate = parseDateQueryValue(until, 'until');
    if (sinceDate && untilDate && sinceDate.getTime() > untilDate.getTime()) {
      throw new BadRequestException('since must be earlier than or equal to until');
    }

    return {
      tenantId,
      action: action?.trim(),
      targetType: targetType?.trim(),
      filterUserId: filterUserId?.trim(),
      sinceDate,
      untilDate
    };
  }
}

function parseDateQueryValue(value: string | undefined, label: 'since' | 'until'): Date | null {
  if (typeof value !== 'string' || !value.trim()) return null;

  const parsed = new Date(value.trim());
  if (Number.isNaN(parsed.getTime())) {
    throw new BadRequestException(`${label} must be a valid ISO date`);
  }

  return parsed;
}

import { Injectable, NestMiddleware } from '@nestjs/common';
import type { Request, Response, NextFunction } from 'express';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class TenantResolveMiddleware implements NestMiddleware {
  constructor(private readonly prisma: PrismaService) {}

  async use(req: Request, _res: Response, next: NextFunction) {
    const code = (req.header('x-tenant-code') || req.header('X-Tenant-Code') || '').trim();

    if (!code) {
      (req as any).tenant = { tenantCode: null, tenantId: null };
      return next();
    }

    const tenant = await this.prisma.tenant.findUnique({ where: { code } });
    (req as any).tenant = { tenantCode: code, tenantId: tenant?.id ?? null };

    return next();
  }
}

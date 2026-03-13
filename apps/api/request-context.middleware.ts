import type { NextFunction, Request, Response } from 'express';
import { randomUUID } from 'node:crypto';
import { HttpMetricsService } from './metrics/http-metrics.service';

type RequestWithContext = Request & {
  requestId?: string;
  auth?: { userId: string };
  tenant?: { tenantCode: string | null; tenantId: string | null };
};

export function createRequestContextMiddleware(metrics: HttpMetricsService) {
  return (req: RequestWithContext, res: Response, next: NextFunction) => {
    const startedAt = Date.now();
    const requestId = (req.header('x-request-id') || '').trim() || randomUUID();

    req.requestId = requestId;
    res.setHeader('x-request-id', requestId);

    res.on('finish', () => {
      const durationMs = Date.now() - startedAt;
      metrics.recordRequest(req.method, res.statusCode, durationMs);

      const tenantCode = req.tenant?.tenantCode ?? null;
      const tenantId = req.tenant?.tenantId ?? null;
      const payload = {
        level: 'info',
        type: 'http_request',
        requestId,
        method: req.method,
        path: req.originalUrl || req.url,
        statusCode: res.statusCode,
        durationMs,
        tenantCode,
        tenantId
      };
      process.stdout.write(JSON.stringify(payload) + '\n');
    });

    next();
  };
}

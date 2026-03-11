import type { NextFunction, Request, Response } from 'express';
import { randomUUID } from 'node:crypto';
import { HttpMetricsService } from './metrics/http-metrics.service';

type RequestWithContext = Request & {
  requestId?: string;
  tenantId?: string | null;
  tenantCode?: string | null;
};

export function createRequestContextMiddleware(metrics: HttpMetricsService) {
  return function requestContextMiddleware(req: Request, res: Response, next: NextFunction) {
    const request = req as RequestWithContext;
    const requestId = String(req.header('x-request-id') || randomUUID());
    const startedAt = Date.now();

    request.requestId = requestId;
    res.setHeader('X-Request-Id', requestId);

    res.on('finish', () => {
      const durationMs = Date.now() - startedAt;
      metrics.recordRequest(req.method, res.statusCode, durationMs);

      const payload = {
        level: 'info',
        type: 'http_request',
        requestId,
        method: req.method,
        path: req.originalUrl || req.url,
        statusCode: res.statusCode,
        durationMs,
        tenantCode: request.tenantCode || req.header('x-tenant-code') || null,
        tenantId: request.tenantId || null
      };

      // eslint-disable-next-line no-console
      console.log(JSON.stringify(payload));
    });

    next();
  };
}

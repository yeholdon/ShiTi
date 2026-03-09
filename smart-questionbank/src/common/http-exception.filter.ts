import { ArgumentsHost, Catch, ExceptionFilter, HttpException, HttpStatus } from '@nestjs/common';
import type { Request, Response } from 'express';

function normalizeMessage(value: unknown): string | string[] {
  if (Array.isArray(value)) return value.map((item) => String(item));
  if (typeof value === 'string') return value;
  if (value == null) return 'Request failed';
  return String(value);
}

function defaultCode(statusCode: number) {
  if (statusCode === 400) return 'bad_request';
  if (statusCode === 401) return 'unauthorized';
  if (statusCode === 403) return 'forbidden';
  if (statusCode === 404) return 'not_found';
  if (statusCode === 409) return 'conflict';
  if (statusCode === 422) return 'unprocessable_entity';
  if (statusCode === 429) return 'too_many_requests';
  if (statusCode >= 500) return 'internal_error';
  return 'request_failed';
}

type RequestWithContext = Request & {
  requestId?: string;
};

@Catch()
export class HttpErrorFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<RequestWithContext>();

    const isHttpException = exception instanceof HttpException;
    const statusCode = isHttpException ? exception.getStatus() : HttpStatus.INTERNAL_SERVER_ERROR;
    const raw = isHttpException ? exception.getResponse() : null;
    const payload = typeof raw === 'string' ? { message: raw } : ((raw as Record<string, unknown> | null) ?? {});
    const message = normalizeMessage(payload.message ?? (exception instanceof Error ? exception.message : 'Internal server error'));
    const code =
      typeof payload.code === 'string' && payload.code.trim() ? payload.code.trim() : defaultCode(statusCode);

    const body: Record<string, unknown> = {
      statusCode,
      message,
      error: {
        code,
        message
      },
      path: request.originalUrl || request.url,
      timestamp: new Date().toISOString(),
      requestId: request.requestId || null
    };

    const details = payload.details;
    if (details !== undefined) {
      body.error = {
        ...(body.error as Record<string, unknown>),
        details
      };
    }

    response.status(statusCode).json(body);
  }
}

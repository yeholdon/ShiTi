import 'reflect-metadata';
import { BadRequestException, ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import type { INestApplication } from '@nestjs/common';
import express from 'express';
import type { Request, Response } from 'express';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { AppModule } from './app.module';
import { HttpErrorFilter } from './common/http-exception.filter';
import { HttpMetricsService } from './common/metrics/http-metrics.service';
import { createRequestContextMiddleware } from './common/request-context.middleware';
import './tenant/tenant.types';

function toValidationDetails(errors: any[], parentPath = ''): Array<{ field: string; messages: string[] }> {
  return errors.flatMap((error) => {
    const field = parentPath ? `${parentPath}.${error.property}` : error.property;
    const messages = error.constraints ? Object.values(error.constraints).map((item) => String(item)) : [];
    const children = Array.isArray(error.children) ? toValidationDetails(error.children, field) : [];
    const current = messages.length > 0 ? [{ field, messages }] : [];
    return [...current, ...children];
  });
}

function logLifecycle(level: 'info' | 'warn' | 'error', type: string, details: Record<string, unknown> = {}) {
  const payload = {
    level,
    type,
    timestamp: new Date().toISOString(),
    pid: process.pid,
    ...details
  };

  const line = JSON.stringify(payload);
  if (level === 'error') {
    // eslint-disable-next-line no-console
    console.error(line);
    return;
  }
  // eslint-disable-next-line no-console
  console.log(line);
}

function normalizeError(error: unknown) {
  if (error instanceof Error) {
    return {
      name: error.name,
      message: error.message,
      stack: error.stack || null
    };
  }

  return {
    name: 'NonErrorThrown',
    message: typeof error === 'string' ? error : JSON.stringify(error),
    stack: null
  };
}

function installProcessLifecycleLogging(app: INestApplication, port: number) {
  const state = {
    closing: false
  };

  const closeApp = async (reason: string, code: number) => {
    if (state.closing) return;
    state.closing = true;

    logLifecycle(code === 0 ? 'warn' : 'error', 'process_shutdown', {
      reason,
      code
    });

    try {
      await app.close();
    } catch (error) {
      logLifecycle('error', 'app_close_failed', normalizeError(error));
    } finally {
      process.exit(code);
    }
  };

  process.once('SIGINT', () => {
    void closeApp('SIGINT', 0);
  });

  process.once('SIGTERM', () => {
    void closeApp('SIGTERM', 0);
  });

  process.once('uncaughtException', (error) => {
    logLifecycle('error', 'uncaught_exception', {
      port,
      ...normalizeError(error)
    });
    void closeApp('uncaughtException', 1);
  });

  process.once('unhandledRejection', (reason) => {
    logLifecycle('error', 'unhandled_rejection', {
      port,
      ...normalizeError(reason)
    });
    void closeApp('unhandledRejection', 1);
  });
}

async function bootstrap() {
  const port = Number(process.env.PORT || 3000);
  logLifecycle('info', 'bootstrap_start', {
    port,
    nodeEnv: process.env.NODE_ENV || 'development',
    workerEnabled: process.env.EXPORT_JOBS_WORKER_ENABLED || '1'
  });

  const app = await NestFactory.create(AppModule, { cors: true });
  const adminRoot = join(__dirname, '..', 'public/admin');
  const adminIndex = readFileSync(join(adminRoot, 'index.html'), 'utf8');
  const siteRoot = join(__dirname, '..', 'public/site');
  const siteIndex = readFileSync(join(siteRoot, 'index.html'), 'utf8');
  const expressApp = app.getHttpAdapter().getInstance();
  const metrics = app.get(HttpMetricsService);

  expressApp.get('/', (_req: Request, res: Response) => {
    res.type('html').send(siteIndex);
  });
  expressApp.get('/admin', (_req: Request, res: Response) => {
    res.type('html').send(adminIndex);
  });
  app.use(createRequestContextMiddleware(metrics));
  app.use('/site', express.static(siteRoot, { index: 'index.html' }));
  app.use('/admin', express.static(adminRoot, { index: 'index.html' }));
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
      exceptionFactory: (errors) => {
        const details = toValidationDetails(errors);
        const message = details[0]?.messages[0] || 'Validation failed';
        return new BadRequestException({
          code: 'validation_failed',
          message,
          details
        });
      }
    })
  );
  app.useGlobalFilters(new HttpErrorFilter());

  const swaggerConfig = new DocumentBuilder()
    .setTitle('ShiTi API')
    .setDescription('ShiTi backend OpenAPI document')
    .setVersion('0.1.0')
    .addBearerAuth()
    .build();
  const swaggerDocument = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup('docs', app, swaggerDocument, {
    jsonDocumentUrl: 'docs/openapi.json'
  });

  installProcessLifecycleLogging(app, port);
  await app.listen(port);

  logLifecycle('info', 'bootstrap_ready', {
    port
  });
}

bootstrap().catch((err) => {
  logLifecycle('error', 'bootstrap_failed', normalizeError(err));
  process.exit(1);
});

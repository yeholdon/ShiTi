import 'reflect-metadata';
import { BadRequestException, ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import express from 'express';
import type { Request, Response } from 'express';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { AppModule } from './app.module';
import { HttpErrorFilter } from './http-exception.filter';
import { HttpMetricsService } from './metrics/http-metrics.service';
import { createRequestContextMiddleware } from './request-context.middleware';
import './tenant.types-shim';
import { installContextLifecycleLogging, logLifecycle } from '../../src/bootstrap/lifecycle';

function toValidationDetails(errors: any[], parentPath = ''): Array<{ field: string; messages: string[] }> {
  return errors.flatMap((error) => {
    const field = parentPath ? `${parentPath}.${error.property}` : error.property;
    const messages = error.constraints ? Object.values(error.constraints).map((item) => String(item)) : [];
    const children = Array.isArray(error.children) ? toValidationDetails(error.children, field) : [];
    const current = messages.length > 0 ? [{ field, messages }] : [];
    return [...current, ...children];
  });
}

export async function bootstrapApi() {
  const port = Number(process.env.PORT || 3000);
  const projectRoot = process.cwd();
  logLifecycle('info', 'bootstrap_start', {
    appKind: 'api',
    port,
    nodeEnv: process.env.NODE_ENV || 'development',
    workerEnabled: process.env.EXPORT_JOBS_WORKER_ENABLED || '1'
  });

  const app = await NestFactory.create(AppModule, { cors: true });
  const adminRoot = join(projectRoot, 'public', 'admin');
  const adminIndex = readFileSync(join(adminRoot, 'index.html'), 'utf8');
  const siteRoot = join(projectRoot, 'public', 'site');
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

  installContextLifecycleLogging(app, { appKind: 'api', port });
  await app.listen(port);

  logLifecycle('info', 'bootstrap_ready', {
    appKind: 'api',
    port
  });
}

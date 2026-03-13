import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { WorkerAppModule } from './app.module';
import { installContextLifecycleLogging, logLifecycle } from '../../src/bootstrap/lifecycle';

export async function bootstrapWorker() {
  logLifecycle('info', 'bootstrap_start', {
    appKind: 'worker',
    nodeEnv: process.env.NODE_ENV || 'development',
    workerEnabled: process.env.EXPORT_JOBS_WORKER_ENABLED || '1'
  });

  const app = await NestFactory.createApplicationContext(WorkerAppModule, {
    logger: ['log', 'warn', 'error']
  });

  installContextLifecycleLogging(app, { appKind: 'worker' });

  logLifecycle('info', 'bootstrap_ready', {
    appKind: 'worker'
  });
}

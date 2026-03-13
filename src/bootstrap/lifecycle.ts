import type { INestApplicationContext } from '@nestjs/common';

export function logLifecycle(level: 'info' | 'warn' | 'error', type: string, details: Record<string, unknown> = {}) {
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

export function installContextLifecycleLogging(
  app: INestApplicationContext,
  details: { appKind: 'api' | 'worker'; port?: number }
) {
  const state = { closing: false };

  const closeApp = async (reason: string, code: number) => {
    if (state.closing) return;
    state.closing = true;

    logLifecycle(code === 0 ? 'warn' : 'error', 'process_shutdown', {
      appKind: details.appKind,
      port: details.port,
      reason,
      code
    });

    try {
      await app.close();
    } catch (error) {
      logLifecycle('error', 'app_close_failed', {
        appKind: details.appKind,
        port: details.port,
        ...normalizeError(error)
      });
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
      appKind: details.appKind,
      port: details.port,
      ...normalizeError(error)
    });
    void closeApp('uncaughtException', 1);
  });

  process.once('unhandledRejection', (reason) => {
    logLifecycle('error', 'unhandled_rejection', {
      appKind: details.appKind,
      port: details.port,
      ...normalizeError(reason)
    });
    void closeApp('unhandledRejection', 1);
  });
}

export function logBootstrapFailure(appKind: 'api' | 'worker', error: unknown, port?: number) {
  logLifecycle('error', 'bootstrap_failed', {
    appKind,
    port,
    ...normalizeError(error)
  });
}

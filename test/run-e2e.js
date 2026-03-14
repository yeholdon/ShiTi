const { spawn } = require('child_process');
const path = require('path');
const { Queue } = require('bullmq');

const jestBin = path.join(__dirname, '..', 'node_modules', '.bin', process.platform === 'win32' ? 'jest.cmd' : 'jest');

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function sanitizeNodeOptions(env) {
  if (!env.NODE_OPTIONS) return env;
  const tokens = env.NODE_OPTIONS.match(/"[^"]*"|'[^']*'|\\S+/g) || [];
  const filtered = tokens.filter((token) => {
    if (token === '--localstorage-file' || token === '--localstorage-file=') return false;
    if (token.startsWith('--localstorage-file=')) {
      return token.length > '--localstorage-file='.length;
    }
    return true;
  });
  const next = { ...env };
  if (filtered.length === 0) delete next.NODE_OPTIONS;
  else next.NODE_OPTIONS = filtered.join(' ');
  return next;
}

function withDefaultTestEnv(env) {
  return {
    DATABASE_URL: 'postgresql://qb_app:qb_app@localhost:5432/qb?schema=public',
    RLS_ADMIN_DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/qb?schema=public',
    REDIS_URL: 'redis://localhost:6379',
    MINIO_ENDPOINT: 'localhost',
    MINIO_PORT: '9000',
    MINIO_USE_SSL: 'false',
    MINIO_ACCESS_KEY: 'minioadmin',
    MINIO_SECRET_KEY: 'minioadmin',
    MINIO_BUCKET: 'questionbank',
    JWT_SECRET: 'dev-secret-change-me',
    ...env
  };
}

function parseRedisUrl(urlString) {
  const url = new URL(urlString);
  return {
    host: url.hostname,
    port: url.port ? Number(url.port) : 6379,
    password: url.password || undefined,
    db: url.pathname && url.pathname !== '/' ? Number(url.pathname.slice(1)) : undefined,
  };
}

async function waitForServer(url, timeoutMs = 60000) {
  const http = await import('node:http');
  const start = Date.now();
  // eslint-disable-next-line no-constant-condition
  while (true) {
    try {
      await new Promise((resolve, reject) => {
        const req = http.default.get(url, (res) => {
          res.resume();
          resolve(res.statusCode);
        });
        req.on('error', reject);
        req.setTimeout(2000, () => req.destroy(new Error('timeout')));
      });
      return;
    } catch (e) {
      if (Date.now() - start > timeoutMs) {
        throw new Error(`E2E server not ready: ${url} (${e && e.message ? e.message : e})`);
      }
      await sleep(500);
    }
  }
}

async function main() {
  const port = Number(process.env.E2E_PORT || 3100 + Math.floor(Math.random() * 1000));
  const baseUrl = `http://localhost:${port}`;

  const cwd = path.join(__dirname, '..');
  const baseEnv = withDefaultTestEnv(sanitizeNodeOptions({ ...process.env }));

  const exportQueue = new Queue('export_jobs', {
    connection: parseRedisUrl(baseEnv.REDIS_URL),
  });
  await exportQueue.resume().catch(() => undefined);
  await exportQueue.close().catch(() => undefined);

  // Ensure tenant isolation policies exist in the test database.
  // (RLS is a DB concern; without it, isolation relies purely on app code and is easier to regress.)
  await new Promise((resolve, reject) => {
    const proc = spawn(process.execPath, ['-r', 'ts-node/register', 'prisma/apply-rls.ts'], {
      cwd,
      env: { ...baseEnv },
      stdio: 'inherit'
    });
    proc.on('close', (code) => {
      if (code === 0) resolve();
      else reject(new Error(`apply-rls exited with code ${code}`));
    });
  });

  // Seed system defaults (subjects/textbooks) required by e2e flows.
  await new Promise((resolve, reject) => {
    const proc = spawn(process.execPath, ['-r', 'ts-node/register', 'prisma/seed.ts'], {
      cwd,
      env: { ...baseEnv },
      stdio: 'inherit'
    });
    proc.on('close', (code) => {
      if (code === 0) resolve();
      else reject(new Error(`seed exited with code ${code}`));
    });
  });

  const serverProc = spawn(process.execPath, ['-r', 'ts-node/register', 'apps/api/main.ts'], {
    cwd,
    env: {
      ...baseEnv,
      NODE_ENV: 'test',
      PORT: String(port),
      EXPORT_JOBS_WORKER_ENABLED: '0'
    },
    stdio: ['ignore', 'pipe', 'pipe']
  });

  const workerProc = spawn(process.execPath, ['-r', 'ts-node/register', 'apps/worker/main.ts'], {
    cwd,
    env: {
      ...baseEnv,
      NODE_ENV: 'test',
      EXPORT_JOBS_WORKER_ENABLED: process.env.EXPORT_JOBS_WORKER_ENABLED || '1'
    },
    stdio: ['ignore', 'pipe', 'pipe']
  });

  const forward = (stream, prefix) => {
    stream.on('data', (d) => process.stdout.write(prefix + d.toString()));
  };

  forward(serverProc.stdout, '[api] ');
  forward(serverProc.stderr, '[api] ');
  forward(workerProc.stdout, '[worker] ');
  forward(workerProc.stderr, '[worker] ');

  try {
    await waitForServer(baseUrl + '/health');
    await sleep(1500);

    const jestProc = spawn(jestBin, ['--config', 'test/jest-e2e.json', '--runInBand'], {
      cwd: path.join(__dirname, '..'),
      env: {
        ...baseEnv,
        NODE_ENV: 'test',
        E2E_BASE_URL: baseUrl
      },
      stdio: 'inherit'
    });

    const code = await new Promise((resolve) => jestProc.on('close', resolve));
    process.exitCode = code;
  } finally {
    serverProc.kill('SIGTERM');
    workerProc.kill('SIGTERM');
  }
}

main().catch((e) => {
  // eslint-disable-next-line no-console
  console.error(e);
  process.exit(1);
});

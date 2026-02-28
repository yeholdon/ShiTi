const { spawn } = require('child_process');
const path = require('path');

const jestBin = path.join(__dirname, '..', 'node_modules', '.bin', process.platform === 'win32' ? 'jest.cmd' : 'jest');

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
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

  // Ensure tenant isolation policies exist in the test database.
  // (RLS is a DB concern; without it, isolation relies purely on app code and is easier to regress.)
  await new Promise((resolve, reject) => {
    const proc = spawn(process.execPath, ['-r', 'ts-node/register', 'prisma/apply-rls.ts'], {
      cwd,
      env: { ...process.env },
      stdio: 'inherit'
    });
    proc.on('close', (code) => {
      if (code === 0) resolve();
      else reject(new Error(`apply-rls exited with code ${code}`));
    });
  });

  const serverProc = spawn(process.execPath, ['-r', 'ts-node/register', 'src/main.ts'], {
    cwd,
    env: {
      ...process.env,
      PORT: String(port),
      // E2E expects export jobs to complete; enable worker in the spawned API process.
      EXPORT_JOBS_WORKER_ENABLED: process.env.EXPORT_JOBS_WORKER_ENABLED || '1'
    },
    stdio: ['ignore', 'pipe', 'pipe']
  });

  const forward = (stream, prefix) => {
    stream.on('data', (d) => process.stdout.write(prefix + d.toString()));
  };

  forward(serverProc.stdout, '[api] ');
  forward(serverProc.stderr, '[api] ');

  try {
    await waitForServer(baseUrl + '/');

    const jestProc = spawn(jestBin, ['--config', 'test/jest-e2e.json'], {
      cwd: path.join(__dirname, '..'),
      env: {
        ...process.env,
        E2E_BASE_URL: baseUrl
      },
      stdio: 'inherit'
    });

    const code = await new Promise((resolve) => jestProc.on('close', resolve));
    process.exitCode = code;
  } finally {
    serverProc.kill('SIGTERM');
  }
}

main().catch((e) => {
  // eslint-disable-next-line no-console
  console.error(e);
  process.exit(1);
});

const http = require('http');

const url = process.env.E2E_BASE_URL || 'http://localhost:3000';
const path = process.env.E2E_HEALTH_PATH || '/';
const timeoutMs = Number(process.env.E2E_WAIT_TIMEOUT_MS || 60000);
const intervalMs = Number(process.env.E2E_WAIT_INTERVAL_MS || 500);

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function ping() {
  return new Promise((resolve, reject) => {
    const req = http.get(url + path, (res) => {
      // Any HTTP response means the server is up.
      res.resume();
      resolve(res.statusCode);
    });
    req.on('error', reject);
    req.setTimeout(2000, () => {
      req.destroy(new Error('timeout'));
    });
  });
}

(async () => {
  const start = Date.now();
  // eslint-disable-next-line no-constant-condition
  while (true) {
    try {
      await ping();
      process.exit(0);
    } catch (e) {
      if (Date.now() - start > timeoutMs) {
        // eslint-disable-next-line no-console
        console.error('E2E server not ready:', url + path);
        // eslint-disable-next-line no-console
        console.error(String(e && e.message ? e.message : e));
        process.exit(1);
      }
      await sleep(intervalMs);
    }
  }
})().catch((e) => {
  // eslint-disable-next-line no-console
  console.error(e);
  process.exit(1);
});

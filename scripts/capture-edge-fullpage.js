#!/usr/bin/env node

const fs = require('node:fs/promises');
const path = require('node:path');

async function main() {
  const [debugBaseUrl, pageUrl, outputPath, expectedHash = '', postLoadDelayMs = '2500'] =
    process.argv.slice(2);
  if (!debugBaseUrl || !pageUrl || !outputPath) {
    throw new Error(
      'usage: capture-edge-fullpage.js <debug-base-url> <page-url> <output-path> [expected-hash] [post-load-delay-ms]',
    );
  }

  const target = await createTarget(debugBaseUrl, pageUrl);
  const client = await connectToTarget(target.webSocketDebuggerUrl);

  try {
    await client.send('Page.enable');
    await client.send('Runtime.enable');
    await client.send('Page.bringToFront');

    await waitForPageReady(client, expectedHash, Number(postLoadDelayMs));

    const { contentSize } = await client.send('Page.getLayoutMetrics');
    const screenshot = await client.send('Page.captureScreenshot', {
      format: 'png',
      fromSurface: true,
      captureBeyondViewport: true,
      clip: {
        x: 0,
        y: 0,
        width: Math.max(1, Math.ceil(contentSize.width)),
        height: Math.max(1, Math.ceil(contentSize.height)),
        scale: 1,
      },
    });

    await fs.mkdir(path.dirname(outputPath), { recursive: true });
    await fs.writeFile(outputPath, Buffer.from(screenshot.data, 'base64'));
    await closeTarget(debugBaseUrl, target.id);
  } finally {
    client.close();
  }
}

async function createTarget(debugBaseUrl, pageUrl) {
  const encodedUrl = encodeURIComponent(pageUrl);
  const endpoints = [
    `${debugBaseUrl}/json/new?${encodedUrl}`,
    `${debugBaseUrl}/json/new?${pageUrl}`,
  ];

  let lastError;
  for (const endpoint of endpoints) {
    for (const method of ['PUT', 'GET']) {
      try {
        const response = await fetch(endpoint, { method });
        if (!response.ok) {
          throw new Error(`${method} ${endpoint} -> ${response.status}`);
        }
        return await response.json();
      } catch (error) {
        lastError = error;
      }
    }
  }

  throw lastError ?? new Error('failed to create Edge debugging target');
}

async function closeTarget(debugBaseUrl, targetId) {
  const endpoint = `${debugBaseUrl}/json/close/${targetId}`;
  for (const method of ['GET', 'PUT']) {
    try {
      const response = await fetch(endpoint, { method });
      if (response.ok) {
        return;
      }
    } catch (_) {
      // Ignore and try the next close strategy.
    }
  }
}

async function waitForPageReady(client, expectedHash, postLoadDelayMs) {
  const maxAttempts = 40;
  for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
    const { result } = await client.send('Runtime.evaluate', {
      expression: `(() => ({
        readyState: document.readyState,
        href: location.href,
        hash: location.hash,
        bodyHeight: Math.max(
          document.body ? document.body.scrollHeight : 0,
          document.documentElement ? document.documentElement.scrollHeight : 0
        ),
        hasCanvas: !!document.querySelector('canvas'),
        hasFlutterView: !!document.querySelector('flt-glass-pane, flutter-view, flt-semantics-host')
      }))()`,
      returnByValue: true,
    });

    const value = result.value || {};
    const hashOk = !expectedHash || value.hash === `#${expectedHash}`;
    const ready =
      value.readyState === 'complete' &&
      hashOk &&
      Number(value.bodyHeight || 0) > 0 &&
      (value.hasCanvas || value.hasFlutterView);

    if (ready) {
      await waitForFonts(client);
      if (postLoadDelayMs > 0) {
        await delay(postLoadDelayMs);
      }
      return;
    }

    await delay(500);
  }

  throw new Error('page did not reach ready state in time');
}

async function waitForFonts(client) {
  try {
    await client.send('Runtime.evaluate', {
      awaitPromise: true,
      expression: `document.fonts ? document.fonts.ready.then(() => true) : Promise.resolve(true)`,
      returnByValue: true,
    });
  } catch (_) {
    // Fonts API is optional for readiness.
  }
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function connectToTarget(wsUrl) {
  return new Promise((resolve, reject) => {
    const socket = new WebSocket(wsUrl);
    const pending = new Map();
    let nextId = 0;

    socket.addEventListener('open', () => {
      resolve({
        send(method, params = {}) {
          return new Promise((resolveSend, rejectSend) => {
            const id = ++nextId;
            pending.set(id, { resolve: resolveSend, reject: rejectSend });
            socket.send(JSON.stringify({ id, method, params }));
          });
        },
        close() {
          socket.close();
        },
      });
    });

    socket.addEventListener('message', (event) => {
      const payload = JSON.parse(event.data);
      if (!payload.id) {
        return;
      }
      const entry = pending.get(payload.id);
      if (!entry) {
        return;
      }
      pending.delete(payload.id);
      if (payload.error) {
        entry.reject(new Error(payload.error.message || 'CDP call failed'));
        return;
      }
      entry.resolve(payload.result || {});
    });

    socket.addEventListener('error', (error) => {
      reject(error);
    });

    socket.addEventListener('close', () => {
      for (const entry of pending.values()) {
        entry.reject(new Error('WebSocket closed before response'));
      }
      pending.clear();
    });
  });
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});

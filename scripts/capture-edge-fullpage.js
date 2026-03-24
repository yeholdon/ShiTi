#!/usr/bin/env node

const fs = require('node:fs/promises');
const path = require('node:path');

async function main() {
  const [
    debugBaseUrl,
    pageUrl,
    outputPath,
    expectedHash = '',
    postLoadDelayMs = '2500',
  ] = process.argv.slice(2);
  if (!debugBaseUrl || !pageUrl || !outputPath) {
    throw new Error(
      'usage: capture-edge-fullpage.js <debug-base-url> <page-url> <output-path> [expected-hash] [post-load-delay-ms]',
    );
  }

  const target = await findTarget(debugBaseUrl, pageUrl, expectedHash);
  const client = await connectToTarget(target.webSocketDebuggerUrl);

  try {
    await client.send('Page.enable');
    await client.send('Runtime.enable');
    await client.send('Page.bringToFront');
    await navigateToPage(client, pageUrl);

    await waitForPageReady(client, expectedHash, Number(postLoadDelayMs));
    await applyCaptureViewport(client);

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
  } finally {
    client.close();
  }
}

async function navigateToPage(client, pageUrl) {
  await client.send('Page.navigate', { url: pageUrl });
}

async function findTarget(debugBaseUrl, pageUrl, expectedHash) {
  const maxAttempts = 60;
  for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
    const response = await fetch(`${debugBaseUrl}/json/list`);
    if (!response.ok) {
      throw new Error(`GET ${debugBaseUrl}/json/list -> ${response.status}`);
    }
    const targets = await response.json();
    const pageTargets = targets.filter((candidate) => candidate.type === 'page');
    const exactTarget = pageTargets.find((candidate) => {
      const candidateUrl = String(candidate.url || '');
      const candidateTitle = String(candidate.title || '');
      if (candidateUrl === pageUrl) {
        return true;
      }
      if (expectedHash && candidateUrl.includes(`#${expectedHash}`)) {
        return true;
      }
      if (candidateUrl.includes(pageUrl)) {
        return true;
      }
      if (candidateTitle === 'shiti_flutter_app' && candidateUrl.includes('127.0.0.1')) {
        return true;
      }
      return false;
    });
    if (exactTarget) {
      return exactTarget;
    }

    if (pageTargets.length === 1) {
      return pageTargets[0];
    }

    const localhostTarget = pageTargets.find((candidate) =>
      String(candidate.url || '').includes('127.0.0.1'),
    );
    if (localhostTarget) {
      return localhostTarget;
    }

    const target = targets.find((candidate) => {
      if (candidate.type !== 'page') {
        return false;
      }
      if (candidate.url === pageUrl) {
        return true;
      }
      if (expectedHash && String(candidate.url || '').includes(`#${expectedHash}`)) {
        return true;
      }
      return String(candidate.url || '').includes(pageUrl);
    });
    if (target) {
      return target;
    }
    await delay(250);
  }

  throw new Error('failed to find matching Edge page target');
}

async function waitForPageReady(client, expectedHash, postLoadDelayMs) {
  const maxAttempts = 80;
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
        bodyChildCount: document.body ? document.body.children.length : 0,
        canvasCount: document.querySelectorAll('canvas').length,
        hasCanvas: !!document.querySelector('canvas'),
        hasFlutterView: !!document.querySelector('flt-glass-pane, flutter-view, flt-semantics-host')
      }))()`,
      returnByValue: true,
    });

    const value = result.value || {};
    const hashOk = !expectedHash || value.hash === `#${expectedHash}`;
    const flutterReady =
      value.hasFlutterView ||
      Number(value.canvasCount || 0) > 0 ||
      Number(value.bodyChildCount || 0) > 3;
    const ready =
      value.readyState === 'complete' &&
      hashOk &&
      Number(value.bodyHeight || 0) > 0 &&
      flutterReady;

    if (ready) {
      await waitForFonts(client);
      if (postLoadDelayMs > 0) {
        await delay(postLoadDelayMs);
      }
      return;
    }

    await delay(500);
  }

  if (postLoadDelayMs > 0) {
    await delay(postLoadDelayMs);
  }
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

async function applyCaptureViewport(client) {
  try {
    await client.send('Emulation.setDeviceMetricsOverride', {
      width: 1440,
      height: 2600,
      deviceScaleFactor: 1,
      mobile: false,
      screenWidth: 1440,
      screenHeight: 2600,
      positionX: 0,
      positionY: 0,
      dontSetVisibleSize: false,
    });
    await delay(500);
  } catch (_) {
    // Some targets may reject metrics overrides; fall back to the native viewport.
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

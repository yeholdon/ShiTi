const els = {
  liveCard: document.querySelector('#liveCard'),
  liveStatus: document.querySelector('#liveStatus'),
  liveHint: document.querySelector('#liveHint'),
  readyCard: document.querySelector('#readyCard'),
  readyStatusPage: document.querySelector('#readyStatusPage'),
  readyHint: document.querySelector('#readyHint'),
  metricsCard: document.querySelector('#metricsCard'),
  metricsStatus: document.querySelector('#metricsStatus'),
  metricsHint: document.querySelector('#metricsHint'),
  depDatabase: document.querySelector('#depDatabase .dependency-state'),
  depRedis: document.querySelector('#depRedis .dependency-state'),
  depMinio: document.querySelector('#depMinio .dependency-state'),
  uptimeValue: document.querySelector('#uptimeValue'),
  requestCountValue: document.querySelector('#requestCountValue'),
  lastRefreshValue: document.querySelector('#lastRefreshValue'),
  systemSummaryValue: document.querySelector('#systemSummaryValue'),
  requestTrend: document.querySelector('#requestTrend'),
  requestTrendHint: document.querySelector('#requestTrendHint'),
  uptimeTrend: document.querySelector('#uptimeTrend'),
  uptimeTrendHint: document.querySelector('#uptimeTrendHint'),
  snapshotList: document.querySelector('#snapshotList'),
  refreshNowButton: document.querySelector('#refreshNowButton'),
  metricsPreview: document.querySelector('#metricsPreview')
};

const history = [];
const maxHistory = 8;

function setTone(card, tone) {
  card.classList.remove('tone-neutral', 'tone-ok', 'tone-warn', 'tone-error');
  card.classList.add(tone);
}

function setDependencyState(el, value) {
  const normalized = value === true || value === 'ok' ? 'ok' : value === false ? 'degraded' : String(value || 'unknown');
  el.textContent = normalized;
  el.parentElement.dataset.state = normalized;
}

function formatNow() {
  return new Date().toLocaleString('zh-CN');
}

function formatDuration(seconds) {
  if (!Number.isFinite(seconds)) return '-';
  if (seconds < 60) return `${seconds.toFixed(0)} 秒`;
  if (seconds < 3600) return `${(seconds / 60).toFixed(1)} 分钟`;
  return `${(seconds / 3600).toFixed(1)} 小时`;
}

function sumMetricLines(metricsText, metricName) {
  return metricsText
    .split('\n')
    .filter((line) => line.startsWith(`${metricName}{`) || line.startsWith(`${metricName} `))
    .reduce((total, line) => {
      const value = Number(line.trim().split(' ').pop());
      return Number.isFinite(value) ? total + value : total;
    }, 0);
}

function sparkline(values, svg) {
  if (!svg) return;
  svg.innerHTML = '';
  if (!values.length) return;
  const width = 220;
  const height = 72;
  const min = Math.min(...values);
  const max = Math.max(...values);
  const range = max - min || 1;
  const points = values
    .map((value, index) => {
      const x = (index / Math.max(values.length - 1, 1)) * width;
      const y = height - ((value - min) / range) * (height - 8) - 4;
      return `${x.toFixed(1)},${y.toFixed(1)}`;
    })
    .join(' ');
  const polyline = document.createElementNS('http://www.w3.org/2000/svg', 'polyline');
  polyline.setAttribute('points', points);
  polyline.setAttribute('fill', 'none');
  polyline.setAttribute('stroke', '#0f766e');
  polyline.setAttribute('stroke-width', '3');
  polyline.setAttribute('stroke-linecap', 'round');
  polyline.setAttribute('stroke-linejoin', 'round');
  svg.append(polyline);
}

function renderSnapshots() {
  if (!els.snapshotList) return;
  if (!history.length) {
    els.snapshotList.innerHTML = `
      <article class="snapshot-row">
        <strong>等待第一次刷新</strong>
        <p>状态样本将显示在这里。</p>
      </article>
    `;
    return;
  }

  els.snapshotList.innerHTML = history
    .slice()
    .reverse()
    .map(
      (item) => `
        <article class="snapshot-row">
          <strong>${item.time}</strong>
          <p>${item.summary}</p>
        </article>
      `
    )
    .join('');
}

function pushSnapshot(sample) {
  history.push(sample);
  if (history.length > maxHistory) {
    history.shift();
  }
  sparkline(
    history.map((item) => item.requestCount),
    els.requestTrend
  );
  sparkline(
    history.map((item) => item.uptimeSeconds),
    els.uptimeTrend
  );
  els.requestTrendHint.textContent = history.length > 1 ? `最近 ${history.length} 次采样中的累计请求量变化` : '至少两次采样后展示变化';
  els.uptimeTrendHint.textContent = history.length > 1 ? `最近 ${history.length} 次采样中的进程运行时长变化` : '至少两次采样后展示变化';
  renderSnapshots();
}

async function fetchJson(path) {
  const res = await fetch(path);
  if (!res.ok) throw new Error(`${path} -> ${res.status}`);
  return res.json();
}

async function fetchText(path) {
  const res = await fetch(path);
  if (!res.ok) throw new Error(`${path} -> ${res.status}`);
  return res.text();
}

async function refreshStatus() {
  let uptimeSeconds = NaN;
  let totalRequests = NaN;

  try {
    const live = await fetchJson('/health');
    els.liveStatus.textContent = live.status || 'ok';
    els.liveHint.textContent = 'liveness 已通过';
    setTone(els.liveCard, 'tone-ok');
  } catch (error) {
    els.liveStatus.textContent = 'error';
    els.liveHint.textContent = String(error.message || error);
    setTone(els.liveCard, 'tone-error');
  }

  try {
    const ready = await fetchJson('/health/ready');
    els.readyStatusPage.textContent = ready.status || 'ready';
    const checks = ready.checks
      ? Object.entries(ready.checks)
          .map(([key, value]) => `${key}:${value}`)
          .join(' / ')
      : '依赖可用';
    els.readyHint.textContent = checks;
    setTone(els.readyCard, ready.status === 'ready' ? 'tone-ok' : 'tone-warn');
    setDependencyState(els.depDatabase, ready.checks?.database);
    setDependencyState(els.depRedis, ready.checks?.redis);
    setDependencyState(els.depMinio, ready.checks?.minio);
  } catch (error) {
    els.readyStatusPage.textContent = 'not_ready';
    els.readyHint.textContent = String(error.message || error);
    setTone(els.readyCard, 'tone-error');
    setDependencyState(els.depDatabase, 'error');
    setDependencyState(els.depRedis, 'error');
    setDependencyState(els.depMinio, 'error');
  }

  try {
    const metrics = await fetchText('/metrics');
    els.metricsStatus.textContent = 'ok';
    els.metricsHint.textContent = 'metrics 已抓取';
    setTone(els.metricsCard, 'tone-ok');
    els.metricsPreview.textContent = metrics.split('\n').slice(0, 18).join('\n');

    const uptimeMatch = metrics.match(/process_uptime_seconds\s+([0-9.]+)/);
    uptimeSeconds = uptimeMatch ? Number(uptimeMatch[1]) : NaN;
    totalRequests = sumMetricLines(metrics, 'http_requests_total');

    els.uptimeValue.textContent = formatDuration(uptimeSeconds);
    els.requestCountValue.textContent = Number.isFinite(totalRequests) ? String(totalRequests) : '-';
  } catch (error) {
    els.metricsStatus.textContent = 'error';
    els.metricsHint.textContent = String(error.message || error);
    setTone(els.metricsCard, 'tone-error');
    els.metricsPreview.textContent = 'metrics 拉取失败';
    els.uptimeValue.textContent = '-';
    els.requestCountValue.textContent = '-';
  }

  const hasHardError = [els.liveStatus.textContent, els.metricsStatus.textContent].includes('error');
  if (hasHardError) {
    els.systemSummaryValue.textContent = '系统存在严重异常，先检查 API 进程和观测链路。';
  } else if (els.readyStatusPage.textContent !== 'ready') {
    els.systemSummaryValue.textContent = 'API 存活，但依赖尚未完全就绪。';
  } else {
    els.systemSummaryValue.textContent = '系统状态稳定，可以进入后台继续操作。';
  }

  const refreshTime = formatNow();
  els.lastRefreshValue.textContent = refreshTime;
  pushSnapshot({
    time: refreshTime,
    requestCount: Number.isFinite(totalRequests) ? totalRequests : 0,
    uptimeSeconds: Number.isFinite(uptimeSeconds) ? uptimeSeconds : 0,
    summary: `${els.liveStatus.textContent} / ${els.readyStatusPage.textContent} / ${els.metricsStatus.textContent}`
  });
}

void refreshStatus();
window.setInterval(refreshStatus, 15000);
els.refreshNowButton?.addEventListener('click', () => {
  void refreshStatus();
});

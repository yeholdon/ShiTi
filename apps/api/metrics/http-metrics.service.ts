import { Injectable } from '@nestjs/common';

type StatusBucket = {
  count: number;
  durationMsSum: number;
};

@Injectable()
export class HttpMetricsService {
  private readonly startedAt = Date.now();
  private totalRequests = 0;
  private totalDurationMs = 0;
  private readonly statusBuckets = new Map<string, StatusBucket>();
  private readonly methodStatusBuckets = new Map<string, StatusBucket>();

  recordRequest(method: string, statusCode: number, durationMs: number) {
    this.totalRequests += 1;
    this.totalDurationMs += durationMs;

    const statusKey = String(statusCode);
    const methodStatusKey = `${method.toUpperCase()} ${statusKey}`;
    this.incrementBucket(this.statusBuckets, statusKey, durationMs);
    this.incrementBucket(this.methodStatusBuckets, methodStatusKey, durationMs);
  }

  renderPrometheus() {
    const lines = [
      '# HELP shiti_process_uptime_seconds API process uptime in seconds',
      '# TYPE shiti_process_uptime_seconds gauge',
      `shiti_process_uptime_seconds ${this.formatValue((Date.now() - this.startedAt) / 1000)}`,
      '# HELP shiti_http_requests_total Total number of HTTP requests observed',
      '# TYPE shiti_http_requests_total counter',
      `shiti_http_requests_total ${this.totalRequests}`,
      '# HELP shiti_http_request_duration_ms_sum Sum of HTTP request durations in milliseconds',
      '# TYPE shiti_http_request_duration_ms_sum counter',
      `shiti_http_request_duration_ms_sum ${this.formatValue(this.totalDurationMs)}`,
      '# HELP shiti_http_request_duration_ms_count Count of timed HTTP requests',
      '# TYPE shiti_http_request_duration_ms_count counter',
      `shiti_http_request_duration_ms_count ${this.totalRequests}`,
      '# HELP shiti_http_requests_by_status_total HTTP requests grouped by status code',
      '# TYPE shiti_http_requests_by_status_total counter'
    ];

    for (const [statusCode, bucket] of [...this.statusBuckets.entries()].sort()) {
      lines.push(`shiti_http_requests_by_status_total{statusCode="${statusCode}"} ${bucket.count}`);
    }

    lines.push(
      '# HELP shiti_http_requests_by_method_status_total HTTP requests grouped by method and status code',
      '# TYPE shiti_http_requests_by_method_status_total counter'
    );

    for (const [key, bucket] of [...this.methodStatusBuckets.entries()].sort()) {
      const [method, statusCode] = key.split(' ');
      lines.push(
        `shiti_http_requests_by_method_status_total{method="${method}",statusCode="${statusCode}"} ${bucket.count}`
      );
    }

    return lines.join('\n') + '\n';
  }

  private incrementBucket(store: Map<string, StatusBucket>, key: string, durationMs: number) {
    const bucket = store.get(key) || { count: 0, durationMsSum: 0 };
    bucket.count += 1;
    bucket.durationMsSum += durationMs;
    store.set(key, bucket);
  }

  private formatValue(value: number) {
    return Number.isInteger(value) ? String(value) : value.toFixed(3);
  }
}

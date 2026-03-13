import { Controller, Get, Header } from '@nestjs/common';
import { HttpMetricsService } from './http-metrics.service';

@Controller('metrics')
export class MetricsController {
  constructor(private readonly metrics: HttpMetricsService) {}

  @Get()
  @Header('Content-Type', 'text/plain; version=0.0.4; charset=utf-8')
  getMetrics() {
    return this.metrics.renderPrometheus();
  }
}

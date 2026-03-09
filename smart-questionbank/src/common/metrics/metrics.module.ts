import { Global, Module } from '@nestjs/common';
import { HttpMetricsService } from './http-metrics.service';
import { MetricsController } from './metrics.controller';

@Global()
@Module({
  controllers: [MetricsController],
  providers: [HttpMetricsService],
  exports: [HttpMetricsService]
})
export class MetricsModule {}

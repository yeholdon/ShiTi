import { bootstrapWorker } from './bootstrap';
import { logBootstrapFailure } from '../../src/bootstrap/lifecycle';

bootstrapWorker().catch((error) => {
  logBootstrapFailure('worker', error);
  process.exit(1);
});

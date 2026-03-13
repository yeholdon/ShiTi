import { bootstrapApi } from './bootstrap';
import { logBootstrapFailure } from '../../src/bootstrap/lifecycle';

bootstrapApi().catch((error) => {
  logBootstrapFailure('api', error, Number(process.env.PORT || 3000));
  process.exit(1);
});

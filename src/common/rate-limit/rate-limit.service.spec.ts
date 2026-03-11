import { RateLimitService } from './rate-limit.service';

describe('RateLimitService', () => {
  afterEach(async () => {
    delete process.env.REDIS_URL;
  });

  it('uses redis count when redis hit succeeds', async () => {
    const service = new RateLimitService();
    jest.spyOn<any, any>(service as any, 'tryRedisHit').mockResolvedValue(5);
    (service as any).redis = {} as any;

    await expect(service.hit('rate:test', 60_000)).resolves.toBe(5);
  });

  it('falls back to in-memory buckets when redis hit is unavailable', async () => {
    const service = new RateLimitService();
    jest.spyOn<any, any>(service as any, 'tryRedisHit').mockResolvedValue(null);
    (service as any).redis = {} as any;

    await expect(service.hit('rate:test', 60_000)).resolves.toBe(1);
    await expect(service.hit('rate:test', 60_000)).resolves.toBe(2);
  });

  it('resets in-memory buckets after the window elapses', async () => {
    const service = new RateLimitService();

    const nowSpy = jest.spyOn(Date, 'now');
    nowSpy.mockReturnValue(1_000);
    await expect(service.hit('rate:test', 500)).resolves.toBe(1);
    await expect(service.hit('rate:test', 500)).resolves.toBe(2);

    nowSpy.mockReturnValue(1_600);
    await expect(service.hit('rate:test', 500)).resolves.toBe(1);

    nowSpy.mockRestore();
  });
});

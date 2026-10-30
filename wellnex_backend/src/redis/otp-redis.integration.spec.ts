import { randomUUID } from "node:crypto";
import { RedisService } from "./redis.service";

// Use only an explicitly supplied disposable Redis instance, never application .env.
const describeRedis = process.env.SECURITY_TEST_REDIS_URL
  ? describe
  : describe.skip;
describeRedis("OTP Redis atomicity", () => {
  let service: RedisService;
  const identities: string[] = [];
  const identity = () => {
    const value = `security-test:${randomUUID()}`;
    identities.push(value);
    return value;
  };
  beforeAll(async () => {
    service = new RedisService({
      get: (key: string) =>
        key === "REDIS_URL"
          ? process.env.SECURITY_TEST_REDIS_URL
          : key === "NODE_ENV"
            ? "production"
            : undefined,
    } as any);
    const client = service.getClient();
    if (client.status !== "ready")
      await new Promise<void>((resolve, reject) => {
        const timer = setTimeout(
          () => reject(new Error("Test Redis did not become ready")),
          5000,
        );
        client.once("ready", () => {
          clearTimeout(timer);
          resolve();
        });
        client.once("error", (error) => {
          clearTimeout(timer);
          reject(error);
        });
      });
  });
  afterAll(async () => {
    if (!service) return;
    const keys = identities.flatMap((id) => [
      `otp:${id}`,
      `otp_attempts:${id}`,
      `otp_rate:${id}`,
      `otp_send_cooldown:${id}`,
    ]);
    if (keys.length && service.getClient().status === "ready")
      await service.getClient().del(...keys);
    await service.onModuleDestroy();
  });
  it("accepts a code exactly once under simultaneous verification", async () => {
    const id = identity();
    await service.setOtp(id, "123456", 5);
    const results = await Promise.all(
      Array.from({ length: 20 }, () => service.consumeOtp(id, "123456")),
    );
    expect(results.filter(Boolean)).toHaveLength(1);
  });
  it("rejects a correct code after five wrong guesses", async () => {
    const id = identity();
    await service.setOtp(id, "123456", 5);
    for (let i = 0; i < 5; i++)
      expect(await service.consumeOtp(id, "000000")).toBe(false);
    expect(await service.consumeOtp(id, "123456")).toBe(false);
  });
  it("admits only one concurrent resend and caps the hourly quota", async () => {
    const id = identity();
    const results = await Promise.all(
      Array.from({ length: 20 }, () => service.checkOtpRateLimit(id)),
    );
    expect(results.filter(Boolean)).toHaveLength(1);
    expect(await service.getClient().ttl(`otp_rate:${id}`)).toBeGreaterThan(0);
    for (let i = 0; i < 4; i++) {
      await service.getClient().del(`otp_send_cooldown:${id}`);
      expect(await service.checkOtpRateLimit(id)).toBe(true);
    }
    await service.getClient().del(`otp_send_cooldown:${id}`);
    expect(await service.checkOtpRateLimit(id)).toBe(false);
  });
});

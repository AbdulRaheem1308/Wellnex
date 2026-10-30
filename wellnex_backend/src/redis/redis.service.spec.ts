import { Test, TestingModule } from "@nestjs/testing";
import { RedisService } from "./redis.service";
import { ConfigService } from "@nestjs/config";

let mockRedisOptions: any;

jest.mock("ioredis", () => {
  const mRedis = jest.fn().mockImplementation((url, options) => {
    if (typeof url === "object") {
      mockRedisOptions = url;
    } else {
      mockRedisOptions = options;
    }
    return {
      on: jest.fn(),
      quit: jest.fn().mockResolvedValue("OK"),
      status: "ready",
      setex: jest.fn().mockResolvedValue("OK"),
      get: jest.fn(),
      del: jest.fn().mockResolvedValue(1),
      incr: jest.fn(),
      eval: jest.fn(),
      expire: jest.fn().mockResolvedValue(1),
      exists: jest.fn(),
      ttl: jest.fn(),
      set: jest.fn().mockResolvedValue("OK"),
    };
  });
  return {
    __esModule: true,
    default: mRedis,
    Redis: mRedis,
  };
});

describe("RedisService", () => {
  let service: RedisService;
  let mockClient: any;
  let mockConfigService: any;

  beforeEach(async () => {
    jest.clearAllMocks();
    jest.useFakeTimers();

    mockConfigService = {
      get: jest.fn((key) => {
        if (key === "NODE_ENV") return "development";
        if (key === "REDIS_URL") return "redis://localhost:6379";
        return null;
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        RedisService,
        {
          provide: ConfigService,
          useValue: mockConfigService,
        },
      ],
    }).compile();

    service = module.get<RedisService>(RedisService);
    mockClient = service.getClient();
    Object.defineProperty(mockClient, "status", {
      value: "ready",
      writable: true,
    });
  });

  afterEach(async () => {
    await service.onModuleDestroy();
    jest.useRealTimers();
  });

  describe("Constructor and Listeners", () => {
    it("should initialize without redisUrl if missing", async () => {
      mockConfigService.get.mockImplementation((k: string) =>
        k === "NODE_ENV" ? "test" : null,
      );
      const mModule = await Test.createTestingModule({
        providers: [
          RedisService,
          { provide: ConfigService, useValue: mockConfigService },
        ],
      }).compile();
      const srv = mModule.get<RedisService>(RedisService);
      expect(srv).toBeDefined();
      await srv.onModuleDestroy();
    });

    it("should handle connect event", () => {
      const connectHandler = mockClient.on.mock.calls.find(
        (c: any) => c[0] === "connect",
      )[1];
      const loggerSpy = jest
        .spyOn((service as any).logger, "log")
        .mockImplementation();
      connectHandler();
      expect(loggerSpy).toHaveBeenCalledWith("🔴 Redis connected");
    });

    it("should handle error event in dev", () => {
      const errorHandler = mockClient.on.mock.calls.find(
        (c: any) => c[0] === "error",
      )[1];
      const loggerSpy = jest
        .spyOn((service as any).logger, "warn")
        .mockImplementation();
      errorHandler(new Error("test error"));
      expect(loggerSpy).toHaveBeenCalledWith("⚠️ Redis error: test error");
    });

    it("should handle error event in production", async () => {
      mockConfigService.get.mockImplementation((k: string) =>
        k === "NODE_ENV" ? "production" : null,
      );
      const pModule = await Test.createTestingModule({
        providers: [
          RedisService,
          { provide: ConfigService, useValue: mockConfigService },
        ],
      }).compile();
      const pService = pModule.get<RedisService>(RedisService);
      const pClient = pService.getClient();
      const errorHandler = (pClient.on as jest.Mock).mock.calls.find(
        (c: any) => c[0] === "error",
      )[1];

      const loggerSpy = jest
        .spyOn((pService as any).logger, "error")
        .mockImplementation();
      errorHandler(new Error("test error"));
      expect(loggerSpy).toHaveBeenCalledWith(
        "CRITICAL: Redis error in PRODUCTION: test error",
      );
      await pService.onModuleDestroy();
    });

    it("should handle retryStrategy in dev", () => {
      const loggerSpy = jest
        .spyOn((service as any).logger, "warn")
        .mockImplementation();
      expect(mockRedisOptions.retryStrategy(1)).toBe(100);
      expect(mockRedisOptions.retryStrategy(4)).toBeNull();
      expect(loggerSpy).toHaveBeenCalledWith(
        "⚠️ Redis connection failed, running without cache",
      );
    });

    it("should handle retryStrategy in prod", async () => {
      mockConfigService.get.mockImplementation((k: string) =>
        k === "NODE_ENV" ? "production" : null,
      );
      const pModule = await Test.createTestingModule({
        providers: [
          RedisService,
          { provide: ConfigService, useValue: mockConfigService },
        ],
      }).compile();
      const pService = pModule.get<RedisService>(RedisService);
      const loggerSpy = jest
        .spyOn((pService as any).logger, "error")
        .mockImplementation();

      expect(mockRedisOptions.retryStrategy(4)).toBeNull();
      expect(loggerSpy).toHaveBeenCalledWith(
        "CRITICAL: Redis connection failing in PRODUCTION! Services degraded.",
      );
      await pService.onModuleDestroy();
    });

    it("should sweep memory store on interval", async () => {
      mockClient.status = "connecting";
      await service.setOtp("sweep@test.com", "123", -1);

      const loggerSpy = jest
        .spyOn((service as any).logger, "debug")
        .mockImplementation();
      jest.advanceTimersByTime(5 * 60 * 1000);

      expect(loggerSpy).toHaveBeenCalledWith(
        "Swept 1 expired items from fallback memory store",
      );
      expect(await service.getOtp("sweep@test.com")).toBeNull();
    });
  });

  describe("onModuleDestroy", () => {
    it("should call quit on redis client and clear interval", async () => {
      await service.onModuleDestroy();
      expect(mockClient.quit).toHaveBeenCalled();
    });
  });

  describe("OTP Management", () => {
    it("should set OTP with expiry", async () => {
      await service.setOtp("test@test.com", "123456", 5);
      expect(mockClient.setex).toHaveBeenCalledWith(
        "otp:test@test.com",
        300,
        "123456",
      );
    });

    it("should fallback to memory store if redis is not connected for setOtp", async () => {
      mockClient.status = "connecting";
      await service.setOtp("mem@test.com", "654321", 5);
      expect(mockClient.setex).not.toHaveBeenCalled();
      const otp = await service.getOtp("mem@test.com");
      expect(otp).toBe("654321");
    });

    it("should get OTP from redis", async () => {
      mockClient.get.mockResolvedValue("123456");
      const otp = await service.getOtp("test@test.com");
      expect(otp).toBe("123456");
      expect(mockClient.get).toHaveBeenCalledWith("otp:test@test.com");
    });

    it("should return null from memory store if expired", async () => {
      mockClient.status = "connecting";
      await service.setOtp("mem@test.com", "654321", -1);
      const otp = await service.getOtp("mem@test.com");
      expect(otp).toBeNull();
    });

    it("should return null from redis if null", async () => {
      mockClient.get.mockResolvedValue(null);
      const otp = await service.getOtp("test@test.com");
      expect(otp).toBeNull();
    });

    it("should delete OTP from redis", async () => {
      await service.deleteOtp("test@test.com");
      expect(mockClient.del).toHaveBeenCalledWith("otp:test@test.com");
    });

    it("should delete OTP from memory store", async () => {
      mockClient.status = "connecting";
      await service.setOtp("mem@test.com", "654321", 5);
      await service.deleteOtp("mem@test.com");
      const otp = await service.getOtp("mem@test.com");
      expect(otp).toBeNull();
    });
  });

  describe("Rate Limiting", () => {
    it("uses one quota for Gmail mailbox aliases", async () => {
      mockClient.eval.mockResolvedValue(1);
      await service.checkOtpRateLimit("U.ser+tag@googlemail.com");
      expect(mockClient.eval).toHaveBeenCalledWith(
        expect.any(String),
        2,
        "otp_rate:user@gmail.com",
        "otp_send_cooldown:user@gmail.com",
      );
    });
    it("uses an atomic shared quota and cooldown", async () => {
      mockClient.eval.mockResolvedValue(1);
      expect(await service.checkOtpRateLimit("test")).toBe(true);
      expect(mockClient.eval).toHaveBeenCalledWith(
        expect.any(String),
        2,
        "otp_rate:test",
        "otp_send_cooldown:test",
      );
    });
    it("rejects when quota or cooldown denies the request", async () => {
      mockClient.eval.mockResolvedValue(0);
      expect(await service.checkOtpRateLimit("test")).toBe(false);
    });
    it("fails closed when Redis is disconnected", async () => {
      mockClient.status = "connecting";
      expect(await service.checkOtpRateLimit("test")).toBe(false);
      expect(mockClient.eval).not.toHaveBeenCalled();
    });
    it("fails closed when Redis errors", async () => {
      mockClient.eval.mockRejectedValue(new Error("unavailable"));
      expect(await service.checkOtpRateLimit("test")).toBe(false);
    });
  });

  describe("atomic OTP consumption", () => {
    it("delegates comparison and deletion to one Redis operation", async () => {
      mockClient.eval.mockResolvedValueOnce(1).mockResolvedValueOnce(0);
      expect(await service.consumeOtp("user", "123456")).toBe(true);
      expect(await service.consumeOtp("user", "123456")).toBe(false);
      expect(mockClient.get).not.toHaveBeenCalled();
      expect(mockClient.eval).toHaveBeenCalledWith(
        expect.any(String),
        2,
        "otp:user",
        "otp_attempts:user",
        "123456",
      );
    });
    it("never accepts verification after a Redis error", async () => {
      mockClient.eval.mockRejectedValueOnce(new Error("unavailable"));
      await expect(service.consumeOtp("user", "123456")).rejects.toThrow(
        "OTP service temporarily unavailable",
      );
    });
    it("caps development-memory guesses and prevents replay", async () => {
      mockClient.status = "end";
      await service.setOtp("user", "123456", 5);
      for (let i = 0; i < 5; i++)
        expect(await service.consumeOtp("user", "wrong")).toBe(false);
      expect(await service.consumeOtp("user", "123456")).toBe(false);
      await service.setOtp("other", "123456", 5);
      expect(await service.consumeOtp("other", "123456")).toBe(true);
      expect(await service.consumeOtp("other", "123456")).toBe(false);
    });
    it("does not fall back to memory for production OTPs", async () => {
      (service as any).isProduction = true;
      mockClient.status = "end";
      await expect(service.setOtp("user", "123456", 5)).rejects.toThrow(
        "OTP service temporarily unavailable",
      );
      await expect(service.consumeOtp("user", "123456")).rejects.toThrow(
        "OTP service temporarily unavailable",
      );
    });
  });

  describe("Ad Cooldown", () => {
    it("should return true if no cooldown", async () => {
      mockClient.exists.mockResolvedValue(0);
      const res = await service.checkAdCooldown("u1");
      expect(res).toBe(true);
    });

    it("should return false if cooldown exists", async () => {
      mockClient.exists.mockResolvedValue(1);
      const res = await service.checkAdCooldown("u1");
      expect(res).toBe(false);
    });

    it("should fail open checkAdCooldown if disconnected", async () => {
      mockClient.status = "connecting";
      const res = await service.checkAdCooldown("u1");
      expect(res).toBe(true);
    });

    it("should set cooldown", async () => {
      await service.setAdCooldown("u1", 5);
      expect(mockClient.setex).toHaveBeenCalledWith("ad_cooldown:u1", 300, "1");
    });

    it("should not set cooldown if disconnected", async () => {
      mockClient.status = "connecting";
      await service.setAdCooldown("u1", 5);
      expect(mockClient.setex).not.toHaveBeenCalled();
    });

    it("should get TTL", async () => {
      mockClient.ttl.mockResolvedValue(100);
      const res = await service.getAdCooldownRemaining("u1");
      expect(res).toBe(100);
    });

    it("should return 0 TTL if disconnected", async () => {
      mockClient.status = "connecting";
      const res = await service.getAdCooldownRemaining("u1");
      expect(res).toBe(0);
    });
  });

  describe("Cache helpers", () => {
    it("should set cache", async () => {
      await service.setCache("k1", { data: 1 }, 10);
      expect(mockClient.setex).toHaveBeenCalledWith("k1", 10, '{"data":1}');
    });

    it("should not set cache if disconnected", async () => {
      mockClient.status = "connecting";
      await service.setCache("k1", { data: 1 }, 10);
      expect(mockClient.setex).not.toHaveBeenCalled();
    });

    it("should get cache", async () => {
      mockClient.get.mockResolvedValue('{"data":1}');
      const res = await service.getCache("k1");
      expect(res).toEqual({ data: 1 });
    });

    it("should return null if cache get yields null", async () => {
      mockClient.get.mockResolvedValue(null);
      const res = await service.getCache("k1");
      expect(res).toBeNull();
    });

    it("should return null if cache disconnected", async () => {
      mockClient.status = "connecting";
      const res = await service.getCache("k1");
      expect(res).toBeNull();
    });

    it("should delete cache", async () => {
      await service.deleteCache("k1");
      expect(mockClient.del).toHaveBeenCalledWith("k1");
    });

    it("should not delete cache if disconnected", async () => {
      mockClient.status = "connecting";
      await service.deleteCache("k1");
      expect(mockClient.del).not.toHaveBeenCalled();
    });

    it("should handle cache get errors gracefully", async () => {
      mockClient.get.mockRejectedValue(new Error("err"));
      const res = await service.getCache("k1");
      expect(res).toBeNull();
    });
  });

  describe("Nonce Check", () => {
    it("should allow new nonce", async () => {
      const res = await service.setNonce("nonce1", 10);
      expect(res).toBe(true);
      expect(mockClient.set).toHaveBeenCalledWith(
        "nonce:nonce1",
        "used",
        "EX",
        10,
        "NX",
      );
    });

    it("should reject existing nonce", async () => {
      mockClient.set.mockResolvedValue(null);
      const res = await service.setNonce("nonce1", 10);
      expect(res).toBe(false);
    });

    it("should use memory store if redis disconnected", async () => {
      mockClient.status = "connecting";
      const res1 = await service.setNonce("m-nonce", 10);
      const res2 = await service.setNonce("m-nonce", 10);
      expect(res1).toBe(true);
      expect(res2).toBe(false);
    });

    it("should use memory store with expiry handling", async () => {
      mockClient.status = "connecting";
      await service.setNonce("m-nonce-exp", -1);
      const res = await service.setNonce("m-nonce-exp", 10);
      expect(res).toBe(true); // Since it was expired, it allows again
    });

    it("should fail secure if redis throws", async () => {
      mockClient.set.mockRejectedValue(new Error("err"));
      const res = await service.setNonce("nonce1", 10);
      expect(res).toBe(false);
    });
  });
});

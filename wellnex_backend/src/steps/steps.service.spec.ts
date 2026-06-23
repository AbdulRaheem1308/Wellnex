import { Test, TestingModule } from "@nestjs/testing";
import { StepsService } from "./steps.service";
import { PrismaService } from "../prisma/prisma.service";
import { ConfigService } from "@nestjs/config";
import { RewardsService } from "../rewards/rewards.service";
import { PostHogService } from "../analytics/posthog.service";
import { RedisService } from "../redis/redis.service";
import { getQueueToken } from "@nestjs/bullmq";
import { BadRequestException } from "@nestjs/common";
import { SyncStepsDto } from "./dto/steps.dto";

describe("StepsService", () => {
  let service: StepsService;
  let queue: any;

  const mockPrisma: any = {
    $transaction: jest.fn(async (cb) => cb(mockPrisma)),
    step: {
      findUnique: jest.fn(),
      upsert: jest.fn(),
      count: jest.fn(),
      createMany: jest.fn(),
      findMany: jest.fn(),
    },
    device: {
      findFirst: jest.fn(),
    },
    user: {
      findUnique: jest.fn(),
    },
    streak: {
      upsert: jest.fn(),
    },
    wallet: {
      upsert: jest.fn(),
    },
    anomaly: {
      create: jest.fn().mockResolvedValue({}),
    },
  };

  const mockConfig = {
    get: jest.fn().mockImplementation((key, defaultVal) => {
      if (key === "CALORIES_PER_STEP") return "0.04";
      if (key === "KM_PER_STEP") return "0.000762";
      return defaultVal;
    }),
  };

  const mockRewardsService = {};
  const mockPostHogService = {};
  const mockRedisService = {
    setNonce: jest.fn(),
  };
  const mockQueue = {
    add: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        StepsService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: ConfigService, useValue: mockConfig },
        { provide: RewardsService, useValue: mockRewardsService },
        { provide: PostHogService, useValue: mockPostHogService },
        { provide: RedisService, useValue: mockRedisService },
        { provide: getQueueToken("steps-processing"), useValue: mockQueue },
      ],
    }).compile();

    service = module.get<StepsService>(StepsService);
    queue = module.get(getQueueToken("steps-processing"));

    jest.clearAllMocks();
  });

  it("should be defined", () => {
    expect(service).toBeDefined();
  });

  describe("syncSteps validation & anti-cheat", () => {
    const userId = "user1";
    const baseDto: SyncStepsDto = {
      deviceIdentifier: "dev123",
      stepCount: 5000,
      date: new Date().toISOString(),
      source: "google_fit",
    };

    it("should throw if no deviceIdentifier", async () => {
      const dto = { ...baseDto, deviceIdentifier: undefined };
      await expect(service.syncSteps(userId, dto as any)).rejects.toThrow(
        BadRequestException,
      );
    });

    it("should throw if device is not bound/active", async () => {
      mockPrisma.device.findFirst.mockResolvedValueOnce(null);
      await expect(service.syncSteps(userId, baseDto)).rejects.toThrow(
        BadRequestException,
      );
    });

    it("should throw on negative steps", async () => {
      mockPrisma.device.findFirst.mockResolvedValueOnce({ id: "d1" });
      const dto = { ...baseDto, stepCount: -10 };
      await expect(service.syncSteps(userId, dto)).rejects.toThrow(
        BadRequestException,
      );
    });

    it("should throw on replay nonce", async () => {
      mockPrisma.device.findFirst.mockResolvedValueOnce({ id: "d1" });
      mockRedisService.setNonce.mockResolvedValueOnce(false); // not unique
      const dto = { ...baseDto, nonce: "nonce123" };
      await expect(service.syncSteps(userId, dto)).rejects.toThrow(
        BadRequestException,
      );
    });

    it("should throw on time drift", async () => {
      mockPrisma.device.findFirst.mockResolvedValueOnce({ id: "d1" });
      const dto = { ...baseDto, timestamp: Date.now() - 600000 }; // 10 minutes ago
      await expect(service.syncSteps(userId, dto)).rejects.toThrow(
        BadRequestException,
      );
    });

    it("should throw on jailbroken device", async () => {
      mockPrisma.device.findFirst.mockResolvedValueOnce({ id: "d1" });
      const dto = { ...baseDto, integrity: { isJailBroken: true } };
      await expect(service.syncSteps(userId, dto as any)).rejects.toThrow(
        BadRequestException,
      );
    });

    it("should throw on mock location", async () => {
      mockPrisma.device.findFirst.mockResolvedValueOnce({ id: "d1" });
      const dto = { ...baseDto, integrity: { isMockLocation: true } };
      await expect(service.syncSteps(userId, dto as any)).rejects.toThrow(
        BadRequestException,
      );
    });

    it("should pass if timestamp, nonce, and clean integrity are provided", async () => {
      mockPrisma.device.findFirst.mockResolvedValueOnce({ id: "d1" });
      mockRedisService.setNonce.mockResolvedValueOnce(true);
      const dto = {
        ...baseDto,
        timestamp: Date.now(),
        nonce: "valid-nonce",
        integrity: {
          isJailBroken: false,
          isMockLocation: false,
          isRealDevice: true,
        },
      };
      mockPrisma.step.findUnique.mockResolvedValueOnce(null);
      mockPrisma.step.upsert.mockResolvedValueOnce({
        stepCount: 5000,
        source: "google_fit",
      });

      await expect(
        service.syncSteps(userId, dto as any),
      ).resolves.toBeDefined();
    });

    it("should throw if steps > MAX_STEPS_PER_DAY", async () => {
      mockPrisma.device.findFirst.mockResolvedValueOnce({ id: "d1" });
      const dto = { ...baseDto, stepCount: 65000 };
      await expect(service.syncSteps(userId, dto)).rejects.toThrow(
        BadRequestException,
      );
    });

    it("should sync steps and queue job successfully", async () => {
      mockPrisma.device.findFirst.mockResolvedValueOnce({ id: "d1" });
      mockPrisma.step.findUnique.mockResolvedValueOnce(null);
      const stepRet = { stepCount: 5000, source: "google_fit" };
      mockPrisma.step.upsert.mockResolvedValueOnce(stepRet);

      const res = await service.syncSteps(userId, baseDto);
      expect(res).toEqual(stepRet);
      expect(queue.add).toHaveBeenCalledWith(
        "process-sync",
        expect.objectContaining({
          userId,
          effectiveStepCount: 5000,
        }),
      );
    });

    it("should log warning and process if steps > SUSPICIOUS_STEPS_THRESHOLD", async () => {
      mockPrisma.device.findFirst.mockResolvedValueOnce({ id: "d1" });
      mockPrisma.step.findUnique.mockResolvedValueOnce(null);
      mockPrisma.step.upsert.mockResolvedValueOnce({});
      const dto = { ...baseDto, stepCount: 35000 };
      await service.syncSteps(userId, dto);
      expect(queue.add).toHaveBeenCalled();
    });

    it("should use the higher step count if existing is higher", async () => {
      mockPrisma.device.findFirst.mockResolvedValueOnce({ id: "d1" });
      mockPrisma.step.findUnique.mockResolvedValueOnce({
        stepCount: 8000,
        source: "apple_health",
      });
      const stepRet = { stepCount: 8000, source: "apple_health" };
      mockPrisma.step.upsert.mockResolvedValueOnce(stepRet);

      await service.syncSteps(userId, baseDto);
      expect(mockPrisma.step.upsert).toHaveBeenCalledWith(
        expect.objectContaining({
          update: expect.objectContaining({
            stepCount: 8000,
            source: "apple_health",
          }),
        }),
      );
    });

    it("should skip nonce check when no nonce provided", async () => {
      mockPrisma.device.findFirst.mockResolvedValueOnce({ id: "d1" });
      mockPrisma.step.findUnique.mockResolvedValueOnce(null);
      mockPrisma.step.upsert.mockResolvedValueOnce({
        stepCount: 5000,
        source: "google_fit",
      });

      // No nonce in dto — should not call setNonce
      const dtoWithoutNonce = { ...baseDto };
      delete (dtoWithoutNonce as any).nonce;
      await service.syncSteps(userId, dtoWithoutNonce);
      expect(mockRedisService.setNonce).not.toHaveBeenCalled();
    });

    it("should skip timestamp check when no timestamp provided", async () => {
      mockPrisma.device.findFirst.mockResolvedValueOnce({ id: "d1" });
      mockPrisma.step.findUnique.mockResolvedValueOnce(null);
      mockPrisma.step.upsert.mockResolvedValueOnce({
        stepCount: 5000,
        source: "google_fit",
      });

      const dtoWithoutTimestamp = { ...baseDto };
      delete (dtoWithoutTimestamp as any).timestamp;
      await expect(
        service.syncSteps(userId, dtoWithoutTimestamp),
      ).resolves.toBeDefined();
    });

    it("should skip integrity check when no integrity provided", async () => {
      mockPrisma.device.findFirst.mockResolvedValueOnce({ id: "d1" });
      mockPrisma.step.findUnique.mockResolvedValueOnce(null);
      mockPrisma.step.upsert.mockResolvedValueOnce({
        stepCount: 5000,
        source: "google_fit",
      });

      const dtoWithoutIntegrity = { ...baseDto };
      delete (dtoWithoutIntegrity as any).integrity;
      await expect(
        service.syncSteps(userId, dtoWithoutIntegrity),
      ).resolves.toBeDefined();
    });
  });

  describe("getTodaySteps", () => {
    const userId = "user1";

    it("should fetch today steps, ensuring user data first", async () => {
      mockPrisma.step.findUnique.mockResolvedValueOnce({
        stepCount: 4000,
        caloriesBurned: 160,
        distanceKm: 3.0,
        activeMinutes: 30,
      });
      mockPrisma.user.findUnique.mockResolvedValueOnce({ dailyStepGoal: 5000 });

      const res = await service.getTodaySteps(userId);
      expect(res.stepCount).toBe(4000);
      expect(res.goal).toBe(5000);
      expect(res.progress).toBe(80);
      expect(res.goalReached).toBe(false);
    });

    it("should cap progress at 100%", async () => {
      mockPrisma.step.findUnique.mockResolvedValueOnce({ stepCount: 6000 });
      mockPrisma.user.findUnique.mockResolvedValueOnce({ dailyStepGoal: 5000 });

      const res = await service.getTodaySteps(userId);
      expect(res.progress).toBe(100);
      expect(res.goalReached).toBe(true);
    });

    it("should default to 10000 goal when user has no dailyStepGoal", async () => {
      mockPrisma.step.findUnique.mockResolvedValueOnce(null);
      mockPrisma.user.findUnique.mockResolvedValueOnce({ dailyStepGoal: null });

      const res = await service.getTodaySteps(userId);
      expect(res.stepCount).toBe(0);
      expect(res.goal).toBe(10000);
      expect(res.progress).toBe(0);
      expect(res.goalReached).toBe(false);
    });
  });

  describe("getHistory", () => {
    it("should return paginated history", async () => {
      mockPrisma.step.findMany.mockResolvedValueOnce([
        { id: "s1" },
        { id: "s2" },
      ]);
      mockPrisma.step.count.mockResolvedValueOnce(2);

      const res = await service.getHistory("u1", 1, 10);
      expect(res.data).toHaveLength(2);
      expect(res.pagination.total).toBe(2);
      expect(res.pagination.page).toBe(1);
    });
  });

  describe("getWeeklySummary", () => {
    it("should compute weekly totals correctly", async () => {
      const d1 = new Date();
      d1.setHours(0, 0, 0, 0);
      mockPrisma.step.findMany.mockResolvedValueOnce([
        { date: d1, stepCount: 5000, caloriesBurned: 200, distanceKm: 3.8 },
      ]);

      const res = await service.getWeeklySummary("u1");
      expect(res.totalSteps).toBe(5000);
      expect(res.activeDays).toBe(1);
      expect(res.dailyBreakdown.length).toBe(7);
    });
  });

  describe("getMonthlySummary", () => {
    it("should compute monthly totals correctly", async () => {
      const d1 = new Date(2023, 5, 15);
      mockPrisma.step.findMany.mockResolvedValueOnce([
        { date: d1, stepCount: 10000, caloriesBurned: 400, distanceKm: 7.6 },
      ]);

      const res = await service.getMonthlySummary("u1", 2023, 6);
      expect(res.totalSteps).toBe(10000);
      expect(res.activeDays).toBe(1);
      expect(res.bestDay).toEqual({
        date: "2023-06-15",
        stepCount: 10000,
      });
    });

    it("should handle empty steps for getMonthlySummary", async () => {
      mockPrisma.step.findMany.mockResolvedValueOnce([]);
      const res = await service.getMonthlySummary("u1", 2023, 6);
      expect(res.totalSteps).toBe(0);
      expect(res.bestDay).toBeNull();
    });
  });
});

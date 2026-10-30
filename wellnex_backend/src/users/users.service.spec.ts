import { Test, TestingModule } from "@nestjs/testing";
import { UsersService } from "./users.service";
import { PrismaService } from "../prisma/prisma.service";
import { RedisService } from "../redis/redis.service";
import { NotFoundException } from "@nestjs/common";

describe("UsersService", () => {
  let service: UsersService;

  const mockPrisma: any = {
    $transaction: jest.fn(async (cb) => cb(mockPrisma)),
    user: {
      findUnique: jest.fn(),
      findFirst: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      findMany: jest.fn(),
      count: jest.fn(),
      delete: jest.fn(),
    },
    achievement: {
      findMany: jest.fn(),
    },
    userAchievement: {
      upsert: jest.fn(),
      count: jest.fn(),
    },
    wallet: {
      upsert: jest.fn(),
    },
    transaction: {
      create: jest.fn(),
    },
    step: {
      aggregate: jest.fn(),
      findFirst: jest.fn(),
      findMany: jest.fn(),
    },
    avatar: {
      count: jest.fn(),
      create: jest.fn(),
      findMany: jest.fn(),
    },
    userSettings: {
      findUnique: jest.fn(),
      create: jest.fn(),
      upsert: jest.fn(),
      delete: jest.fn(),
    },
  };

  const mockRedis = {
    getCache: jest.fn(),
    setCache: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: RedisService, useValue: mockRedis },
      ],
    }).compile();

    service = module.get<UsersService>(UsersService);

    jest.clearAllMocks();
  });

  it("should be defined", () => {
    expect(service).toBeDefined();
  });

  describe("findById & findByIdentifier", () => {
    it("should find user by id", async () => {
      mockPrisma.user.findUnique.mockResolvedValueOnce({ id: "u1" });
      const res = await service.findById("u1");
      expect(res?.id).toBe("u1");
    });

    it("should find user by identifier", async () => {
      mockPrisma.user.findFirst.mockResolvedValueOnce({ id: "u1" });
      const res = await service.findByIdentifier("test@test.com");
      expect(res?.id).toBe("u1");
    });
  });

  describe("create & initialize achievements", () => {
    it("should create user and init achievements", async () => {
      mockPrisma.user.create.mockResolvedValueOnce({ id: "u1" });
      mockPrisma.achievement.findMany.mockResolvedValueOnce([{ id: "a1" }]);
      mockPrisma.userAchievement.upsert.mockResolvedValueOnce({});

      const res = await service.create({
        email: "t@t.com",
        phone: "123",
      } as any);
      expect(res.id).toBe("u1");
      expect(mockPrisma.userAchievement.upsert).toHaveBeenCalled();
    });

    it("should init achievements for all users", async () => {
      mockPrisma.user.findMany.mockResolvedValueOnce([{ id: "u1" }]);
      mockPrisma.achievement.findMany.mockResolvedValue([{ id: "a1" }]);

      const res = await service.initializeAchievementsForAllUsers();
      expect(res.success).toBe(true);
      expect(res.usersProcessed).toBe(1);
    });
  });

  describe("applyReferralCode", () => {
    it("should throw if invalid code", async () => {
      mockPrisma.user.findUnique.mockResolvedValueOnce(null);
      await expect(service.applyReferralCode("u1", "BAD")).rejects.toThrow(
        "Invalid referral code",
      );
    });

    it("should throw if own code", async () => {
      mockPrisma.user.findUnique.mockResolvedValueOnce({ id: "u1" });
      await expect(service.applyReferralCode("u1", "CODE")).rejects.toThrow(
        "own referral code",
      );
    });

    it("should throw if already referred", async () => {
      mockPrisma.user.findUnique.mockResolvedValueOnce({ id: "referrer" }); // referrer
      mockPrisma.user.findUnique.mockResolvedValueOnce({
        id: "u1",
        referredBy: "CODE2",
      }); // user
      await expect(service.applyReferralCode("u1", "CODE")).rejects.toThrow(
        "already applied",
      );
    });

    it("should apply referral code successfully", async () => {
      mockPrisma.user.findUnique.mockResolvedValueOnce({ id: "referrer" });
      mockPrisma.user.findUnique.mockResolvedValueOnce({ id: "u1" });

      const res = await service.applyReferralCode("u1", "CODE");
      expect(res.success).toBe(true);
      expect(mockPrisma.user.update).toHaveBeenCalledTimes(2);
      expect(mockPrisma.wallet.upsert).toHaveBeenCalled();
      expect(mockPrisma.transaction.create).toHaveBeenCalled();
    });
  });

  describe("getReferralLeaderboard & getReferralStats", () => {
    it("should return cached leaderboard", async () => {
      mockRedis.getCache.mockResolvedValueOnce([{ rank: 1 }]);
      const res = await service.getReferralLeaderboard();
      expect(res[0].rank).toBe(1);
    });

    it("should compute leaderboard if not cached", async () => {
      mockRedis.getCache.mockResolvedValueOnce(null);
      mockPrisma.user.findMany.mockResolvedValueOnce([
        { id: "u1", referralCount: 5 },
      ]);
      const res = await service.getReferralLeaderboard();
      expect(res[0].rank).toBe(1);
      expect(mockRedis.setCache).toHaveBeenCalled();
    });

    it("should get referral stats", async () => {
      mockPrisma.user.findUnique.mockResolvedValueOnce({ referralCount: 5 });
      mockPrisma.user.count.mockResolvedValueOnce(10); // 10 people better
      const res = await service.getReferralStats("u1");
      expect(res.rank).toBe(11);
    });
  });

  describe("update & getUserStats & computeFitnessLevel", () => {
    it("should throw if user not found on update", async () => {
      mockPrisma.user.findUnique.mockResolvedValueOnce(null);
      await expect(service.update("u1", {})).rejects.toThrow(NotFoundException);
    });

    it("should update user and auto-compute fitness level", async () => {
      mockPrisma.user.findUnique.mockResolvedValueOnce({ id: "u1" });
      mockPrisma.step.findMany.mockResolvedValueOnce([{ stepCount: 10000 }]);
      mockPrisma.user.update.mockResolvedValueOnce({ id: "u1" });

      const res = await service.update("u1", { weightKg: 70 });
      expect(res.id).toBe("u1");
      expect(mockPrisma.step.findMany).toHaveBeenCalled(); // computeFitnessLevel called
    });

    it("should get user stats", async () => {
      mockPrisma.user.findUnique.mockResolvedValueOnce({
        id: "u1",
        wallet: { balance: 100 },
        streak: { currentStreak: 5 },
      });
      mockPrisma.step.aggregate.mockResolvedValueOnce({
        _sum: { stepCount: 50000, caloriesBurned: 2000 },
      });
      mockPrisma.step.aggregate.mockResolvedValueOnce({
        _sum: { distanceKm: 40 },
      });
      mockPrisma.step.findFirst.mockResolvedValueOnce({ stepCount: 15000 });
      mockPrisma.userAchievement.count.mockResolvedValueOnce(3);
      mockPrisma.step.findMany.mockResolvedValueOnce([]); // computeFitnessLevel -> beginner

      const res = await service.getUserStats("u1");
      expect(res.fitnessLevel).toBe("beginner");
      expect(res.lifetimeSteps).toBe(50000);
      expect(res.currentStreak).toBe(5);
    });
  });

  describe("getAvatars & seedAvatars", () => {
    it("should return existing avatars", async () => {
      mockPrisma.avatar.count.mockResolvedValueOnce(5);
      mockPrisma.avatar.findMany.mockResolvedValueOnce([{ id: "a1" }]);
      const res = await service.getAvatars();
      expect(res).toHaveLength(1);
    });

    it("should seed avatars if 0", async () => {
      mockPrisma.avatar.count.mockResolvedValueOnce(0);
      mockPrisma.avatar.findMany.mockResolvedValueOnce([]);
      await service.getAvatars();
      expect(mockPrisma.avatar.create).toHaveBeenCalled();
    });
  });

  describe("GDPR & settings", () => {
    it("should sanitize user", () => {
      const u = { id: "1", refreshTokens: "x", fcmToken: "y", name: "Z" };
      const res = service.sanitizeUser(u);
      expect(res.name).toBe("Z");
      expect((res as any).fcmToken).toBeUndefined();
    });

    it("should export data", async () => {
      mockPrisma.user.findUnique.mockResolvedValueOnce({
        id: "u1",
        refreshTokens: "x",
      });
      const res = await service.exportData("u1");
      expect(res.data.id).toBe("u1");
      expect(res.data.refreshTokens).toBeUndefined();
    });

    it("should throw if user not found for export", async () => {
      mockPrisma.user.findUnique.mockResolvedValueOnce(null);
      await expect(service.exportData("u1")).rejects.toThrow(NotFoundException);
    });

    it("should delete account", async () => {
      mockPrisma.user.findUnique.mockResolvedValueOnce({ id: "u1" });
      const res = await service.deleteAccount("u1");
      expect(res.success).toBe(true);
      expect(mockPrisma.user.delete).toHaveBeenCalled();
    });

    it("should throw on delete account if not found", async () => {
      mockPrisma.user.findUnique.mockResolvedValueOnce(null);
      await expect(service.deleteAccount("u1")).rejects.toThrow(
        NotFoundException,
      );
    });

    it("should get settings or create", async () => {
      mockPrisma.userSettings.findUnique.mockResolvedValueOnce(null);
      mockPrisma.userSettings.create.mockResolvedValueOnce({ id: "s1" });
      const res = await service.getSettings("u1");
      expect(res.id).toBe("s1");
    });

    it("should update settings", async () => {
      mockPrisma.userSettings.upsert.mockResolvedValueOnce({ id: "s1" });
      const res = await service.updateSettings("u1", { isPushEnabled: true });
      expect(res.id).toBe("s1");
    });
  });
  describe("deleteSettings", () => {
    it("should delete user settings", async () => {
      mockPrisma.userSettings.delete.mockResolvedValueOnce({ id: "s1" });
      await service.deleteSettings("u1");
      expect(mockPrisma.userSettings.delete).toHaveBeenCalledWith({
        where: { userId: "u1" },
      });
    });
  });

  describe("computeFitnessLevel", () => {
    it("should return beginner if no steps", async () => {
      mockPrisma.step.findMany.mockResolvedValueOnce([]);
      const res = await service.computeFitnessLevel("u1");
      expect(res).toBe("beginner");
    });

    it("should return elite if >= 12000", async () => {
      mockPrisma.step.findMany.mockResolvedValueOnce([
        { stepCount: 15000 },
        { stepCount: 10000 },
      ]);
      const res = await service.computeFitnessLevel("u1");
      expect(res).toBe("elite");
    });

    it("should return athlete if >= 8000", async () => {
      mockPrisma.step.findMany.mockResolvedValueOnce([
        { stepCount: 9000 },
        { stepCount: 7000 },
      ]);
      const res = await service.computeFitnessLevel("u1");
      expect(res).toBe("athlete");
    });

    it("should return active if >= 5000", async () => {
      mockPrisma.step.findMany.mockResolvedValueOnce([
        { stepCount: 6000 },
        { stepCount: 4000 },
      ]);
      const res = await service.computeFitnessLevel("u1");
      expect(res).toBe("active");
    });

    it("should return beginner if < 5000", async () => {
      mockPrisma.step.findMany.mockResolvedValueOnce([
        { stepCount: 3000 },
        { stepCount: 4000 },
      ]);
      const res = await service.computeFitnessLevel("u1");
      expect(res).toBe("beginner");
    });
  });
  it("rejects adding or replacing login identities through profile edits", async () => {
    jest.spyOn(service, "findById").mockResolvedValue({
      id: "u1",
      phone: "+919876543210",
      email: "owner@example.invalid",
    } as any);
    await expect(
      service.update("u1", { email: "victim@example.invalid" }),
    ).rejects.toThrow("separate verified identity flow");
    await expect(
      service.update("u1", { phone: "+919999999999" }),
    ).rejects.toThrow("separate verified identity flow");
    expect(mockPrisma.user.update).not.toHaveBeenCalled();
  });
  it("allows profile saves that repeat existing identities without writing identity columns", async () => {
    jest.spyOn(service, "findById").mockResolvedValue({
      id: "u1",
      phone: "+919876543210",
      email: "Owner@Example.Invalid",
    } as any);
    mockPrisma.user.update.mockResolvedValue({ id: "u1" });
    await service.update("u1", {
      name: "Owner",
      email: "owner@example.invalid",
      phone: "+919876543210",
    });
    const call = mockPrisma.user.update.mock.calls.at(-1)[0];
    expect(call.data).not.toHaveProperty("email");
    expect(call.data).not.toHaveProperty("phone");
  });
});

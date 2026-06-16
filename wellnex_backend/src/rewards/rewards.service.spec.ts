import { Test, TestingModule } from "@nestjs/testing";
import { RewardsService } from "./rewards.service";
import { PrismaService } from "../prisma/prisma.service";
import { ConfigService } from "@nestjs/config";
import { QuestsService } from "../quests/quests.service";
import { NotificationsService } from "../notifications/notifications.service";

describe("RewardsService", () => {
  let service: RewardsService;

  const mockPrisma: any = {
    $transaction: jest.fn(async (cb) => cb(mockPrisma)),
    user: {
      findMany: jest.fn(),
      findUnique: jest.fn(),
    },
    wallet: {
      update: jest.fn(),
      findUnique: jest.fn(),
      create: jest.fn(),
      upsert: jest.fn(),
    },
    transaction: {
      create: jest.fn(),
      findMany: jest.fn(),
      count: jest.fn(),
    },
    step: {
      findMany: jest.fn(),
      aggregate: jest.fn(),
    },
    streak: {
      findUnique: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
    },
    userAchievement: {
      updateMany: jest.fn(),
      findMany: jest.fn(),
      findUnique: jest.fn(),
      upsert: jest.fn(),
    },
    level: {
      findMany: jest.fn(),
    },
    achievement: {
      findMany: jest.fn(),
    },
    userChallenge: {
      count: jest.fn(),
    },
    friendship: {
      count: jest.fn(),
    },
    reward: {
      findMany: jest.fn(),
      findUnique: jest.fn(),
      update: jest.fn(),
      create: jest.fn(),
    },
    userRedemption: {
      create: jest.fn(),
      findMany: jest.fn(),
    },
  };

  const mockConfig = {
    get: jest.fn().mockImplementation((key, defaultVal) => {
      if (key === "POINTS_PER_STEP") return "0.1";
      return defaultVal;
    }),
  };

  const mockQuestsService = {
    processQuestProgress: jest.fn(),
  };

  const mockNotificationsService = {
    sendPushNotification: jest.fn(),
    createAndNotify: jest.fn().mockResolvedValue({}),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        RewardsService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: ConfigService, useValue: mockConfig },
        { provide: QuestsService, useValue: mockQuestsService },
        { provide: NotificationsService, useValue: mockNotificationsService },
      ],
    }).compile();

    service = module.get<RewardsService>(RewardsService);
    jest.clearAllMocks();
  });

  it("should be defined", () => {
    expect(service).toBeDefined();
  });

  describe("processWalletExpiry", () => {
    it("should expire coins for inactive users", async () => {
      mockPrisma.user.findMany.mockResolvedValueOnce([
        { id: "u1", wallet: { balance: 100 } },
      ]);
      await service.processWalletExpiry();
      expect(mockPrisma.wallet.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { userId: "u1" },
          data: { balance: 0 },
        }),
      );
      expect(mockPrisma.transaction.create).toHaveBeenCalled();
    });

    it("should do nothing if no inactive users", async () => {
      mockPrisma.user.findMany.mockResolvedValueOnce([]);
      await service.processWalletExpiry();
      expect(mockPrisma.wallet.update).not.toHaveBeenCalled();
    });
  });

  describe("getWallet", () => {
    it("should return existing wallet", async () => {
      mockPrisma.wallet.findUnique.mockResolvedValueOnce({
        id: "w1",
        balance: 50,
      });
      const w = await service.getWallet("u1");
      expect(w.balance).toBe(50);
    });

    it("should create wallet if not found", async () => {
      mockPrisma.wallet.findUnique.mockResolvedValueOnce(null);
      mockPrisma.wallet.create.mockResolvedValueOnce({ id: "w1", balance: 0 });
      const w = await service.getWallet("u1");
      expect(w.balance).toBe(0);
      expect(mockPrisma.wallet.create).toHaveBeenCalled();
    });

    it("should catch error and return wallet on concurrency create conflict", async () => {
      mockPrisma.wallet.findUnique.mockResolvedValueOnce(null);
      mockPrisma.wallet.create.mockRejectedValueOnce(
        new Error("Unique Constraint"),
      );
      mockPrisma.wallet.findUnique.mockResolvedValueOnce({
        id: "w1",
        balance: 0,
      });
      const w = await service.getWallet("u1");
      expect(w.balance).toBe(0);
    });

    it("should rethrow error on concurrency create conflict if wallet not found", async () => {
      mockPrisma.wallet.findUnique.mockResolvedValueOnce(null);
      mockPrisma.wallet.create.mockRejectedValueOnce(new Error("DB Error"));
      mockPrisma.wallet.findUnique.mockResolvedValueOnce(null);
      await expect(service.getWallet("u1")).rejects.toThrow("DB Error");
    });
  });

  describe("processStepRewards", () => {
    it("should award points and process dependencies correctly", async () => {
      mockPrisma.user.findUnique.mockResolvedValue({ dailyStepGoal: 5000 });
      mockPrisma.transaction.findMany.mockResolvedValue([]);
      mockPrisma.transaction.create.mockResolvedValue({});
      mockPrisma.wallet.upsert.mockResolvedValue({});

      // Mock updateStreak
      mockPrisma.streak.findUnique.mockResolvedValue({
        currentStreak: 1,
        longestStreak: 1,
        lastActiveDate: new Date(),
      });
      mockPrisma.streak.update.mockResolvedValue({});
      mockPrisma.streak.create.mockResolvedValue({
        currentStreak: 1,
        longestStreak: 1,
        lastActiveDate: new Date(),
      });

      // Mock checkAchievements
      mockPrisma.step.findMany.mockResolvedValue([]);
      mockPrisma.step.aggregate.mockResolvedValue({
        _sum: { stepCount: 10000 },
      });
      mockPrisma.wallet.findUnique.mockResolvedValue({
        lifetimePoints: 1000,
        balance: 1000,
        lastResetDate: new Date(),
      });
      mockPrisma.userChallenge.count.mockResolvedValue(0);
      mockPrisma.friendship.count.mockResolvedValue(0);
      mockPrisma.achievement.findMany.mockResolvedValue([]);

      const res = await service.processStepRewards("u1", 6000, new Date());
      expect(res.pointsEarned).toBe(600); // 6000 * 0.1
      expect(mockQuestsService.processQuestProgress).toHaveBeenCalledWith(
        "u1",
        6000,
      );
    });

    it("should award only incremental points if some points have already been awarded today", async () => {
      mockPrisma.user.findUnique.mockResolvedValue({ dailyStepGoal: 5000 });
      const dateStr = new Date().toISOString().split("T")[0];
      mockPrisma.transaction.findMany.mockResolvedValueOnce([
        { points: 50, metadata: { date: dateStr } },
      ]);
      mockPrisma.transaction.create.mockResolvedValue({});
      mockPrisma.wallet.upsert.mockResolvedValue({});

      mockPrisma.streak.findUnique.mockResolvedValue({
        currentStreak: 1,
        longestStreak: 1,
        lastActiveDate: new Date(),
      });
      mockPrisma.streak.update.mockResolvedValue({});

      mockPrisma.step.findMany.mockResolvedValue([]);
      mockPrisma.step.aggregate.mockResolvedValue({
        _sum: { stepCount: 10000 },
      });
      mockPrisma.wallet.findUnique.mockResolvedValue({
        lifetimePoints: 1000,
        balance: 1000,
        lastResetDate: new Date(),
      });
      mockPrisma.userChallenge.count.mockResolvedValue(0);
      mockPrisma.friendship.count.mockResolvedValue(0);
      mockPrisma.achievement.findMany.mockResolvedValue([]);

      const res = await service.processStepRewards("u1", 6000, new Date());
      expect(res.pointsEarned).toBe(550); // 600 (total) - 50 (already awarded) = 550
    });

    it("should return 0 points earned if new points <= 0", async () => {
      mockPrisma.user.findUnique.mockResolvedValue({ dailyStepGoal: 5000 });
      const dateStr = new Date().toISOString().split("T")[0];
      // Already awarded more points than today's total
      mockPrisma.transaction.findMany.mockResolvedValueOnce([
        { points: 1000, metadata: { date: dateStr } },
      ]);

      mockPrisma.streak.findUnique.mockResolvedValue({
        currentStreak: 1,
        longestStreak: 1,
        lastActiveDate: new Date(),
      });
      mockPrisma.streak.update.mockResolvedValue({});
      mockPrisma.streak.create.mockResolvedValue({});
      mockPrisma.step.findMany.mockResolvedValue([]);
      mockPrisma.step.aggregate.mockResolvedValue({
        _sum: { stepCount: 1000 },
      });
      mockPrisma.wallet.findUnique.mockResolvedValue({
        lifetimePoints: 500,
        balance: 500,
        lastResetDate: new Date(),
      });
      mockPrisma.userChallenge.count.mockResolvedValue(0);
      mockPrisma.friendship.count.mockResolvedValue(0);
      mockPrisma.achievement.findMany.mockResolvedValue([]);

      const res = await service.processStepRewards("u1", 100, new Date());
      // 100 steps * 0.1 = 10 points – already awarded 1000, so newPoints = -990 → clamped to 0
      expect(res.pointsEarned).toBe(0);
      expect(mockPrisma.wallet.upsert).not.toHaveBeenCalled();
    });
  });

  describe("updateStreak", () => {
    it("should increment streak on consecutive day", async () => {
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);
      yesterday.setHours(0, 0, 0, 0);

      mockPrisma.streak.findUnique.mockResolvedValue({
        userId: "u1",
        currentStreak: 5,
        longestStreak: 5,
        lastActiveDate: yesterday,
      });
      mockPrisma.streak.update.mockResolvedValue({ currentStreak: 6 });

      await service.updateStreak("u1", new Date());
      expect(mockPrisma.streak.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ currentStreak: 6 }),
        }),
      );
    });

    it("should reset streak if missed a day", async () => {
      const past = new Date();
      past.setDate(past.getDate() - 3);
      past.setHours(0, 0, 0, 0);

      mockPrisma.streak.findUnique.mockResolvedValue({
        userId: "u1",
        currentStreak: 5,
        longestStreak: 5,
        lastActiveDate: past,
      });
      mockPrisma.streak.update.mockResolvedValue({ currentStreak: 1 });

      await service.updateStreak("u1", new Date());
      expect(mockPrisma.streak.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ currentStreak: 1 }),
        }),
      );
    });

    it("should create new streak if none exists", async () => {
      mockPrisma.streak.findUnique.mockResolvedValueOnce(null);
      mockPrisma.streak.create.mockResolvedValueOnce({ currentStreak: 1 });
      const res = await service.updateStreak("u1", new Date());
      expect(mockPrisma.streak.create).toHaveBeenCalled();
      expect(res.currentStreak).toBe(1);
    });

    it("should set streak to 1 if lastActive is missing", async () => {
      mockPrisma.streak.findUnique.mockResolvedValueOnce({
        currentStreak: 5,
        longestStreak: 5,
        lastActiveDate: null,
      });
      mockPrisma.streak.update.mockResolvedValueOnce({ currentStreak: 1 });
      await service.updateStreak("u1", new Date());
      expect(mockPrisma.streak.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ currentStreak: 1 }),
        }),
      );
    });

    it("should award streak milestones", async () => {
      const today = new Date();
      const yesterday = new Date(today);
      yesterday.setDate(today.getDate() - 1);
      yesterday.setHours(0, 0, 0, 0);

      mockPrisma.streak.findUnique.mockResolvedValueOnce({
        userId: "u1",
        currentStreak: 6,
        longestStreak: 6,
        lastActiveDate: yesterday,
      });
      mockPrisma.streak.update.mockResolvedValueOnce({ currentStreak: 7 });
      mockPrisma.transaction.create.mockResolvedValue({});
      mockPrisma.wallet.upsert.mockResolvedValue({});
      await service.updateStreak("u1", today);
      expect(mockPrisma.transaction.create).toHaveBeenCalled();
    });
  });

  describe("redeemReward", () => {
    it("should redeem successfully when balance allows", async () => {
      const mockReward = {
        id: "r1",
        coinCost: 100,
        availableStock: 10,
        isActive: true,
      };
      const mockWallet = { id: "w1", userId: "u1", balance: 200 };

      mockPrisma.wallet.findUnique.mockResolvedValue(mockWallet);
      mockPrisma.reward.findUnique.mockResolvedValue(mockReward);
      mockPrisma.userRedemption.create.mockResolvedValue({ id: "red1" });
      mockPrisma.wallet.update.mockResolvedValue({});
      mockPrisma.transaction.create.mockResolvedValue({});
      mockPrisma.reward.update.mockResolvedValue({});

      const res = await service.redeemReward("u1", "r1");
      expect(res.success).toBe(true);
      expect(res.newBalance).toBe(100);
      expect(mockPrisma.wallet.update).toHaveBeenCalled();
    });

    it("should fail if insufficient coins", async () => {
      const mockReward = {
        id: "r1",
        coinCost: 500,
        availableStock: 10,
        isActive: true,
      };
      const mockWallet = { id: "w1", userId: "u1", balance: 200 };

      mockPrisma.wallet.findUnique.mockResolvedValue(mockWallet);
      mockPrisma.reward.findUnique.mockResolvedValue(mockReward);

      await expect(service.redeemReward("u1", "r1")).rejects.toThrow(
        "Insufficient coins",
      );
    });

    it("should throw if wallet not found", async () => {
      mockPrisma.wallet.findUnique.mockResolvedValue(null);
      await expect(service.redeemReward("u1", "r1")).rejects.toThrow(
        "Wallet not found",
      );
    });

    it("should throw if reward not found", async () => {
      mockPrisma.wallet.findUnique.mockResolvedValue({});
      mockPrisma.reward.findUnique.mockResolvedValue(null);
      await expect(service.redeemReward("u1", "r1")).rejects.toThrow(
        "Reward not found",
      );
    });

    it("should throw if reward is not active", async () => {
      mockPrisma.wallet.findUnique.mockResolvedValue({});
      mockPrisma.reward.findUnique.mockResolvedValue({ isActive: false });
      await expect(service.redeemReward("u1", "r1")).rejects.toThrow(
        "Reward is no longer available",
      );
    });

    it("should throw if reward out of stock", async () => {
      mockPrisma.wallet.findUnique.mockResolvedValue({ balance: 500 });
      mockPrisma.reward.findUnique.mockResolvedValue({
        isActive: true,
        coinCost: 100,
        availableStock: 0,
      });
      await expect(service.redeemReward("u1", "r1")).rejects.toThrow(
        "Reward is out of stock",
      );
    });

    it("should redeem unlimited stock reward without decrementing stock", async () => {
      mockPrisma.wallet.findUnique.mockResolvedValue({ balance: 500 });
      mockPrisma.reward.findUnique.mockResolvedValue({
        isActive: true,
        coinCost: 100,
        availableStock: -1,
      });
      mockPrisma.userRedemption.create.mockResolvedValue({});
      mockPrisma.wallet.update.mockResolvedValue({});
      mockPrisma.transaction.create.mockResolvedValue({});
      await service.redeemReward("u1", "r1");
    });
  });

  describe("getTransactions", () => {
    it("should return paginated transactions", async () => {
      mockPrisma.transaction.findMany.mockResolvedValueOnce([{ id: "tx1" }]);
      mockPrisma.transaction.count.mockResolvedValueOnce(1);
      const res = await service.getTransactions("u1", 1, 10);
      expect(res.data.length).toBe(1);
      expect(res.pagination.total).toBe(1);
    });
  });

  describe("checkMonthlyReset", () => {
    it("should reset monthly stats if it is a new month", async () => {
      const pastDate = new Date();
      pastDate.setMonth(pastDate.getMonth() - 1);
      mockPrisma.wallet.findUnique.mockResolvedValueOnce({
        userId: "u1",
        lastResetDate: pastDate,
      });
      mockPrisma.wallet.update.mockResolvedValueOnce({});
      mockPrisma.userAchievement.updateMany.mockResolvedValueOnce({});

      await service.checkMonthlyReset("u1");
      expect(mockPrisma.wallet.update).toHaveBeenCalled();
      expect(mockPrisma.userAchievement.updateMany).toHaveBeenCalled();
    });

    it("should do nothing if same month", async () => {
      mockPrisma.wallet.findUnique.mockResolvedValueOnce({
        userId: "u1",
        lastResetDate: new Date(),
      });
      await service.checkMonthlyReset("u1");
      expect(mockPrisma.wallet.update).not.toHaveBeenCalled();
    });

    it("should do nothing if wallet is null", async () => {
      mockPrisma.wallet.findUnique.mockResolvedValueOnce(null);
      await service.checkMonthlyReset("u1");
      expect(mockPrisma.wallet.update).not.toHaveBeenCalled();
    });
  });

  describe("getStreak", () => {
    it("should recalculate streak and return it", async () => {
      mockPrisma.step.findMany.mockResolvedValueOnce([
        { date: new Date(), stepCount: 5000 },
      ]);
      mockPrisma.streak.findUnique.mockResolvedValueOnce({
        userId: "u1",
        currentStreak: 1,
        longestStreak: 1,
      });
      mockPrisma.streak.update.mockResolvedValueOnce({
        currentStreak: 1,
        longestStreak: 1,
        lastActiveDate: new Date(),
      });

      const res = await service.getStreak("u1");
      expect(res.currentStreak).toBe(1);
      expect(res.nextMilestone).toBe(7);
      expect(res.daysToMilestone).toBe(6);
    });

    it("should create streak in recalculate if none exists", async () => {
      const d1 = new Date();
      d1.setHours(0, 0, 0, 0);
      mockPrisma.step.findMany.mockResolvedValueOnce([{ date: d1 }]);
      mockPrisma.streak.findUnique.mockResolvedValueOnce(null);
      mockPrisma.streak.create.mockResolvedValueOnce({ currentStreak: 1 });
      await service.recalculateStreakFromSteps("u1");
      expect(mockPrisma.streak.create).toHaveBeenCalled();
    });

    it("should use findUnique fallback if recalculate throws", async () => {
      mockPrisma.step.findMany.mockRejectedValueOnce(new Error("DB Error"));
      mockPrisma.streak.findUnique.mockResolvedValueOnce({ currentStreak: 5 });
      const res = await service.getStreak("u1");
      expect(res.currentStreak).toBe(5);
    });

    it("should throw if fallback also fails", async () => {
      mockPrisma.step.findMany.mockRejectedValueOnce(new Error("DB Error"));
      mockPrisma.streak.findUnique.mockResolvedValueOnce(null);
      await expect(service.getStreak("u1")).rejects.toThrow("DB Error");
    });

    it("should calculate streak accurately from multiple days", async () => {
      const d1 = new Date("2023-01-01");
      const d2 = new Date("2023-01-02");
      const d3 = new Date("2023-01-04"); // break streak
      const d4 = new Date();
      d4.setDate(d4.getDate() - 1); // yesterday

      mockPrisma.step.findMany.mockResolvedValueOnce([
        { date: d1 },
        { date: d2 },
        { date: d3 },
        { date: d4 },
      ]);
      mockPrisma.streak.findUnique.mockResolvedValueOnce(null);
      mockPrisma.streak.create.mockResolvedValueOnce({});

      await service.recalculateStreakFromSteps("u1");
      expect(mockPrisma.streak.create).toHaveBeenCalled();
    });

    it("should handle zero steps", async () => {
      mockPrisma.step.findMany.mockResolvedValueOnce([]);
      mockPrisma.streak.findUnique.mockResolvedValueOnce(null);
      mockPrisma.streak.create.mockResolvedValueOnce({});

      await service.recalculateStreakFromSteps("u1");
      expect(mockPrisma.streak.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ currentStreak: 0 }),
        }),
      );
    });
  });

  describe("getLevels", () => {
    it("should return levels", async () => {
      mockPrisma.level.findMany.mockResolvedValueOnce([{ levelNumber: 1 }]);
      const res = await service.getLevels();
      expect(res.length).toBe(1);
    });
  });

  describe("getRewardsCatalog", () => {
    it("should return rewards and check affordance", async () => {
      mockPrisma.wallet.findUnique.mockResolvedValueOnce({ balance: 500 });
      mockPrisma.reward.findMany.mockResolvedValueOnce([
        { coinCost: 100, availableStock: 1 },
      ]);
      const res = await service.getRewardsCatalog("u1");
      expect(res[0].canAfford).toBe(true);
    });

    it("should filter rewards by category", async () => {
      mockPrisma.wallet.findUnique.mockResolvedValueOnce({ balance: 500 });
      mockPrisma.reward.findMany.mockResolvedValueOnce([]);
      await service.getRewardsCatalog("u1", "FITNESS");
      expect(mockPrisma.reward.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { isActive: true, category: "FITNESS" },
          orderBy: expect.anything(),
        }),
      );
    });
  });

  describe("getMyOffers", () => {
    it("should return user redemptions", async () => {
      mockPrisma.userRedemption.findMany.mockResolvedValueOnce([
        { id: "red1" },
      ]);
      const res = await service.getMyOffers("u1");
      expect(res.length).toBe(1);
    });

    it("should filter by status", async () => {
      mockPrisma.userRedemption.findMany.mockResolvedValueOnce([]);
      await service.getMyOffers("u1", "ACTIVE");
      expect(mockPrisma.userRedemption.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { userId: "u1", status: "ACTIVE" },
          include: expect.anything(),
          orderBy: expect.anything(),
        }),
      );
    });
  });

  describe("getAchievements", () => {
    it("should map user achievements correctly", async () => {
      mockPrisma.step.findMany.mockResolvedValue([]);
      mockPrisma.streak.findUnique.mockResolvedValue(null);
      mockPrisma.streak.create.mockResolvedValue({ currentStreak: 1 });
      mockPrisma.step.aggregate.mockResolvedValue({
        _sum: { stepCount: 10000 },
      });
      mockPrisma.wallet.findUnique.mockResolvedValue({});
      mockPrisma.userChallenge.count.mockResolvedValue(0);
      mockPrisma.friendship.count.mockResolvedValue(0);

      // Real getAchievements data
      mockPrisma.achievement.findMany.mockResolvedValue([
        { id: "a1", isActive: true, stepsRequired: 5000 },
        { id: "a2", isActive: true, streakRequired: 5 },
        { id: "a3", isActive: true, targetValue: 5, category: "SOCIAL" },
        { id: "a4", isActive: true, targetValue: 5, category: "CHALLENGE" },
        { id: "a5", isActive: true, targetValue: 500, category: "COINS" },
      ]);
      mockPrisma.userAchievement.findUnique.mockResolvedValue(null);
      mockPrisma.userAchievement.upsert.mockResolvedValue({});
      mockPrisma.userAchievement.findMany.mockResolvedValue([
        {
          achievementId: "a1",
          unlocked: true,
          progress: 100,
          currentValue: 10000,
        },
      ]);

      const res = await service.getAchievements("u1");
      expect(res.length).toBe(5);
    });
  });

  describe("checkAchievements", () => {
    it("should calculate achievement progress correctly for all types and award points", async () => {
      mockPrisma.step.findMany.mockResolvedValue([]);
      mockPrisma.streak.findUnique.mockResolvedValue(null);
      mockPrisma.streak.create.mockResolvedValue({
        currentStreak: 5,
        longestStreak: 10,
      });
      mockPrisma.step.aggregate.mockResolvedValue({
        _sum: { stepCount: 10000 },
      });
      mockPrisma.wallet.findUnique.mockResolvedValue({ lifetimePoints: 500 });
      mockPrisma.userChallenge.count.mockResolvedValue(5);
      mockPrisma.friendship.count.mockResolvedValue(5);

      mockPrisma.achievement.findMany.mockResolvedValue([
        { id: "a1", streakRequired: 10, pointsReward: 100 },
        { id: "a2", targetValue: 5, category: "SOCIAL", pointsReward: 100 },
        { id: "a3", targetValue: 5, category: "CHALLENGE", pointsReward: 100 },
        { id: "a4", targetValue: 500, category: "COINS", pointsReward: 100 },
        { id: "a5", stepsRequired: 10000, pointsReward: 100 },
      ]);
      mockPrisma.userAchievement.findUnique.mockResolvedValue(null); // not unlocked yet
      mockPrisma.userAchievement.upsert.mockResolvedValue({});
      mockPrisma.transaction.create.mockResolvedValue({});

      const count = await service.checkAchievements("u1");
      expect(count).toBe(5); // all 5 should unlock
    });
  });

  describe("getRewardDetails", () => {
    it("should return details if found", async () => {
      mockPrisma.wallet.findUnique.mockResolvedValueOnce({ balance: 500 });
      mockPrisma.reward.findUnique.mockResolvedValueOnce({
        id: "r1",
        coinCost: 100,
        availableStock: -1,
      });
      const res = await service.getRewardDetails("r1", "u1");
      expect(res.canAfford).toBe(true);
      expect(res.inStock).toBe(true);
    });
    it("should throw if reward not found", async () => {
      mockPrisma.wallet.findUnique.mockResolvedValueOnce({ balance: 500 });
      mockPrisma.reward.findUnique.mockResolvedValueOnce(null);
      await expect(service.getRewardDetails("r1", "u1")).rejects.toThrow(
        "Reward not found",
      );
    });
  });

  describe("seedDemoRewards", () => {
    it("should seed rewards", async () => {
      mockPrisma.reward.create.mockResolvedValue({});
      const res = await service.seedDemoRewards();
      expect(res.count).toBe(6);
      expect(mockPrisma.reward.create).toHaveBeenCalledTimes(6);
    });
  });

  describe("forceRewardsSync", () => {
    it("should process step rewards for found steps", async () => {
      mockPrisma.step.findMany.mockResolvedValueOnce([
        { userId: "u1", stepCount: 5000 },
        { userId: "u2", stepCount: 10000 },
      ]);
      mockPrisma.user.findUnique.mockResolvedValue({ dailyStepGoal: 5000 });
      mockPrisma.transaction.findMany.mockResolvedValue([]);
      mockPrisma.transaction.create.mockResolvedValue({});
      mockPrisma.wallet.upsert.mockResolvedValue({});
      mockPrisma.streak.findUnique.mockResolvedValue({
        currentStreak: 1,
        longestStreak: 1,
      });
      mockPrisma.streak.update.mockResolvedValue({});
      mockPrisma.step.aggregate.mockResolvedValue({
        _sum: { stepCount: 5000 },
      });
      mockPrisma.wallet.findUnique.mockResolvedValue({});
      mockPrisma.userChallenge.count.mockResolvedValue(0);
      mockPrisma.friendship.count.mockResolvedValue(0);
      mockPrisma.achievement.findMany.mockResolvedValue([]);

      const result = await service.forceRewardsSync();

      expect(result.processedCount).toBe(2);
      expect(result.details.length).toBe(2);
      expect(mockPrisma.step.findMany).toHaveBeenCalled();
    });

    it("should process step rewards with userId filter", async () => {
      mockPrisma.step.findMany.mockResolvedValueOnce([
        { userId: "u1", stepCount: 5000 },
      ]);

      const result = await service.forceRewardsSync("u1");

      expect(result.processedCount).toBe(1);
      expect(mockPrisma.step.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ userId: "u1" }),
        }),
      );
    });

    it("should handle processing errors gracefully", async () => {
      mockPrisma.step.findMany.mockResolvedValueOnce([
        { userId: "u1", stepCount: 5000 },
      ]);
      mockPrisma.user.findUnique.mockRejectedValueOnce(new Error("Test Error"));

      const result = await service.forceRewardsSync("u1");

      expect(result.processedCount).toBe(1);
      expect(result.details.length).toBe(0); // Should not be in details since it failed
    });
  });
});

import { Injectable, Logger } from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { ConfigService } from "@nestjs/config";
import { TransactionType } from "@prisma/client";
import { QuestsService } from "../quests/quests.service";
import { NotificationsService } from "../notifications/notifications.service";
import { Cron, CronExpression } from "@nestjs/schedule";

@Injectable()
export class RewardsService {
  private readonly logger = new Logger(RewardsService.name);
  private readonly pointsPerStep: number;

  constructor(
    private readonly prisma: PrismaService,
    private readonly configService: ConfigService,
    private readonly questsService: QuestsService,
    private readonly notificationsService: NotificationsService,
  ) {
    this.pointsPerStep = Number.parseFloat(
      this.configService.get("POINTS_PER_STEP", "0.1"),
    );
  }

  /**
   * CRON: Wallet Expiry
   * Runs daily at midnight to expire coins for users inactive for > 180 days.
   */
  @Cron(CronExpression.EVERY_DAY_AT_MIDNIGHT)
  async processWalletExpiry() {
    this.logger.log("Running CRON: processWalletExpiry");

    const sixMonthsAgo = new Date();
    sixMonthsAgo.setDate(sixMonthsAgo.getDate() - 180);

    // Find users with balance > 0 who haven't logged steps or transactions in 180 days
    const inactiveUsers = await this.prisma.user.findMany({
      where: {
        wallet: { balance: { gt: 0 } },
        updatedAt: { lt: sixMonthsAgo },
      },
      include: { wallet: true },
    });

    if (inactiveUsers.length === 0) {
      this.logger.log("No inactive wallets to expire.");
      return;
    }

    for (const user of inactiveUsers) {
      if (!user.wallet) continue;

      const walletBalance = user.wallet.balance;

      await this.prisma.$transaction(async (tx) => {
        // 1. Drain balance
        await tx.wallet.update({
          where: { userId: user.id },
          data: { balance: 0 },
        });

        // 2. Log expiration transaction
        await tx.transaction.create({
          data: {
            userId: user.id,
            type: "REDEMPTION", // Align with schema TransactionType
            points: -walletBalance,
            description: "Coins expired due to 180 days of inactivity.",
          },
        });
      });

      this.logger.log(
        `Expired ${user.wallet.balance} coins for inactive user ${user.id}`,
      );
    }

    this.logger.log(
      `Wallet expiry complete. Expired ${inactiveUsers.length} wallets.`,
    );
  }

  /**
   * Get user wallet
   */
  async getWallet(userId: string) {
    try {
      let wallet = await this.prisma.wallet.findUnique({
        where: { userId },
      });

      wallet ??= await this.prisma.wallet.create({
        data: {
          userId,
          balance: 0,
          lifetimePoints: 0,
          monthlyXp: 0,
        },
      });

      return wallet;
    } catch (error) {
      // Concurrency fallback
      const wallet = await this.prisma.wallet.findUnique({
        where: { userId },
      });
      if (wallet) return wallet;
      throw error;
    }
  }

  /**
   * Get transaction history
   */
  async getTransactions(userId: string, page: number = 1, limit: number = 20) {
    // Ensure page and limit are valid integers
    const pageNum = Math.max(1, Number.parseInt(String(page)) || 1);
    const limitNum = Math.max(
      1,
      Math.min(100, Number.parseInt(String(limit)) || 20),
    );
    const skip = (pageNum - 1) * limitNum;

    const [transactions, total] = await Promise.all([
      this.prisma.transaction.findMany({
        where: { userId },
        orderBy: { createdAt: "desc" },
        take: limitNum,
        skip,
      }),
      this.prisma.transaction.count({ where: { userId } }),
    ]);

    return {
      data: transactions,
      pagination: {
        page: pageNum,
        limit: limitNum,
        total,
        totalPages: Math.ceil(total / limitNum),
      },
    };
  }

  /**
   * Process rewards for step sync
   * Called automatically when steps are synced
   */
  async processStepRewards(userId: string, stepCount: number, date: Date) {
    // Get user's goal
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { dailyStepGoal: true },
    });

    const goal = user?.dailyStepGoal || 10000;

    // Award points for steps
    const pointsEarned = Math.floor(stepCount * this.pointsPerStep);

    // Format date string to YYYY-MM-DD
    const year = date.getUTCFullYear();
    const month = String(date.getUTCMonth() + 1).padStart(2, "0");
    const day = String(date.getUTCDate()).padStart(2, "0");
    const dateStr = `${year}-${month}-${day}`;

    // Get recent step transactions to calculate points already awarded today
    // We fetch recent ones and filter in memory to avoid Prisma JSON querying issues
    const recentTransactions = await this.prisma.transaction.findMany({
      where: {
        userId,
        type: TransactionType.STEPS,
      },
      orderBy: { createdAt: "desc" },
      take: 50,
      select: {
        points: true,
        metadata: true,
      },
    });

    const todaysTransactions = recentTransactions.filter((tx) => {
      if (!tx.metadata) return false;
      const meta = tx.metadata as any;
      return meta.date === dateStr;
    });

    const pointsAlreadyAwarded = todaysTransactions.reduce(
      (sum, tx) => sum + tx.points,
      0,
    );
    const newPoints = pointsEarned - pointsAlreadyAwarded;

    if (newPoints > 0) {
      await this.addPoints(
        userId,
        newPoints,
        TransactionType.STEPS,
        `Earned ${newPoints} points for reaching ${stepCount.toLocaleString()} steps today`,
        { date: dateStr },
      );
    }

    // Update streak if goal reached
    if (stepCount >= goal) {
      await this.updateStreak(userId, date);
    }

    // Check for new achievements
    await this.checkAchievements(userId);

    // Process live quest progression
    await this.questsService.processQuestProgress(userId, stepCount);

    // Check for monthly reset
    await this.checkMonthlyReset(userId);

    return { pointsEarned: newPoints > 0 ? newPoints : 0 };
  }

  /**
   * Add points to user wallet
   */
  async addPoints(
    userId: string,
    points: number,
    type: TransactionType,
    description?: string,
    metadata?: any,
  ) {
    // Create transaction
    const transaction = await this.prisma.transaction.create({
      data: {
        userId,
        type,
        points,
        description,
        metadata,
      },
    });

    // Update wallet
    await this.prisma.wallet.upsert({
      where: { userId },
      update: {
        balance: { increment: points },
        lifetimePoints: { increment: points },
        monthlyXp: { increment: points },
      },
      create: {
        userId,
        balance: points,
        lifetimePoints: points,
        monthlyXp: points,
      },
    });

    return transaction;
  }

  /**
   * Check and process monthly reset
   */
  async checkMonthlyReset(userId: string) {
    const wallet = await this.prisma.wallet.findUnique({ where: { userId } });
    if (!wallet) return;

    const lastReset = new Date(wallet.lastResetDate);
    const now = new Date();

    // Check if we occur in a new month compared to last reset
    if (
      now.getMonth() !== lastReset.getMonth() ||
      now.getFullYear() !== lastReset.getFullYear()
    ) {
      // It's a new month! Reset time.
      this.logger.log(`Performing monthly reset for user ${userId}`);

      // 1. Reset Monthly XP and Update Date
      await this.prisma.wallet.update({
        where: { userId },
        data: {
          monthlyXp: 0,
          lastResetDate: now,
        },
      });

      // 2. Reset Badges (Lock all achievements)
      await this.prisma.userAchievement.updateMany({
        where: { userId },
        data: {
          unlocked: false,
          progress: 0,
          currentValue: 0,
          unlockedAt: null,
        },
      });

      // 3. Reset Level? Level is calculated from XP.
      // If we use monthlyXp for level, it auto-resets when monthlyXp becomes 0.
    }
  }

  /**
   * Update user streak
   */
  async updateStreak(userId: string, date: Date) {
    const dateOnly = new Date(date);
    dateOnly.setHours(0, 0, 0, 0);

    let streak = await this.prisma.streak.findUnique({
      where: { userId },
    });

    let isNewStreak = false;
    if (!streak) {
      streak = await this.prisma.streak.create({
        data: {
          userId,
          currentStreak: 1,
          longestStreak: 1,
          lastActiveDate: dateOnly,
        },
      });
      isNewStreak = true;
    }

    if (isNewStreak) {
      return streak;
    }

    const yesterday = new Date(dateOnly);
    yesterday.setDate(yesterday.getDate() - 1);

    const lastActive = streak.lastActiveDate
      ? new Date(streak.lastActiveDate)
      : null;

    let newStreak = streak.currentStreak;

    if (!lastActive) {
      // First activity
      newStreak = 1;
    } else if (lastActive.getTime() === yesterday.getTime()) {
      // Consecutive day - increment streak
      newStreak = streak.currentStreak + 1;

      // Award streak bonuses at milestones
      await this.checkStreakMilestones(userId, newStreak);
    } else if (lastActive.getTime() < yesterday.getTime()) {
      // Streak broken - reset
      newStreak = 1;
    }
    // If same day, keep streak the same

    // Update streak
    streak = await this.prisma.streak.update({
      where: { userId },
      data: {
        currentStreak: newStreak,
        longestStreak: Math.max(streak.longestStreak, newStreak),
        lastActiveDate: dateOnly,
      },
    });

    return streak;
  }

  /**
   * Check and award streak milestone bonuses
   */
  private async checkStreakMilestones(userId: string, streak: number) {
    const milestones: { [key: number]: number } = {
      7: 50, // Week streak
      30: 200, // Month streak
      100: 500, // 100 days
      365: 2000, // Year streak
    };

    if (milestones[streak]) {
      await this.addPoints(
        userId,
        milestones[streak],
        TransactionType.STREAK_BONUS,
        `🔥 ${streak}-day streak bonus!`,
      );
      this.logger.log(`User ${userId} earned ${streak}-day streak bonus`);
    }
  }

  /**
   * Recalculate streak values from step history (Self-Healing & Timezone-Resilient)
   */
  async recalculateStreakFromSteps(userId: string) {
    const allSteps = await this.prisma.step.findMany({
      where: {
        userId,
        stepCount: { gt: 0 },
      },
      orderBy: { date: "asc" },
      select: { date: true },
    });

    let calculatedCurrentStreak = 0;
    let calculatedLongestStreak = 0;
    let lastActiveDate: Date | null = null;

    if (allSteps.length > 0) {
      const uniqueDates = Array.from(
        new Set(
          allSteps.map((s) => {
            const d = s.date;
            const year = d.getUTCFullYear();
            const month = String(d.getUTCMonth() + 1).padStart(2, "0");
            const day = String(d.getUTCDate()).padStart(2, "0");
            return `${year}-${month}-${day}`;
          }),
        ),
      ).sort((a, b) => a.localeCompare(b));

      if (uniqueDates.length > 0) {
        const metrics = this.calculateStreakMetrics(uniqueDates);
        calculatedCurrentStreak = metrics.currentStreak;
        calculatedLongestStreak = metrics.longestStreak;
        lastActiveDate = metrics.lastActiveDate;
      }
    }

    const streak = await this.prisma.streak.findUnique({ where: { userId } });
    if (streak) {
      // Keep longestStreak at the max of existing longestStreak and newly calculated longestStreak
      const finalLongest = Math.max(
        streak.longestStreak,
        calculatedLongestStreak,
      );
      return this.prisma.streak.update({
        where: { userId },
        data: {
          currentStreak: calculatedCurrentStreak,
          longestStreak: finalLongest,
          lastActiveDate: lastActiveDate || streak.lastActiveDate,
        },
      });
    } else {
      return this.prisma.streak.create({
        data: {
          userId,
          currentStreak: calculatedCurrentStreak,
          longestStreak: calculatedLongestStreak,
          lastActiveDate,
        },
      });
    }
  }

  /**
   * Get user streak info
   */
  async getStreak(userId: string) {
    try {
      const streak = await this.recalculateStreakFromSteps(userId);

      // Calculate next milestone
      const milestones = [7, 30, 100, 365];
      const nextMilestone =
        milestones.find((m) => m > streak.currentStreak) || null;
      const daysToMilestone = nextMilestone
        ? nextMilestone - streak.currentStreak
        : null;

      return {
        currentStreak: streak.currentStreak,
        longestStreak: streak.longestStreak,
        lastActiveDate: streak.lastActiveDate,
        nextMilestone,
        daysToMilestone,
      };
    } catch (error) {
      // Concurrency fallback
      const streak = await this.prisma.streak.findUnique({
        where: { userId },
      });
      if (streak) {
        const milestones = [7, 30, 100, 365];
        const nextMilestone =
          milestones.find((m) => m > streak.currentStreak) || null;
        const daysToMilestone = nextMilestone
          ? nextMilestone - streak.currentStreak
          : null;
        return {
          currentStreak: streak.currentStreak,
          longestStreak: streak.longestStreak,
          lastActiveDate: streak.lastActiveDate,
          nextMilestone,
          daysToMilestone,
        };
      }
      throw error;
    }
  }

  /**
   * Get all levels
   */
  async getLevels() {
    const levels = await this.prisma.level.findMany({
      orderBy: { levelNumber: "asc" },
    });
    return levels;
  }

  /**
   * Get all achievements with user progress
   */
  async getAchievements(userId: string) {
    // First, update all achievement progress based on current user stats
    await this.checkAchievements(userId);

    // Get all achievements
    const achievements = await this.prisma.achievement.findMany({
      where: { isActive: true },
      orderBy: [
        { category: "asc" },
        { stepsRequired: "asc" },
        { streakRequired: "asc" },
      ],
    });

    // Get user's achievement records (now includes progress)
    const userAchievements = await this.prisma.userAchievement.findMany({
      where: { userId },
      select: {
        achievementId: true,
        unlocked: true,
        unlockedAt: true,
        progress: true,
        currentValue: true,
      },
    });

    const userAchievementMap = new Map(
      userAchievements.map((ua) => [ua.achievementId, ua]),
    );

    // Enrich achievements with user progress
    return achievements.map((achievement) => {
      const userAchievement = userAchievementMap.get(achievement.id);
      const unlocked = userAchievement?.unlocked || false;
      const progress = userAchievement?.progress || 0;

      return {
        ...achievement,
        unlocked,
        unlockedAt: userAchievement?.unlockedAt,
        progress: unlocked ? 100 : progress,
        currentValue: userAchievement?.currentValue || 0,
      };
    });
  }

  /**
   * Check and unlock new achievements
   */
  async checkAchievements(userId: string) {
    // Self-heal streak from step history to ensure perfect consistency with the calendar
    const streak = await this.recalculateStreakFromSteps(userId);

    // Get user stats
    const [stepsTotal, wallet, challengesCompleted, friendships] =
      await Promise.all([
        this.prisma.step.aggregate({
          where: { userId },
          _sum: { stepCount: true },
        }),
        this.prisma.wallet.findUnique({ where: { userId } }),
        this.prisma.userChallenge.count({
          where: { userId, status: "COMPLETED" },
        }),
        this.prisma.friendship.count({
          where: { userId, status: "ACCEPTED" },
        }),
      ]);

    const lifetimeSteps = stepsTotal._sum.stepCount || 0;
    const currentStreak = streak.currentStreak;
    const longestStreak = streak.longestStreak;
    const lifetimeCoins = wallet?.lifetimePoints || 0;

    // Get all active achievements
    const achievements = await this.prisma.achievement.findMany({
      where: { isActive: true },
    });

    let unlockedCount = 0;

    for (const achievement of achievements) {
      // Calculate progress and check if unlocked
      const { progress, currentValue, unlocked } =
        this.calculateAchievementProgress(achievement, {
          lifetimeSteps,
          currentStreak,
          longestStreak,
          friendships,
          challengesCompleted,
          lifetimeCoins,
        });

      // Get existing record
      const existing = await this.prisma.userAchievement.findUnique({
        where: {
          userId_achievementId: {
            userId,
            achievementId: achievement.id,
          },
        },
      });

      const wasUnlocked = existing?.unlocked || false;

      // Upsert the achievement progress
      await this.prisma.userAchievement.upsert({
        where: {
          userId_achievementId: {
            userId,
            achievementId: achievement.id,
          },
        },
        create: {
          userId,
          achievementId: achievement.id,
          unlocked,
          progress,
          currentValue,
          unlockedAt: unlocked ? new Date() : null,
        },
        update: {
          progress,
          currentValue,
          unlocked,
          unlockedAt:
            unlocked && !wasUnlocked ? new Date() : existing?.unlockedAt,
        },
      });

      // Award points if newly unlocked
      if (unlocked && !wasUnlocked && achievement.pointsReward > 0) {
        await this.addPoints(
          userId,
          achievement.pointsReward,
          TransactionType.MILESTONE,
          `🏆 Achievement unlocked: ${achievement.name}`,
        );
        unlockedCount++;

        this.logger.log(
          `User ${userId} unlocked achievement: ${achievement.name}`,
        );

        this.notificationsService
          .createAndNotify(
            userId,
            "New Badge Unlocked! 🥇",
            `You've earned the ${achievement.name} badge!`,
            "BADGE_UNLOCKED",
          )
          .catch((e) => {
            // eslint-disable-next-line no-console
            console.error("Push failed", e);
          });
      }
    }

    return unlockedCount;
  }

  // ==========================================
  // REWARDS CATALOG & REDEMPTION
  // ==========================================

  /**
   * Get rewards catalog with eligibility check
   */
  async getRewardsCatalog(userId: string, category?: string) {
    const wallet = await this.getWallet(userId);

    const where: any = { isActive: true };
    if (category) {
      where.category = category.toUpperCase();
    }

    const rewards = await this.prisma.reward.findMany({
      where,
      orderBy: [{ coinCost: "asc" }],
    });

    return rewards.map(
      (reward: { coinCost: number; availableStock: number }) => ({
        ...reward,
        canAfford: wallet.balance >= reward.coinCost,
        inStock: reward.availableStock === -1 || reward.availableStock > 0,
      }),
    );
  }

  /**
   * Get single reward details
   */
  async getRewardDetails(rewardId: string, userId: string) {
    const wallet = await this.getWallet(userId);

    const reward = await this.prisma.reward.findUnique({
      where: { id: rewardId },
    });

    if (!reward) {
      throw new Error("Reward not found");
    }

    return {
      ...reward,
      canAfford: wallet.balance >= reward.coinCost,
      inStock: reward.availableStock === -1 || reward.availableStock > 0,
    };
  }

  /**
   * Redeem a reward
   */
  async redeemReward(userId: string, rewardId: string) {
    return this.prisma.$transaction(async (tx) => {
      const wallet = await tx.wallet.findUnique({
        where: { userId },
      });

      if (!wallet) {
        throw new Error("Wallet not found");
      }

      const reward = await tx.reward.findUnique({
        where: { id: rewardId },
      });

      if (!reward) {
        throw new Error("Reward not found");
      }

      if (!reward.isActive) {
        throw new Error("Reward is no longer available");
      }

      if (wallet.balance < reward.coinCost) {
        throw new Error("Insufficient coins");
      }

      if (reward.availableStock !== -1 && reward.availableStock <= 0) {
        throw new Error("Reward is out of stock");
      }

      // Generate voucher code
      const voucherCode = this.generateVoucherCode();

      // Calculate expiry (30 days from now by default, or reward expiry)
      const expiresAt =
        reward.expiryDate || new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

      // Create redemption record
      const redemption = await tx.userRedemption.create({
        data: {
          userId,
          rewardId,
          coinCost: reward.coinCost,
          voucherCode,
          expiresAt,
        },
        include: { reward: true },
      });

      // Deduct coins
      await tx.wallet.update({
        where: { userId },
        data: { balance: { decrement: reward.coinCost } },
      });

      // Create transaction record
      await tx.transaction.create({
        data: {
          userId,
          type: "REDEMPTION",
          points: -reward.coinCost,
          description: `Redeemed: ${reward.title}`,
        },
      });

      // Decrement stock if not unlimited
      if (reward.availableStock !== -1) {
        await tx.reward.update({
          where: { id: rewardId },
          data: { availableStock: { decrement: 1 } },
        });
      }

      return {
        success: true,
        redemption,
        newBalance: wallet.balance - reward.coinCost,
        voucherCode,
      };
    });
  }

  /**
   * Get user's redeemed rewards (My Offers)
   */
  async getMyOffers(userId: string, status?: string) {
    const where: any = { userId };
    if (status) {
      where.status = status.toUpperCase();
    }

    return this.prisma.userRedemption.findMany({
      where,
      include: { reward: true },
      orderBy: { redeemedAt: "desc" },
    });
  }

  /**
   * Generate voucher code
   */
  private generateVoucherCode(): string {
    const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    let code = "STEP-";
    for (let i = 0; i < 8; i++) {
      code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return code;
  }

  /**
   * Seed demo rewards
   */
  async seedDemoRewards() {
    const rewards = [
      {
        title: "10% Off Nike Store",
        description: "Get 10% discount on your next Nike purchase",
        coinCost: 500,
        category: "FITNESS" as any,
        partnerName: "Nike",
        availableStock: 100,
        totalStock: 100,
      },
      {
        title: "Free Starbucks Coffee",
        description: "Enjoy a free tall drink of your choice",
        coinCost: 300,
        category: "FOOD" as any,
        partnerName: "Starbucks",
        availableStock: 50,
        totalStock: 50,
      },
      {
        title: "1 Month Spotify Premium",
        description: "Stream millions of songs ad-free",
        coinCost: 1000,
        category: "ENTERTAINMENT" as any,
        partnerName: "Spotify",
        availableStock: -1,
        totalStock: -1,
      },
      {
        title: "$5 Amazon Gift Card",
        description: "Use on any Amazon purchase",
        coinCost: 750,
        category: "SHOPPING" as any,
        partnerName: "Amazon",
        availableStock: 200,
        totalStock: 200,
      },
      {
        title: "Yoga Mat (Limited Edition)",
        description: "Premium eco-friendly yoga mat",
        coinCost: 2500,
        category: "FITNESS" as any,
        partnerName: "Wellnex Store",
        availableStock: 10,
        totalStock: 10,
        isLimitedEdition: true,
      },
      {
        title: "Smoothie King BOGO",
        description: "Buy one get one free smoothie",
        coinCost: 400,
        category: "FOOD" as any,
        partnerName: "Smoothie King",
        availableStock: 75,
        totalStock: 75,
      },
    ];

    for (const reward of rewards) {
      await this.prisma.reward.create({ data: reward });
    }

    return { message: "Demo rewards seeded", count: rewards.length };
  }

  /**
   * Force rewards sync processing immediately (Manual / Admin Trigger).
   * Processes streaks, achievements, coins, and quest progress.
   */
  async forceRewardsSync(userId?: string) {
    const now = new Date();
    const year = now.getUTCFullYear();
    const month = String(now.getUTCMonth() + 1).padStart(2, "0");
    const day = String(now.getUTCDate()).padStart(2, "0");
    const dateStr = `${year}-${month}-${day}T00:00:00.000Z`;

    const where: any = {
      date: new Date(dateStr),
    };
    if (userId) {
      where.userId = userId;
    }

    const todaySteps = await this.prisma.step.findMany({
      where,
    });

    this.logger.log(
      `Force rewards sync triggered manually. Found ${todaySteps.length} records to process...`,
    );

    const processedUsers = [];
    for (const stepData of todaySteps) {
      try {
        const result = await this.processStepRewards(
          stepData.userId,
          stepData.stepCount,
          now,
        );
        processedUsers.push({
          userId: stepData.userId,
          steps: stepData.stepCount,
          pointsAwarded: result.pointsEarned,
        });
      } catch (err) {
        this.logger.error(
          `Failed to process rewards for user ${stepData.userId}: ${err.message}`,
        );
      }
    }

    return {
      message: `Force rewards sync completed. Processed ${todaySteps.length} users.`,
      processedCount: todaySteps.length,
      details: processedUsers,
    };
  }

  private calculateStreakMetrics(uniqueDates: string[]) {
    let currentStreak = 0;
    let longestStreak = 1;
    let tempStreak = 1;
    let lastActiveDate: Date | null = null;

    if (uniqueDates.length === 0)
      return { currentStreak: 0, longestStreak: 0, lastActiveDate: null };

    for (let i = 1; i < uniqueDates.length; i++) {
      const prevDate = new Date(uniqueDates[i - 1]);
      const currDate = new Date(uniqueDates[i]);
      const diffDays = Math.ceil(
        Math.abs(currDate.getTime() - prevDate.getTime()) / 86400000,
      );

      if (diffDays === 1) {
        tempStreak++;
        if (tempStreak > longestStreak) longestStreak = tempStreak;
      } else if (diffDays > 1) {
        tempStreak = 1;
      }
    }

    const now = new Date();
    const todayLocal = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;
    const todayUtc = now.toISOString().split("T")[0];

    const yesterday = new Date(now);
    yesterday.setDate(now.getDate() - 1);
    const yesterdayLocal = `${yesterday.getFullYear()}-${String(yesterday.getMonth() + 1).padStart(2, "0")}-${String(yesterday.getDate()).padStart(2, "0")}`;
    const yesterdayUtc = new Date(Date.now() - 86400000)
      .toISOString()
      .split("T")[0];

    const lastDateStr = uniqueDates.at(-1)!;
    lastActiveDate = new Date(lastDateStr + "T00:00:00.000Z");

    if (
      [todayLocal, todayUtc, yesterdayLocal, yesterdayUtc].includes(lastDateStr)
    ) {
      currentStreak = tempStreak;
    }

    return { currentStreak, longestStreak, lastActiveDate };
  }

  private calculateAchievementProgress(achievement: any, stats: any) {
    let progress = 0,
      currentValue = 0,
      unlocked = false;

    if (achievement.stepsRequired) {
      currentValue = stats.lifetimeSteps;
      progress = Math.min(
        100,
        Math.floor((currentValue / achievement.stepsRequired) * 100),
      );
      unlocked = currentValue >= achievement.stepsRequired;
    } else if (achievement.streakRequired) {
      currentValue = Math.max(stats.currentStreak, stats.longestStreak);
      progress = Math.min(
        100,
        Math.floor((currentValue / achievement.streakRequired) * 100),
      );
      unlocked = currentValue >= achievement.streakRequired;
    } else if (achievement.targetValue) {
      if (achievement.category === "SOCIAL") currentValue = stats.friendships;
      else if (achievement.category === "CHALLENGE")
        currentValue = stats.challengesCompleted;
      else if (achievement.category === "COINS")
        currentValue = stats.lifetimeCoins;

      progress = Math.min(
        100,
        Math.floor((currentValue / achievement.targetValue) * 100),
      );
      unlocked = currentValue >= achievement.targetValue;
    }

    return { progress, currentValue, unlocked };
  }
}

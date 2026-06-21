import { Injectable, NotFoundException, ConflictException } from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { RedisService } from "../redis/redis.service";
import { CreateUserDto, UpdateUserDto } from "./dto/user.dto";
import { TransactionType, Prisma } from "@prisma/client";

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
  ) {}

  /**
   * Find user by ID
   */
  async findById(id: string) {
    return this.prisma.user.findUnique({
      where: { id },
      include: {
        wallet: true,
        streak: true,
      },
    });
  }

  /**
   * Find user by phone or email
   */
  async findByIdentifier(identifier: string) {
    return this.prisma.user.findFirst({
      where: {
        OR: [{ phone: identifier }, { email: identifier }],
      },
      include: {
        wallet: true,
        streak: true,
      },
    });
  }

  /**
   * Create new user with referral code
   */
  async create(dto: CreateUserDto) {
    const referralCode = this.generateReferralCode();

    let user;
    try {
      user = await this.prisma.user.create({
        data: {
          phone: dto.phone,
          email: dto.email,
          name: dto.name,
          referralCode,
          referredBy: dto.referredBy,
          wallet: {
            create: {
              balance: 0,
              lifetimePoints: 0,
            },
          },
          streak: {
            create: {
              currentStreak: 0,
              longestStreak: 0,
            },
          },
        },
        include: {
          wallet: true,
          streak: true,
        },
      });
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === "P2002"
      ) {
        const target = (error.meta?.target as string[]) || [];
        if (target.includes("phone")) {
          throw new ConflictException(
            "Phone number is already registered to another account",
          );
        }
        if (target.includes("email")) {
          throw new ConflictException(
            "Email is already registered to another account",
          );
        }
        throw new ConflictException("Unique constraint failed");
      }
      throw error;
    }

    // Initialize all achievements for the new user (with unlocked=false)
    await this.initializeUserAchievements(user.id);

    return user;
  }

  /**
   * Initialize all achievements for a user (called on signup)
   */
  async initializeUserAchievements(userId: string) {
    const achievements = await this.prisma.achievement.findMany({
      where: { isActive: true },
    });

    // Create UserAchievement records for all achievements
    for (const achievement of achievements) {
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
          unlocked: false,
        },
        update: {}, // Don't update if exists
      });
    }
  }

  /**
   * Initialize achievements for all existing users (one-time migration)
   */
  async initializeAchievementsForAllUsers() {
    const users = await this.prisma.user.findMany({
      select: { id: true },
    });

    let count = 0;
    for (const user of users) {
      await this.initializeUserAchievements(user.id);
      count++;
    }

    return {
      success: true,
      message: `Initialized achievements for ${count} users`,
      usersProcessed: count,
    };
  }

  /**
   * Apply referral code when user signs up
   */
  async applyReferralCode(userId: string, referralCode: string) {
    // Find the referrer
    const referrer = await this.prisma.user.findUnique({
      where: { referralCode },
    });

    if (!referrer) {
      throw new Error("Invalid referral code");
    }

    if (referrer.id === userId) {
      throw new Error("Cannot use your own referral code");
    }

    // Check if user already has a referrer
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (user?.referredBy) {
      throw new Error("Referral code already applied");
    }

    const REFERRAL_BONUS = 100; // coins

    await this.prisma.$transaction(async (tx) => {
      // Update user with referral info
      await tx.user.update({
        where: { id: userId },
        data: { referredBy: referralCode },
      });

      // Reward the referrer
      await tx.user.update({
        where: { id: referrer.id },
        data: {
          referralCount: { increment: 1 },
          referralCoinsEarned: { increment: REFERRAL_BONUS },
        },
      });

      // Credit referrer's wallet
      await tx.wallet.upsert({
        where: { userId: referrer.id },
        create: {
          userId: referrer.id,
          balance: REFERRAL_BONUS,
          lifetimePoints: REFERRAL_BONUS,
        },
        update: {
          balance: { increment: REFERRAL_BONUS },
          lifetimePoints: { increment: REFERRAL_BONUS },
        },
      });

      // Create transaction for referrer
      await tx.transaction.create({
        data: {
          userId: referrer.id,
          type: TransactionType.REFERRAL,
          points: REFERRAL_BONUS,
          description: `Referral bonus for inviting ${user?.name || "a friend"}`,
        },
      });
    });

    return { success: true, bonus: REFERRAL_BONUS };
  }

  /**
   * Get referral leaderboard (Screen 18)
   */
  async getReferralLeaderboard(limit = 20) {
    const cacheKey = `referral:leaderboard:${limit}`;
    const cached = await this.redis.getCache<any[]>(cacheKey);

    if (cached) {
      return cached;
    }

    const topReferrers = await this.prisma.user.findMany({
      where: { referralCount: { gt: 0 } },
      orderBy: { referralCount: "desc" },
      take: limit,
      select: {
        id: true,
        name: true,
        avatarUrl: true,
        referralCount: true,
        referralCoinsEarned: true,
      },
    });

    const result = topReferrers.map((user, index) => ({
      rank: index + 1,
      ...user,
    }));

    // Cache for 5 minutes (300 seconds)
    await this.redis.setCache(cacheKey, result, 300);

    return result;
  }

  /**
   * Get user's referral stats
   */
  async getReferralStats(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        referralCode: true,
        referralCount: true,
        referralCoinsEarned: true,
      },
    });

    // Get user's rank
    const rank = await this.prisma.user.count({
      where: { referralCount: { gt: user?.referralCount || 0 } },
    });

    return {
      ...user,
      rank: rank + 1,
    };
  }

  /**
   * Generate unique referral code
   */
  private generateReferralCode(): string {
    const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    let code = "STEP";
    for (let i = 0; i < 6; i++) {
      code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return code;
  }

  /**
   * Update user profile
   */
  async update(id: string, dto: UpdateUserDto) {
    const user = await this.findById(id);
    if (!user) {
      throw new NotFoundException("User not found");
    }

    // Auto-compute fitness level when physical stats change
    let fitnessLevel = dto.fitnessLevel;
    if (!fitnessLevel && (dto.heightCm || dto.weightKg || dto.dailyStepGoal)) {
      fitnessLevel = await this.computeFitnessLevel(id);
    }

    const updateData: any = {
      name: dto.name,
      phone: dto.phone,
      email: dto.email,
      heightCm: dto.heightCm,
      weightKg: dto.weightKg,
      age: dto.age,
      dailyStepGoal: dto.dailyStepGoal,
      avatarUrl: dto.avatarUrl,
      activityPreferences: dto.activityPreferences ?? undefined,
      fitnessLevel: fitnessLevel ?? undefined,
      isProfileCreated: dto.isProfileCreated ?? undefined,
    };

    try {
      return await this.prisma.user.update({
        where: { id },
        data: updateData,
        include: {
          wallet: true,
          streak: true,
        },
      });
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === "P2002"
      ) {
        const target = (error.meta?.target as string[]) || [];
        if (target.includes("phone")) {
          throw new ConflictException(
            "Phone number is already registered to another account",
          );
        }
        if (target.includes("email")) {
          throw new ConflictException(
            "Email is already registered to another account",
          );
        }
        throw new ConflictException("Unique constraint failed");
      }
      throw error;
    }
  }

  /**
   * Get user statistics
   */
  async getUserStats(id: string) {
    const user = await this.findById(id);
    if (!user) {
      throw new NotFoundException("User not found");
    }

    // Get total lifetime steps
    const stepsAggregate = await this.prisma.step.aggregate({
      where: { userId: id },
      _sum: {
        stepCount: true,
        caloriesBurned: true,
      },
    });

    // Get total distance
    const distanceAggregate = await this.prisma.step.aggregate({
      where: { userId: id },
      _sum: {
        distanceKm: true,
      },
    });

    // Get best day
    const bestDay = await this.prisma.step.findFirst({
      where: { userId: id },
      orderBy: { stepCount: "desc" },
    });

    // Get achievements count
    const achievementsCount = await this.prisma.userAchievement.count({
      where: { userId: id },
    });

    // Compute and persist fitness level
    const fitnessLevel = await this.computeFitnessLevel(id);
    await this.prisma.user.update({
      where: { id },
      data: { fitnessLevel },
    });

    return {
      fitnessLevel,
      lifetimeSteps: stepsAggregate._sum.stepCount || 0,
      lifetimeCalories: stepsAggregate._sum.caloriesBurned || 0,
      lifetimeDistanceKm: Number(distanceAggregate._sum.distanceKm || 0),
      currentStreak: user.streak?.currentStreak || 0,
      longestStreak: user.streak?.longestStreak || 0,
      achievementsUnlocked: achievementsCount,
      totalPoints: user.wallet?.lifetimePoints || 0,
      currentBalance: user.wallet?.balance || 0,
      bestDaySteps: bestDay?.stepCount || 0,
    };
  }

  /**
   * Compute fitness level based on last 30 days average daily steps
   * Levels: beginner < 5000 | active 5000-7999 | athlete 8000-11999 | elite >= 12000
   */
  async computeFitnessLevel(userId: string): Promise<string> {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const stepsData = await this.prisma.step.findMany({
      where: { userId, date: { gte: thirtyDaysAgo } },
      select: { stepCount: true },
    });

    if (stepsData.length === 0) return "beginner";

    const avgSteps =
      stepsData.reduce((sum, s) => sum + s.stepCount, 0) / stepsData.length;

    if (avgSteps >= 12000) return "elite";
    if (avgSteps >= 8000) return "athlete";
    if (avgSteps >= 5000) return "active";
    return "beginner";
  }

  /**
   * Get list of avatars (seeded if empty)
   */
  async getAvatars() {
    // Check if avatars exist
    const count = await this.prisma.avatar.count();
    if (count === 0) {
      await this.seedAvatars();
    }

    return this.prisma.avatar.findMany({
      where: { isActive: true },
    });
  }

  /**
   * Seed initial avatars
   */
  private async seedAvatars() {
    const avatars = [
      {
        url: "https://api.dicebear.com/7.x/avataaars/png?seed=Felix",
        category: "male",
      },
      {
        url: "https://api.dicebear.com/7.x/avataaars/png?seed=Aneka",
        category: "female",
      },
      {
        url: "https://api.dicebear.com/7.x/avataaars/png?seed=Zoe",
        category: "female",
      },
      {
        url: "https://api.dicebear.com/7.x/avataaars/png?seed=Max",
        category: "male",
      },
      {
        url: "https://api.dicebear.com/7.x/avataaars/png?seed=Buddy",
        category: "neutral",
      },
      {
        url: "https://api.dicebear.com/7.x/avataaars/png?seed=Willow",
        category: "neutral",
      },
      {
        url: "https://api.dicebear.com/7.x/bottts/png?seed=Robot",
        category: "robot",
      },
      {
        url: "https://api.dicebear.com/7.x/fun-emoji/png?seed=Happy",
        category: "emoji",
      },
    ];

    for (const avatar of avatars) {
      await this.prisma.avatar.create({ data: avatar });
    }
  }

  /**
   * Remove sensitive data from user object
   */
  sanitizeUser(user: any) {
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    const { refreshTokens, fcmToken, ...sanitizedUser } = user;
    return sanitizedUser;
  }
  /**
   * Delete user settings (helper)
   */
  async deleteSettings(userId: string) {
    return this.prisma.userSettings.delete({
      where: { userId },
    });
  }

  /**
   * GDPR: Export User Data
   * Returns a JSON object containing all personal data linked to the user.
   */
  async exportData(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        wallet: true,
        settings: true,
        steps: {
          orderBy: { date: "desc" },
          take: 100, // Limit for export payload size
        },
        activities: {
          orderBy: { startTime: "desc" },
          take: 50,
        },
        transactions: {
          orderBy: { createdAt: "desc" },
          take: 50,
        },
      },
    });

    if (!user) throw new NotFoundException("User not found");

    // Sanitize sensitive backend data (like FCM tokens) from export
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    const { refreshTokens, fcmToken, ...safeUser } = user as any;

    return {
      exportDate: new Date().toISOString(),
      data: safeUser,
    };
  }

  /**
   * GDPR: Delete Account
   * Hard-deletes the user and relies on Prisma's onDelete: Cascade to clean up relationships.
   */
  async deleteAccount(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException("User not found");

    // Set a 20-second login cooldown to prevent fast-relogin issues
    if (user.email) {
      await this.redis.setLoginCooldown(user.email, 20);
    }
    if (user.phone) {
      await this.redis.setLoginCooldown(user.phone, 20);
    }

    // Delete user (Prisma cascade will handle steps, wallet, settings, etc.)
    await this.prisma.user.delete({
      where: { id: userId },
    });

    return {
      success: true,
      message: "Account and all associated data permanently deleted.",
    };
  }

  /**
   * Get user settings
   */
  async getSettings(userId: string) {
    let settings = await this.prisma.userSettings.findUnique({
      where: { userId },
    });

    settings ??= await this.prisma.userSettings.create({
      data: { userId },
    });
    return settings;
  }

  /**
   * Update user settings
   */
  async updateSettings(userId: string, data: any) {
    // Remove id and userId from data if present to avoid errors
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    const { id, userId: uid, updatedAt, ...updateData } = data;

    return this.prisma.userSettings.upsert({
      where: { userId },
      update: updateData,
      create: {
        userId,
        ...updateData,
      },
    });
  }
}

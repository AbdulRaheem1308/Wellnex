import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ConflictException,
  Logger,
} from "@nestjs/common";
import { Cron, CronExpression } from "@nestjs/schedule";
import { PrismaService } from "../prisma/prisma.service";
import { RedisService } from "../redis/redis.service";
import { NotificationsService } from "../notifications/notifications.service";
import { CreateChallengeDto, ChallengeStatus } from "./dto/challenge.dto";

@Injectable()
export class ChallengesService {
  private readonly logger = new Logger(ChallengesService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
    private readonly notificationsService: NotificationsService,
  ) {}

  @Cron(CronExpression.EVERY_DAY_AT_MIDNIGHT)
  async generateDailyMissions() {
    this.logger.log("Running CRON: generateDailyMissions");

    const lockKey = "cron:generateDailyMissions";
    const redisClient = this.redis.getClient();

    // Acquire a distributed lock for 10 minutes
    const acquired = await redisClient.set(lockKey, "1", "EX", 600, "NX");
    if (!acquired) {
      this.logger.log("Cron lock already acquired by another node. Skipping.");
      return;
    }

    try {
      // 1. Expire old daily missions
      await this.prisma.challenge.updateMany({
        where: {
          challengeType: "SOLO",
          title: { startsWith: "Daily Mission:" },
          isActive: true,
        },
        data: { isActive: false },
      });

      const todayDateStr = new Date().toISOString().split("T")[0];

      // 2. Create 3 new daily missions
      const missions = [
        {
          title: `Daily Mission: Walk 5K (${todayDateStr})`,
          description: "Walk 5,000 steps today to earn a quick bonus!",
          stepTarget: 5000,
          rewardCoins: 50,
          rewardXp: 20,
          durationDays: 1,
          challengeType: "SOLO" as any,
          difficulty: "EASY" as any,
          imageUrl: "assets/images/missions/daily_walk.png",
        },
        {
          title: `Daily Mission: 10K Push (${todayDateStr})`,
          description: "Hit the 10,000 step mark for a solid reward.",
          stepTarget: 10000,
          rewardCoins: 150,
          rewardXp: 50,
          durationDays: 1,
          challengeType: "SOLO" as any,
          difficulty: "MEDIUM" as any,
          imageUrl: "assets/images/missions/daily_push.png",
        },
        {
          title: `Daily Mission: Watch & Win (${todayDateStr})`,
          description: "Watch 2 ads today to support the app and earn!",
          stepTarget: 2, // Treated as ad views internally in a different hook
          rewardCoins: 30,
          rewardXp: 10,
          durationDays: 1,
          challengeType: "SOLO" as any,
          difficulty: "EASY" as any,
          imageUrl: "assets/images/missions/daily_ads.png",
        },
      ];

      for (const mission of missions) {
        await this.prisma.challenge.create({ data: mission });
      }

      this.logger.log("Daily Missions generated successfully.");
    } catch (err) {
      this.logger.error("Failed to generate daily missions", err.stack);
      // Delete lock on failure so it can be retried if needed
      await redisClient.del(lockKey);
    }
  }

  /**
   * Get all available challenges (active and not expired)
   */
  async findAll() {
    return this.prisma.challenge.findMany({
      where: {
        isActive: true,
        OR: [{ endsAt: null }, { endsAt: { gte: new Date() } }],
      },
      orderBy: { createdAt: "desc" },
    });
  }

  /**
   * Get challenges for a specific user with their status
   */
  async findUserChallenges(userId: string, status?: ChallengeStatus) {
    const where: any = { userId };
    if (status) {
      where.status = status;
    }

    return this.prisma.userChallenge.findMany({
      where,
      include: {
        challenge: true,
      },
      orderBy: { joinedAt: "desc" },
    });
  }

  /**
   * Get a single challenge by ID
   */
  async findOne(id: string) {
    const challenge = await this.prisma.challenge.findUnique({
      where: { id },
      include: {
        _count: {
          select: { userChallenges: true },
        },
      },
    });

    if (!challenge) {
      throw new NotFoundException("Challenge not found");
    }

    return challenge;
  }

  /**
   * Create a new challenge (admin only)
   */
  async create(dto: CreateChallengeDto) {
    return this.prisma.challenge.create({
      data: {
        title: dto.title,
        description: dto.description,
        stepTarget: dto.stepTarget,
        rewardCoins: dto.rewardCoins || 0,
        rewardXp: dto.rewardXp || 0,
        durationDays: dto.durationDays,
        challengeType: dto.challengeType as any,
        difficulty: dto.difficulty as any,
        imageUrl: dto.imageUrl,
        isInviteOnly: dto.isInviteOnly || false,
        maxParticipants: dto.maxParticipants,
        startsAt: dto.startsAt ? new Date(dto.startsAt) : null,
        endsAt: dto.endsAt ? new Date(dto.endsAt) : null,
      },
    });
  }

  /**
   * Join a challenge
   */
  async join(userId: string, challengeId: string) {
    // Check if challenge exists and is active
    const challenge = await this.prisma.challenge.findUnique({
      where: { id: challengeId },
      include: {
        _count: {
          select: { userChallenges: true },
        },
      },
    });

    if (!challenge) {
      throw new NotFoundException("Challenge not found");
    }

    if (!challenge.isActive) {
      throw new BadRequestException("Challenge is no longer active");
    }

    // Check if already joined
    const existing = await this.prisma.userChallenge.findUnique({
      where: {
        userId_challengeId: {
          userId,
          challengeId,
        },
      },
    });

    if (existing) {
      throw new ConflictException("Already joined this challenge");
    }

    // Check max participants
    if (
      challenge.maxParticipants &&
      challenge._count.userChallenges >= challenge.maxParticipants
    ) {
      throw new BadRequestException("Challenge is full");
    }

    // Calculate deadline if durationDays exists
    const deadline = challenge.durationDays
      ? new Date(Date.now() + challenge.durationDays * 24 * 60 * 60 * 1000)
      : null;

    // Create user challenge entry
    const userChallenge = await this.prisma.userChallenge.create({
      data: {
        userId,
        challengeId,
        status: "ONGOING",
        currentSteps: 0,
        progress: 0,
        deadline,
      },
      include: {
        challenge: true,
      },
    });

    await this.notificationsService
      .createAndNotify(
        userId,
        "Challenge Accepted!",
        `You've joined ${challenge.title}. Let's go! 🏃`,
        "CHALLENGE_ACCEPTED",
      )
      .catch((e) => {
        // eslint-disable-next-line no-console
        console.error("Notification failed", e);
      });

    return userChallenge;
  }

  /**
   * Update challenge progress based on user steps
   */
  async updateProgress(
    userId: string,
    challengeId: string,
    stepsToAdd: number,
  ) {
    const userChallenge = await this.prisma.userChallenge.findUnique({
      where: {
        userId_challengeId: {
          userId,
          challengeId,
        },
      },
      include: {
        challenge: true,
      },
    });

    if (!userChallenge) {
      throw new NotFoundException("User challenge not found");
    }

    if (
      userChallenge.status === "NEEDS_REVIVAL" ||
      userChallenge.status === "FAILED"
    ) {
      throw new BadRequestException(
        `Challenge is in ${userChallenge.status} state. Please revive or restart it to continue.`,
      );
    }

    if (userChallenge.status !== "ONGOING") {
      throw new BadRequestException("Challenge is not ongoing");
    }

    const newSteps = userChallenge.currentSteps + stepsToAdd;
    const progress = Math.min(
      100,
      Math.floor((newSteps / userChallenge.challenge.stepTarget) * 100),
    );
    const isCompleted = newSteps >= userChallenge.challenge.stepTarget;

    try {
      const updated = await this.prisma.$transaction(async (tx) => {
        const uc = await tx.userChallenge.update({
          where: {
            userId_challengeId: {
              userId,
              challengeId,
            },
          },
          data: {
            currentSteps: newSteps,
            progress,
            status: isCompleted ? "COMPLETED" : "ONGOING",
            completedAt: isCompleted ? new Date() : null,
          },
          include: {
            challenge: true,
          },
        });

        // Award coins and XP securely within transaction
        if (isCompleted && userChallenge.challenge.rewardCoins > 0) {
          const coins = userChallenge.challenge.rewardCoins;

          await tx.wallet.upsert({
            where: { userId },
            update: {
              balance: { increment: coins },
              lifetimePoints: { increment: coins },
            },
            create: { userId, balance: coins, lifetimePoints: coins },
          });

          await tx.transaction.create({
            data: {
              userId,
              type: "MILESTONE",
              points: coins,
              description: `Reward for completing: ${userChallenge.challenge.title}`,
              metadata: { challengeId: challengeId },
            },
          });
        }

        if (isCompleted) {
          this.notificationsService
            .createAndNotify(
              userId,
              "Challenge Completed! 🎉",
              `You finished ${userChallenge.challenge.title} and earned your rewards!`,
              "CHALLENGE_COMPLETED",
            )
            .catch((e) => {
              // eslint-disable-next-line no-console
              console.error("Notification failed", e);
            });
        }

        return uc;
      });

      return updated;
    } catch (error) {
      this.logger.error(
        `Failed to update challenge progress: ${error.message}`,
      );
      throw new BadRequestException("Failed to update challenge progress");
    }
  }

  /**
   * Get new challenges (not joined by user)
   */
  async findNewChallenges(userId: string) {
    const joinedChallengeIds = await this.prisma.userChallenge.findMany({
      where: { userId },
      select: { challengeId: true },
    });

    const joinedIds = joinedChallengeIds.map(
      (uc: { challengeId: string }) => uc.challengeId,
    );

    return this.prisma.challenge.findMany({
      where: {
        isActive: true,
        id: { notIn: joinedIds },
        OR: [{ endsAt: null }, { endsAt: { gte: new Date() } }],
      },
      orderBy: { createdAt: "desc" },
    });
  }

  /**
   * Seed demo challenges
   */
  async seedDemoChallenges() {
    const challenges = [
      {
        title: "10K Daily Steps",
        description: "Walk 10,000 steps every day for a week",
        stepTarget: 70000,
        rewardCoins: 500,
        rewardXp: 200,
        durationDays: 7,
        challengeType: "SOLO" as any,
        difficulty: "MEDIUM" as any,
      },
      {
        title: "Weekend Warrior",
        description: "Complete 20,000 steps over the weekend",
        stepTarget: 20000,
        rewardCoins: 200,
        rewardXp: 100,
        durationDays: 2,
        challengeType: "SOLO" as any,
        difficulty: "EASY" as any,
      },
      {
        title: "Marathon Month",
        description: "Walk the equivalent of a marathon (42km) in a month",
        stepTarget: 55000,
        rewardCoins: 1000,
        rewardXp: 500,
        durationDays: 30,
        challengeType: "SOLO" as any,
        difficulty: "HARD" as any,
      },
      {
        title: "Team Trek",
        description:
          "Join forces with others to complete 100K steps collectively",
        stepTarget: 100000,
        rewardCoins: 750,
        rewardXp: 350,
        durationDays: 7,
        challengeType: "GROUP" as any,
        difficulty: "MEDIUM" as any,
      },
    ];

    for (const challenge of challenges) {
      await this.prisma.challenge.upsert({
        where: { id: challenge.title.replaceAll(/\s/g, "-").toLowerCase() },
        update: {},
        create: challenge,
      });
    }

    return { message: "Demo challenges seeded" };
  }

  /**
   * Revive an expired challenge
   */
  async revive(userId: string, challengeId: string, method: "COINS" | "AD") {
    const userChallenge = await this.prisma.userChallenge.findUnique({
      where: { userId_challengeId: { userId, challengeId } },
      include: { challenge: true },
    });

    if (!userChallenge) throw new NotFoundException("Challenge not found");

    if (userChallenge.status !== "NEEDS_REVIVAL") {
      throw new BadRequestException("Challenge does not need revival");
    }

    if (userChallenge.progress < 5) {
      throw new BadRequestException(
        "Progress is below 5%. Please restart the challenge instead of reviving.",
      );
    }

    if (method === "COINS") {
      const wallet = await this.prisma.wallet.findUnique({ where: { userId } });
      if (!wallet || wallet.balance < 50) {
        throw new BadRequestException(
          "Insufficient coins for revival (need 50)",
        );
      }
      await this.prisma.wallet.update({
        where: { userId },
        data: { balance: { decrement: 50 } },
      });
      await this.prisma.transaction.create({
        data: {
          userId,
          type: "REVIVAL",
          points: -50,
          description: `Revived challenge: ${userChallenge.challenge.title}`,
        },
      });
    }

    // Calculate new deadline based on extension
    let extensionHours = userChallenge.challenge.revivalExtensionHours;
    if (!extensionHours && userChallenge.challenge.durationDays) {
      // Intelligent fallback: 25% of total duration, minimum 24 hours
      const fallback = Math.floor(
        userChallenge.challenge.durationDays * 24 * 0.25,
      );
      extensionHours = Math.max(24, fallback);
    } else if (!extensionHours) {
      extensionHours = 24;
    }

    const newDeadline = new Date(Date.now() + extensionHours * 60 * 60 * 1000);

    return this.prisma.userChallenge.update({
      where: { userId_challengeId: { userId, challengeId } },
      data: {
        status: "ONGOING",
        deadline: newDeadline,
        revivalCount: { increment: 1 },
      },
      include: { challenge: true },
    });
  }

  /**
   * Restart a challenge (Free if progress < 5%)
   */
  async restart(userId: string, challengeId: string) {
    const userChallenge = await this.prisma.userChallenge.findUnique({
      where: { userId_challengeId: { userId, challengeId } },
      include: { challenge: true },
    });

    if (!userChallenge) throw new NotFoundException("Challenge not found");

    if (userChallenge.progress >= 5) {
      throw new BadRequestException(
        "Progress is 5% or more. Please use the revive option instead.",
      );
    }

    const deadline = userChallenge.challenge.durationDays
      ? new Date(
          Date.now() +
            userChallenge.challenge.durationDays * 24 * 60 * 60 * 1000,
        )
      : null;

    return this.prisma.userChallenge.update({
      where: { userId_challengeId: { userId, challengeId } },
      data: {
        status: "ONGOING",
        currentSteps: 0,
        progress: 0,
        deadline,
        revivalCount: 0,
      },
    });
  }
}

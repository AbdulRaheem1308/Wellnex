import { Injectable, BadRequestException, Logger } from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { ConfigService } from "@nestjs/config";
import { SyncStepsDto } from "./dto/steps.dto";
import { RewardsService } from "../rewards/rewards.service";
import { PostHogService } from "../analytics/posthog.service";
import { RedisService } from "../redis/redis.service";
import { Queue } from "bullmq";
import { InjectQueue } from "@nestjs/bullmq";

// ── Anti-cheat thresholds ────────────────────────────────────────────────────
// World record daily step count is ~53,491 (documented).
// Hard cap at 60,000 — any claim above this is physically impossible.
// Soft flag at 30,000 — legitimate but unusual; logged for review.
const MAX_STEPS_PER_DAY = 60_000;
const SUSPICIOUS_STEPS_THRESHOLD = 30_000;
// ─────────────────────────────────────────────────────────────────────────────

@Injectable()
export class StepsService {
  private readonly logger = new Logger(StepsService.name);
  private readonly caloriesPerStep: number;
  private readonly kmPerStep: number;

  constructor(
    private readonly prisma: PrismaService,
    private readonly configService: ConfigService,
    private readonly rewardsService: RewardsService,
    private readonly postHog: PostHogService,
    private readonly redisService: RedisService,
    @InjectQueue("steps-processing") private readonly stepsQueue: Queue,
  ) {
    this.caloriesPerStep = Number.parseFloat(
      this.configService.get("CALORIES_PER_STEP", "0.04"),
    );
    this.kmPerStep = Number.parseFloat(
      this.configService.get("KM_PER_STEP", "0.000762"),
    );
  }

  /**
   * Sync step data from device.
   * Uses "highest wins" strategy to prevent double-counting across sources.
   * Server-side validation rejects physically impossible step counts.
   */
  async syncSteps(userId: string, dto: SyncStepsDto) {
    // ── Server-Side Anti-Cheat Validation ───────────────────────────────

    await this.validateSyncRequest(userId, dto);
    // ─────────────────────────────────────────────────────────────────────

    const date = new Date(dto.date);
    date.setHours(0, 0, 0, 0);

    const step = await this.prisma.$transaction(async (tx) => {
      // Check if a record already exists for this day
      const existing = await tx.step.findUnique({
        where: {
          userId_date: { userId, date },
        },
      });

      // Use the higher step count to avoid overlap between multiple sources
      const effectiveStepCount = existing
        ? Math.max(existing.stepCount, dto.stepCount)
        : dto.stepCount;

      // Calculate derived values from the winning step count
      const caloriesBurned = Math.round(
        effectiveStepCount * this.caloriesPerStep,
      );
      const distanceKm = Number.parseFloat(
        (effectiveStepCount * this.kmPerStep).toFixed(2),
      );

      // Determine which source provided the highest count
      const effectiveSource =
        existing && existing.stepCount >= dto.stepCount
          ? existing.source
          : dto.source || "manual";

      // Upsert step record with the highest value
      return tx.step.upsert({
        where: {
          userId_date: { userId, date },
        },
        update: {
          stepCount: effectiveStepCount,
          caloriesBurned,
          distanceKm,
          activeMinutes: Math.max(
            existing?.activeMinutes || 0,
            dto.activeMinutes || 0,
          ),
          source: effectiveSource,
          synced: true,
        },
        create: {
          userId,
          date,
          stepCount: effectiveStepCount,
          caloriesBurned,
          distanceKm,
          activeMinutes: dto.activeMinutes || 0,
          source: effectiveSource,
          synced: true,
        },
      });
    });

    this.logger.log(
      `🟢 STEP SYNC: User ${userId} synced ${dto.stepCount} steps from ${dto.source || "manual"} (Effective count: ${step.stepCount}, Device: ${dto.deviceIdentifier})`,
    );

    // Queue background job for streaks, achievements, rewards, corporate leaderboard updates, and analytics
    await this.stepsQueue.add("process-sync", {
      userId,
      effectiveStepCount: step.stepCount,
      date: date.toISOString(),
      effectiveSource: step.source,
    });

    return step;
  }

  /**
   * Ensure user has demo data if empty
   */
  private async ensureUserData(_userId: string) {
    // Disabled: We no longer auto-generate mock data for new users.
    return;
  }

  /**
   * Get today's steps
   */
  async getTodaySteps(userId: string) {
    await this.ensureUserData(userId);

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const step = await this.prisma.step.findUnique({
      where: {
        userId_date: {
          userId,
          date: today,
        },
      },
    });

    // Get user's goal
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { dailyStepGoal: true },
    });

    const stepCount = step?.stepCount || 0;
    const goal = user?.dailyStepGoal || 10000;

    const year = today.getFullYear();
    const month = String(today.getMonth() + 1).padStart(2, "0");
    const day = String(today.getDate()).padStart(2, "0");

    return {
      date: `${year}-${month}-${day}`,
      stepCount,
      caloriesBurned: step?.caloriesBurned || 0,
      distanceKm: step?.distanceKm ? Number(step.distanceKm) : 0,
      activeMinutes: step?.activeMinutes || 0,
      goal,
      progress: Math.min(Math.round((stepCount / goal) * 100), 100),
      goalReached: stepCount >= goal,
    };
  }

  /**
   * Get step history with pagination
   */
  async getHistory(userId: string, page: number = 1, limit: number = 30) {
    const skip = (page - 1) * limit;

    const [steps, total] = await Promise.all([
      this.prisma.step.findMany({
        where: { userId },
        orderBy: { date: "desc" },
        take: limit,
        skip,
      }),
      this.prisma.step.count({ where: { userId } }),
    ]);

    return {
      data: steps,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  /**
   * Get weekly summary
   */
  async getWeeklySummary(userId: string) {
    await this.ensureUserData(userId);

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    // Get start of week (Monday)
    const startOfWeek = new Date(today);
    const dayOfWeek = today.getDay();
    const diff = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
    startOfWeek.setDate(today.getDate() - diff);

    // To make query timezone-safe, add a 1-day safety buffer on both ends of the query bounds.
    // This ensures the database returns all possible matching records, and then in-memory
    // matching by exact local date string filters correctly.
    const queryStart = new Date(startOfWeek.getTime() - 24 * 60 * 60 * 1000);
    const queryEnd = new Date(today.getTime() + 24 * 60 * 60 * 1000);

    const steps = await this.prisma.step.findMany({
      where: {
        userId,
        date: {
          gte: queryStart,
          lte: queryEnd,
        },
      },
      orderBy: { date: "asc" },
    });

    // Create daily breakdown
    const dailyData = [];
    for (let i = 0; i < 7; i++) {
      const date = new Date(startOfWeek);
      date.setDate(startOfWeek.getDate() + i);

      // Use local date string for the target daily breakdown keys
      const year = date.getFullYear();
      const month = String(date.getMonth() + 1).padStart(2, "0");
      const day = String(date.getDate()).padStart(2, "0");
      const dateStr = `${year}-${month}-${day}`;

      // Match using UTC date format because @db.Date column returned from database
      // is represented as midnight UTC in the Date object.
      const dayData = steps.find((s) => {
        const sDateStr = s.date.toISOString().split("T")[0];
        return sDateStr === dateStr;
      });

      dailyData.push({
        date: dateStr,
        dayName: date.toLocaleDateString("en-US", { weekday: "short" }),
        stepCount: dayData?.stepCount || 0,
        caloriesBurned: dayData?.caloriesBurned || 0,
      });
    }

    // Calculate totals for ONLY the 7 days of the active week to avoid any buffer spillover
    const totalSteps = dailyData.reduce((sum, d) => sum + d.stepCount, 0);
    const totalCalories = dailyData.reduce(
      (sum, d) => sum + d.caloriesBurned,
      0,
    );
    const totalDistance = dailyData.reduce((sum, d) => {
      const match = steps.find(
        (s) => s.date.toISOString().split("T")[0] === d.date,
      );
      return sum + (match ? Number(match.distanceKm) : 0);
    }, 0);
    const avgSteps = Math.round(totalSteps / 7);

    return {
      startDate: startOfWeek.toISOString().split("T")[0],
      endDate: today.toISOString().split("T")[0],
      totalSteps,
      totalCalories,
      totalDistanceKm: Number.parseFloat(totalDistance.toFixed(2)),
      averageSteps: avgSteps,
      activeDays: steps.length,
      dailyBreakdown: dailyData,
    };
  }

  /**
   * Get monthly summary
   */
  async getMonthlySummary(userId: string, year?: number, month?: number) {
    const now = new Date();
    const targetYear = year || now.getFullYear();
    const targetMonth = month || now.getMonth() + 1;

    const startOfMonth = new Date(targetYear, targetMonth - 1, 1);
    const endOfMonth = new Date(targetYear, targetMonth, 0);

    const steps = await this.prisma.step.findMany({
      where: {
        userId,
        date: {
          gte: startOfMonth,
          lte: endOfMonth,
        },
      },
      orderBy: { date: "asc" },
    });

    const { totalSteps, totalCalories, totalDistance, avgSteps, bestDay } =
      this.calculateMonthlyTotals(steps);
    const weeklyBreakdown = this.calculateWeeklyBreakdown(steps);

    return {
      year: targetYear,
      month: targetMonth,
      monthName: startOfMonth.toLocaleDateString("en-US", { month: "long" }),
      totalSteps,
      totalCalories,
      totalDistanceKm: Number.parseFloat(totalDistance.toFixed(2)),
      averageSteps: avgSteps,
      activeDays: steps.length,
      totalDaysInMonth: endOfMonth.getDate(),
      bestDay: bestDay
        ? {
            date: (() => {
              const d = bestDay.date;
              const year = d.getFullYear();
              const month = String(d.getMonth() + 1).padStart(2, "0");
              const day = String(d.getDate()).padStart(2, "0");
              return `${year}-${month}-${day}`;
            })(),
            stepCount: bestDay.stepCount,
          }
        : null,
      weeklyBreakdown,
    };
  }

  private async validateSyncRequest(userId: string, dto: SyncStepsDto) {
    if (!dto.deviceIdentifier) {
      throw new BadRequestException(
        "Device identifier is required for step synchronization.",
      );
    }

    const boundDevice = await this.prisma.device.findFirst({
      where: { userId, identifier: dto.deviceIdentifier, isActive: true },
    });

    if (!boundDevice) {
      this.logger.warn(
        `🚨 SECURITY VIOLATION: User ${userId} attempted step sync from unauthorized device: ${dto.deviceIdentifier}`,
      );
      throw new BadRequestException(
        "Step synchronization is only allowed from a registered, active bound device.",
      );
    }

    await this.validateStepCountLimits(userId, dto.stepCount);

    if (dto.nonce) {
      const isUnique = await this.redisService.setNonce(dto.nonce, 86400);
      if (!isUnique) {
        this.logger.warn(
          `🚨 REPLAY DETECTED: Nonce ${dto.nonce} already processed. Rejecting.`,
        );
        throw new BadRequestException("Request replay detected.");
      }
    }

    if (dto.timestamp) {
      const timeDiff = Math.abs(Date.now() - dto.timestamp);
      if (timeDiff > 300000) {
        this.logger.warn(
          `🚨 TIME DRIFT: Request timestamp differs by ${timeDiff}ms. Rejecting.`,
        );
        throw new BadRequestException("Request expired or timestamp invalid.");
      }
    }

    this.validateIntegrity(userId, dto.integrity);
  }

  private async validateStepCountLimits(userId: string, stepCount: number) {
    if (stepCount < 0) {
      throw new BadRequestException("Step count cannot be negative.");
    }
    if (stepCount > MAX_STEPS_PER_DAY) {
      this.logger.warn(
        `🚨 ANTI-CHEAT: User ${userId} claimed ${stepCount} steps. Rejecting.`,
      );
      throw new BadRequestException(
        `Step count exceeds maximum of ${MAX_STEPS_PER_DAY}.`,
      );
    }
    if (stepCount > SUSPICIOUS_STEPS_THRESHOLD) {
      this.logger.warn(
        `⚠️ SUSPICIOUS: User ${userId} reported ${stepCount} steps. Flagged.`,
      );
      // Fire and forget so we don't block sync unnecessarily, but catch errors
      this.prisma.anomaly.create({
        data: {
          userId,
          type: 'SYSTEM_FLAG',
          severity: 'HIGH',
          description: `Suspiciously high step count reported: ${stepCount} steps in a single sync window.`,
          metadata: { stepCount },
          status: 'PENDING',
        }
      }).catch(err => this.logger.error('Failed to log anomaly', err));
    }
  }

  private validateIntegrity(userId: string, integrity?: any) {
    if (!integrity) return;

    if (integrity.isJailBroken) {
      this.logger.warn(
        `🚨 JAILBROKEN DEVICE: Rejected steps from user ${userId}`,
      );
      throw new BadRequestException(
        "Jailbroken or rooted devices are blocked.",
      );
    }
    if (integrity.isMockLocation) {
      this.logger.warn(
        `🚨 LOCATION SPOOFING: Rejected steps from user ${userId}`,
      );
      throw new BadRequestException("Location spoofing is blocked.");
    }
  }

  private calculateMonthlyTotals(steps: any[]) {
    const totalSteps = steps.reduce((sum, s) => sum + s.stepCount, 0);
    const totalCalories = steps.reduce((sum, s) => sum + s.caloriesBurned, 0);
    const totalDistance = steps.reduce(
      (sum, s) => sum + Number(s.distanceKm),
      0,
    );
    const avgSteps =
      steps.length > 0 ? Math.round(totalSteps / steps.length) : 0;

    const bestDay = steps.reduce(
      (max, s) => (s.stepCount > (max?.stepCount || 0) ? s : max),
      steps[0] || null,
    );

    return { totalSteps, totalCalories, totalDistance, avgSteps, bestDay };
  }

  private calculateWeeklyBreakdown(steps: any[]) {
    const weeks = [];
    for (const step of steps) {
      const stepDate = new Date(step.date);
      const weekNum = Math.floor((stepDate.getDate() - 1) / 7);

      if (!weeks[weekNum]) {
        weeks[weekNum] = { weekNumber: weekNum + 1, steps: 0, calories: 0 };
      }
      weeks[weekNum].steps += step.stepCount;
      weeks[weekNum].calories += step.caloriesBurned;
    }
    return weeks.filter(Boolean);
  }
}

import { Injectable, Logger } from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { NotificationsService } from "./notifications.service";
import { Cron, CronExpression } from "@nestjs/schedule";

@Injectable()
export class NotificationsCronService {
  private readonly logger = new Logger(NotificationsCronService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationsService: NotificationsService,
  ) {}

  /**
   * Daily Motivation Reminder
   * Runs every day at 18:00 (6 PM) server time.
   * Finds users who have daily reminders enabled and haven't reached their daily step goal.
   */
  @Cron("0 18 * * *") // 6:00 PM every day
  async sendDailyReminders() {
    this.logger.log("Starting daily motivation reminders cron job...");

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    try {
      // Find all users who have dailyReminders enabled (or setting doesn't exist yet so it defaults to true)
      const users = await this.prisma.user.findMany({
        where: {
          isActive: true,
          fcmToken: { not: null },
          OR: [
            { settings: null },
            { settings: { dailyReminders: true, pushNotifications: true } },
          ],
        },
        select: {
          id: true,
          dailyStepGoal: true,
          steps: {
            where: { date: today },
            select: { stepCount: true },
          },
        },
      });

      let remindersSent = 0;

      for (const user of users) {
        const currentSteps = user.steps[0]?.stepCount || 0;
        const goal = user.dailyStepGoal || 10000;

        if (currentSteps < goal) {
          const remaining = goal - currentSteps;

          // Only send if they have a reasonable amount left, to not spam people who haven't moved at all if they aren't using the app today
          // Actually, let's just send it to everyone who hasn't hit it to encourage them
          let message = `You're only ${remaining} steps away from your daily goal! Let's get stepping! 🚶‍♂️`;

          if (currentSteps === 0) {
            message = `Don't forget your daily walk! Even a short stroll makes a big difference. 🏃‍♀️`;
          } else if (remaining < 2000) {
            message = `Almost there! Just ${remaining} more steps to crush your goal! 🔥`;
          }

          // Use sendPushToUser (which honors settings and handles invalid tokens)
          await this.notificationsService.sendPushToUser(
            user.id,
            "Daily Goal Reminder",
            message,
            { type: "reminder" },
          );

          remindersSent++;
        }
      }

      this.logger.log(
        `Daily motivation reminders completed. Sent to ${remindersSent} users.`,
      );
    } catch (error) {
      this.logger.error("Failed to run daily reminders cron job", error);
    }
  }

  /**
   * Timeline Enforcer
   * Runs every hour to check for expired Challenges and Quests
   */
  @Cron(CronExpression.EVERY_HOUR)
  async enforceTimelines() {
    this.logger.log("Starting timeline enforcement...");
    const now = new Date();

    try {
      // 1. Expire ONGOING challenges -> NEEDS_REVIVAL
      const expiredChallenges = await this.prisma.userChallenge.findMany({
        where: { status: "ONGOING", deadline: { lte: now } },
        include: { challenge: true },
      });

      for (const uc of expiredChallenges) {
        let graceHours = uc.challenge.gracePeriodHours;
        if (!graceHours && uc.challenge.durationDays) {
          graceHours = Math.max(
            24,
            Math.floor(uc.challenge.durationDays * 24 * 0.15),
          );
        } else if (!graceHours) {
          graceHours = 24;
        }

        const graceDeadline = new Date(
          Date.now() + graceHours * 60 * 60 * 1000,
        );

        await this.prisma.userChallenge.update({
          where: { id: uc.id },
          data: { status: "NEEDS_REVIVAL", deadline: graceDeadline },
        });

        this.notificationsService
          .sendPushToUser(
            uc.userId,
            "Time's Up! ⏰",
            `Your time for ${uc.challenge.title} has run out. You have ${graceHours}h to revive your progress!`,
          )
          .catch(() => {});
      }

      // 2. Expire NEEDS_REVIVAL challenges -> FAILED
      await this.prisma.userChallenge.updateMany({
        where: { status: "NEEDS_REVIVAL", deadline: { lte: now } },
        data: { status: "FAILED" },
      });

      // 3. Expire IN_PROGRESS quests -> NEEDS_REVIVAL
      const expiredQuests = await this.prisma.userQuest.findMany({
        where: { status: "IN_PROGRESS", deadline: { lte: now } },
        include: { quest: { include: { stages: true } } },
      });

      for (const uq of expiredQuests) {
        const stage = uq.quest.stages[uq.currentStageIndex];
        let graceHours = stage?.gracePeriodHours;
        if (!graceHours && stage?.durationDays) {
          graceHours = Math.max(24, Math.floor(stage.durationDays * 24 * 0.15));
        } else if (!graceHours) {
          graceHours = 24;
        }

        const graceDeadline = new Date(
          Date.now() + graceHours * 60 * 60 * 1000,
        );

        await this.prisma.userQuest.update({
          where: { id: uq.id },
          data: { status: "NEEDS_REVIVAL", deadline: graceDeadline },
        });

        this.notificationsService
          .sendPushToUser(
            uq.userId,
            "Quest Stage Expired ⏰",
            `Your time for stage ${uq.currentStageIndex + 1} has run out. Revive it to continue!`,
          )
          .catch(() => {});
      }

      // 4. Expire NEEDS_REVIVAL quests -> FAILED
      await this.prisma.userQuest.updateMany({
        where: { status: "NEEDS_REVIVAL", deadline: { lte: now } },
        data: { status: "FAILED" },
      });

      this.logger.log("Timeline enforcement completed.");
    } catch (e) {
      this.logger.error("Error enforcing timelines", e);
    }
  }

  /**
   * Smart Expiration Reminders (Dynamic Heuristic)
   * Runs every hour to notify users 24h before expiry, tailored to their peak activity hour.
   */
  @Cron(CronExpression.EVERY_HOUR)
  async sendSmartReminders() {
    this.logger.log("Starting Smart Reminders...");
    const now = new Date();
    const in24Hours = new Date(Date.now() + 24 * 60 * 60 * 1000);

    try {
      const expiringChallenges = await this.prisma.userChallenge.findMany({
        where: { status: "ONGOING", deadline: { gt: now, lte: in24Hours } },
        include: { challenge: true },
      });

      for (const uc of expiringChallenges) {
        // We will store reminder state in AppConfig to keep it simple and DB-backed
        const configKey = `reminder_sent_challenge_${uc.id}`;
        const alreadySent = await this.prisma.appConfig.findUnique({
          where: { key: configKey },
        });
        if (alreadySent) continue;

        // Dynamic Heuristic: Find user's peak step hour
        let targetHour = 18; // Default 6 PM
        try {
          const peakResult = await this.prisma.$queryRaw<
            { peak_hour: number }[]
          >`
            SELECT EXTRACT(HOUR FROM "updatedAt") AS peak_hour 
            FROM "steps" 
            WHERE "userId" = ${uc.userId}
            GROUP BY peak_hour 
            ORDER BY SUM("stepCount") DESC 
            LIMIT 1
          `;
          if (
            Array.isArray(peakResult) &&
            peakResult.length > 0 &&
            peakResult[0].peak_hour
          ) {
            targetHour = Number(peakResult[0].peak_hour);
            if (targetHour < 9 || targetHour > 20) targetHour = 18;
          }
        } catch (e) {
          // Ignore errors and fallback to 18
        }

        const currentHour = new Date().getHours();

        // If current hour matches their peak hour OR there's less than 3 hours left, send it!
        const hoursLeft =
          (uc.deadline!.getTime() - Date.now()) / (1000 * 60 * 60);
        if (currentHour === targetHour || hoursLeft <= 3) {
          await this.notificationsService
            .sendPushToUser(
              uc.userId,
              "Expiring Soon! ⏳",
              `Don't lose your progress! ${uc.challenge.title} expires in less than 24 hours.`,
            )
            .catch(() => {});

          await this.prisma.appConfig.create({
            data: { key: configKey, value: "sent" },
          });
        }
      }
      this.logger.log("Smart Reminders completed.");
    } catch (e) {
      this.logger.error("Error sending smart reminders", e);
    }
  }
}

import { Test, TestingModule } from "@nestjs/testing";
import { Logger } from "@nestjs/common";
import { NotificationsCronService } from "./notifications.cron.service";
import { PrismaService } from "../prisma/prisma.service";
import { NotificationsService } from "./notifications.service";

jest.spyOn(Logger.prototype, "log").mockImplementation(() => undefined);
jest.spyOn(Logger.prototype, "error").mockImplementation(() => undefined);

describe("NotificationsCronService", () => {
  let service: NotificationsCronService;

  const mockPrisma: any = {
    user: {
      findMany: jest.fn(),
    },
    userChallenge: {
      findMany: jest.fn(),
      update: jest.fn(),
      updateMany: jest.fn(),
    },
    userQuest: {
      findMany: jest.fn(),
      update: jest.fn(),
      updateMany: jest.fn(),
    },
    appConfig: {
      findUnique: jest.fn(),
      create: jest.fn(),
    },
    $queryRaw: jest.fn(),
  };

  const mockNotificationsService = {
    sendPushToUser: jest.fn().mockResolvedValue(undefined),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        NotificationsCronService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: NotificationsService, useValue: mockNotificationsService },
      ],
    }).compile();

    service = module.get<NotificationsCronService>(NotificationsCronService);
    jest.clearAllMocks();
  });

  it("should be defined", () => {
    expect(service).toBeDefined();
  });

  describe("sendDailyReminders", () => {
    it("should skip users who have already reached their goal", async () => {
      mockPrisma.user.findMany.mockResolvedValueOnce([
        { id: "u1", dailyStepGoal: 5000, steps: [{ stepCount: 6000 }] },
      ]);

      await service.sendDailyReminders();

      expect(mockNotificationsService.sendPushToUser).not.toHaveBeenCalled();
    });

    it("should send general reminder to user who hasn't moved", async () => {
      mockPrisma.user.findMany.mockResolvedValueOnce([
        { id: "u1", dailyStepGoal: 10000, steps: [] },
      ]);

      await service.sendDailyReminders();

      expect(mockNotificationsService.sendPushToUser).toHaveBeenCalledWith(
        "u1",
        "Daily Goal Reminder",
        expect.stringContaining("daily walk"),
        { type: "reminder" },
      );
    });

    it("should send 'almost there' reminder when under 2000 steps remain", async () => {
      mockPrisma.user.findMany.mockResolvedValueOnce([
        { id: "u1", dailyStepGoal: 10000, steps: [{ stepCount: 8500 }] },
      ]);

      await service.sendDailyReminders();

      expect(mockNotificationsService.sendPushToUser).toHaveBeenCalledWith(
        "u1",
        "Daily Goal Reminder",
        expect.stringContaining("Almost there"),
        { type: "reminder" },
      );
    });

    it("should send generic motivation reminder for users with some steps but far from goal", async () => {
      mockPrisma.user.findMany.mockResolvedValueOnce([
        { id: "u1", dailyStepGoal: 10000, steps: [{ stepCount: 4000 }] },
      ]);

      await service.sendDailyReminders();

      expect(mockNotificationsService.sendPushToUser).toHaveBeenCalledWith(
        "u1",
        "Daily Goal Reminder",
        expect.stringContaining("6000 steps away"),
        { type: "reminder" },
      );
    });

    it("should use default goal of 10000 if user has none set", async () => {
      mockPrisma.user.findMany.mockResolvedValueOnce([
        { id: "u1", dailyStepGoal: null, steps: [] },
      ]);

      await service.sendDailyReminders();

      expect(mockNotificationsService.sendPushToUser).toHaveBeenCalledWith(
        "u1",
        "Daily Goal Reminder",
        expect.any(String),
        { type: "reminder" },
      );
    });

    it("should handle and log error if prisma throws", async () => {
      mockPrisma.user.findMany.mockRejectedValueOnce(new Error("DB Error"));

      await expect(service.sendDailyReminders()).resolves.toBeUndefined();
    });

    it("should process multiple users and send correct count", async () => {
      mockPrisma.user.findMany.mockResolvedValueOnce([
        { id: "u1", dailyStepGoal: 10000, steps: [{ stepCount: 2000 }] },
        { id: "u2", dailyStepGoal: 5000, steps: [{ stepCount: 5000 }] }, // goal reached
        { id: "u3", dailyStepGoal: 8000, steps: [] },
      ]);

      await service.sendDailyReminders();

      expect(mockNotificationsService.sendPushToUser).toHaveBeenCalledTimes(2);
      expect(mockNotificationsService.sendPushToUser).toHaveBeenCalledWith(
        "u1",
        expect.any(String),
        expect.any(String),
        expect.any(Object),
      );
      expect(mockNotificationsService.sendPushToUser).toHaveBeenCalledWith(
        "u3",
        expect.any(String),
        expect.any(String),
        expect.any(Object),
      );
    });
  });
  describe("enforceTimelines", () => {
    it("should expire ONGOING challenges and transition them to NEEDS_REVIVAL", async () => {
      mockPrisma.userChallenge.findMany.mockResolvedValueOnce([
        {
          id: "uc1",
          userId: "u1",
          challenge: { durationDays: 1, title: "Test" },
        },
      ]);
      mockPrisma.userChallenge.update.mockResolvedValueOnce({});
      mockPrisma.userChallenge.updateMany.mockResolvedValueOnce({});
      mockPrisma.userQuest.findMany.mockResolvedValueOnce([]);
      mockPrisma.userQuest.updateMany.mockResolvedValueOnce({});

      await service.enforceTimelines();

      expect(mockPrisma.userChallenge.update).toHaveBeenCalledWith(
        expect.objectContaining({ where: { id: "uc1" } }),
      );
      expect(mockNotificationsService.sendPushToUser).toHaveBeenCalled();
    });

    it("should expire NEEDS_REVIVAL challenges and quests to FAILED", async () => {
      mockPrisma.userChallenge.findMany.mockResolvedValueOnce([]);
      mockPrisma.userChallenge.updateMany.mockResolvedValueOnce({});
      mockPrisma.userQuest.findMany.mockResolvedValueOnce([]);
      mockPrisma.userQuest.updateMany.mockResolvedValueOnce({});

      await service.enforceTimelines();

      expect(mockPrisma.userChallenge.updateMany).toHaveBeenCalledWith(
        expect.objectContaining({ data: { status: "FAILED" } }),
      );
      expect(mockPrisma.userQuest.updateMany).toHaveBeenCalledWith(
        expect.objectContaining({ data: { status: "FAILED" } }),
      );
    });

    it("should expire IN_PROGRESS quests and transition them to NEEDS_REVIVAL", async () => {
      mockPrisma.userChallenge.findMany.mockResolvedValueOnce([]);
      mockPrisma.userChallenge.updateMany.mockResolvedValueOnce({});
      mockPrisma.userQuest.findMany.mockResolvedValueOnce([
        {
          id: "uq1",
          userId: "u1",
          currentStageIndex: 0,
          quest: { stages: [{ durationDays: 1 }] },
        },
      ]);
      mockPrisma.userQuest.update.mockResolvedValueOnce({});
      mockPrisma.userQuest.updateMany.mockResolvedValueOnce({});

      await service.enforceTimelines();

      expect(mockPrisma.userQuest.update).toHaveBeenCalledWith(
        expect.objectContaining({ where: { id: "uq1" } }),
      );
      expect(mockNotificationsService.sendPushToUser).toHaveBeenCalled();
    });
  });

  describe("sendSmartReminders", () => {
    it("should send smart reminders based on dynamic heuristic", async () => {
      mockPrisma.userChallenge.findMany.mockResolvedValueOnce([
        {
          id: "uc1",
          userId: "u1",
          challenge: { title: "Test" },
          deadline: new Date(Date.now() + 2 * 60 * 60 * 1000),
        }, // 2 hours left
      ]);
      mockPrisma.appConfig.findUnique.mockResolvedValueOnce(null);
      mockPrisma.$queryRaw.mockResolvedValueOnce([{ peak_hour: 18 }]);
      mockPrisma.appConfig.create.mockResolvedValueOnce({});

      await service.sendSmartReminders();

      expect(mockNotificationsService.sendPushToUser).toHaveBeenCalled();
      expect(mockPrisma.appConfig.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: { key: "reminder_sent_challenge_uc1", value: "sent" },
        }),
      );
    });

    it("should skip if reminder already sent", async () => {
      mockPrisma.userChallenge.findMany.mockResolvedValueOnce([
        { id: "uc1", userId: "u1", challenge: { title: "Test" } },
      ]);
      mockPrisma.appConfig.findUnique.mockResolvedValueOnce({
        key: "reminder_sent_challenge_uc1",
      });

      await service.sendSmartReminders();

      expect(mockPrisma.$queryRaw).not.toHaveBeenCalled();
    });
  });
});

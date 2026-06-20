import { Test, TestingModule } from "@nestjs/testing";
import { NotificationsService } from "./notifications.service";
import { PrismaService } from "../prisma/prisma.service";
import * as admin from "firebase-admin";
import { Logger } from "@nestjs/common";
import { Resend } from "resend";

jest.spyOn(Logger.prototype, "error").mockImplementation(() => undefined);
jest.spyOn(Logger.prototype, "warn").mockImplementation(() => undefined);
jest.spyOn(Logger.prototype, "log").mockImplementation(() => undefined);

jest.mock("firebase-admin", () => {
  const mMessaging = {
    send: jest.fn(),
    sendEachForMulticast: jest.fn(),
  };
  return {
    apps: [],
    initializeApp: jest.fn(),
    credential: {
      cert: jest.fn(),
    },
    messaging: jest.fn(() => mMessaging),
  };
});

jest.mock("resend", () => ({
  Resend: jest.fn().mockImplementation(() => ({
    emails: {
      send: jest.fn(),
    },
  })),
}));

describe("NotificationsService", () => {
  let service: NotificationsService;
  let prismaService: PrismaService;
  let mMessaging: any;
  let mResend: any;

  beforeEach(async () => {
    jest.clearAllMocks();
    (admin as any).apps = [];
    mMessaging = admin.messaging();
    mResend = new Resend();

    global.fetch = jest.fn();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        NotificationsService,
        {
          provide: PrismaService,
          useValue: {
            user: {
              update: jest.fn(),
              findUnique: jest.fn(),
              updateMany: jest.fn(),
              findMany: jest.fn(),
            },
            notification: {
              create: jest.fn(),
              findMany: jest.fn(),
              updateMany: jest.fn(),
              update: jest.fn(),
              delete: jest.fn(),
            },
          },
        },
      ],
    }).compile();

    service = module.get<NotificationsService>(NotificationsService);
    (service as any).resendClient = mResend;
    (service as any).brevoApiKey = "test_brevo";
    prismaService = module.get<PrismaService>(PrismaService);
  });

  afterEach(() => {
    (admin as any).apps = [];
  });

  describe("initialization", () => {
    it("should initialize firebase admin if env var is set", () => {
      process.env.FIREBASE_SERVICE_ACCOUNT_JSON = JSON.stringify({
        projectId: "test",
      });
      new NotificationsService(prismaService);
      expect(admin.initializeApp).toHaveBeenCalled();
      delete process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    });

    it("should not initialize firebase if already initialized", () => {
      (admin as any).apps = [{}];
      new NotificationsService(prismaService);
      expect(admin.initializeApp).not.toHaveBeenCalled();
    });

    it("should catch JSON parse errors for service account", () => {
      process.env.FIREBASE_SERVICE_ACCOUNT_JSON = "invalid-json";
      new NotificationsService(prismaService);
      expect(admin.initializeApp).not.toHaveBeenCalled();
      delete process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    });
  });

  describe("registerFcmToken", () => {
    it("should store fcm token for user", async () => {
      (prismaService.user.update as jest.Mock).mockResolvedValue({});
      const result = await service.registerFcmToken("user1", "token1");
      expect(prismaService.user.update).toHaveBeenCalledWith({
        where: { id: "user1" },
        data: { fcmToken: "token1" },
      });
      expect(result).toEqual({ success: true });
    });
  });

  describe("sendPushToUser", () => {
    beforeEach(() => {
      (service as any).fcmEnabled = true;
    });

    it("should skip if FCM is not enabled", async () => {
      (service as any).fcmEnabled = false;
      await service.sendPushToUser("u1", "title", "body");
      expect(prismaService.user.findUnique).not.toHaveBeenCalled();
    });

    it("should skip if user has no FCM token", async () => {
      (prismaService.user.findUnique as jest.Mock).mockResolvedValue({
        fcmToken: null,
      });
      await service.sendPushToUser("u1", "title", "body");
      expect(mMessaging.send).not.toHaveBeenCalled();
    });

    it("should skip if user has push notifications disabled in settings", async () => {
      (prismaService.user.findUnique as jest.Mock).mockResolvedValue({
        fcmToken: "token1",
        settings: { pushNotifications: false },
      });
      await service.sendPushToUser("u1", "title", "body");
      expect(mMessaging.send).not.toHaveBeenCalled();
    });

    it("should call sendFcmMessage if user has token and push enabled explicitly", async () => {
      (prismaService.user.findUnique as jest.Mock).mockResolvedValue({
        fcmToken: "token1",
        settings: { pushNotifications: true },
      });
      mMessaging.send.mockResolvedValue("msg-id");
      await service.sendPushToUser("u1", "title", "body");
      expect(mMessaging.send).toHaveBeenCalled();
    });
  });

  describe("sendFcmMessage", () => {
    beforeEach(() => {
      (service as any).fcmEnabled = true;
    });

    it("should handle invalid token errors and remove token", async () => {
      const error: any = new Error("Invalid token");
      error.code = "messaging/invalid-registration-token";
      mMessaging.send.mockRejectedValue(error);

      await service.sendFcmMessage("token1", "title", "body");
      expect(prismaService.user.updateMany).toHaveBeenCalledWith({
        where: { fcmToken: "token1" },
        data: { fcmToken: null },
      });
    });

    it("should handle registration-token-not-registered error and remove token", async () => {
      const error: any = new Error("Token not registered");
      error.code = "messaging/registration-token-not-registered";
      mMessaging.send.mockRejectedValue(error);

      await service.sendFcmMessage("token1", "title", "body");
      expect(prismaService.user.updateMany).toHaveBeenCalledWith({
        where: { fcmToken: "token1" },
        data: { fcmToken: null },
      });
    });

    it("should handle general errors gracefully", async () => {
      const error = new Error("General error");
      mMessaging.send.mockRejectedValue(error);

      await service.sendFcmMessage("token1", "title", "body");
      expect(prismaService.user.updateMany).not.toHaveBeenCalled();
    });
  });

  describe("broadcastToAll", () => {
    beforeEach(() => {
      (service as any).fcmEnabled = true;
    });

    it("should stop if no users found", async () => {
      (prismaService.user.findMany as jest.Mock).mockResolvedValue([]);
      await service.broadcastToAll("t", "b");
      expect(mMessaging.sendEachForMulticast).not.toHaveBeenCalled();
    });

    it("should send multicast to batched users", async () => {
      (prismaService.user.findMany as jest.Mock)
        .mockResolvedValueOnce([{ id: "1", fcmToken: "t1" }])
        .mockResolvedValueOnce([]);

      mMessaging.sendEachForMulticast.mockResolvedValue({
        successCount: 1,
        failureCount: 0,
      });

      await service.broadcastToAll("t", "b");
      expect(mMessaging.sendEachForMulticast).toHaveBeenCalledWith(
        expect.objectContaining({ tokens: ["t1"] }),
      );
    });

    it("should handle multicast errors", async () => {
      (prismaService.user.findMany as jest.Mock)
        .mockResolvedValueOnce([{ id: "1", fcmToken: "t1" }])
        .mockResolvedValueOnce([]);
      mMessaging.sendEachForMulticast.mockRejectedValue(new Error("fail"));

      await expect(service.broadcastToAll("t", "b")).resolves.toBeUndefined();
    });
  });

  describe("sendEmail", () => {
    it("should not send email if RESEND_API_KEY is not set", async () => {
      (service as any).resendClient = null;
      const result = await service.sendEmail("test@test.com", "Subj", "<html>");
      expect(result).toBe(false);
    });

    it("should send email successfully", async () => {
      mResend.emails.send.mockResolvedValue({ id: "123" });
      const result = await service.sendEmail("test@test.com", "Subj", "<html>");
      expect(result).toBe(true);
      expect(mResend.emails.send).toHaveBeenCalled();
    });

    it("should handle email send error and fallback to brevo fetch", async () => {
      mResend.emails.send.mockRejectedValue(new Error("Send error"));

      (global.fetch as jest.Mock).mockResolvedValue({
        ok: true,
        json: async () => ({ messageId: "123" }),
      });

      const result = await service.sendEmail("test@test.com", "Subj", "<html>");
      expect(result).toBe(true);
      expect(mResend.emails.send).toHaveBeenCalled();
      expect(global.fetch).toHaveBeenCalledWith(
        "https://api.brevo.com/v3/smtp/email",
        expect.any(Object),
      );
    });
  });

  describe("createAndNotify", () => {
    it("should send push and email via createAndNotify", async () => {
      (service as any).fcmEnabled = true;
      process.env.RESEND_API_KEY = "test_key";
      prismaService.user.findUnique = jest.fn().mockResolvedValue({
        fcmToken: "token123",
        email: "test@test.com",
      });
      mMessaging.send.mockResolvedValue("messages/123");
      mResend.emails.send.mockResolvedValue({ id: "123" });

      await service.createAndNotify("u1", "T", "M", "alert", undefined, true);

      expect(mMessaging.send).toHaveBeenCalled();
      expect(mResend.emails.send).toHaveBeenCalled();
    });
  });

  describe("getUserNotifications", () => {
    it("should return user notifications", async () => {
      const date = new Date();
      (prismaService.notification.findMany as jest.Mock).mockResolvedValue([
        {
          id: "n1",
          title: "t",
          message: "m",
          type: "info",
          isRead: false,
          createdAt: date,
        },
      ]);

      const res = await service.getUserNotifications("u1");
      expect(res).toEqual([
        {
          id: "n1",
          title: "t",
          message: "m",
          type: "info",
          isRead: false,
          createdAt: date,
        },
      ]);
    });
  });

  describe("markAsRead", () => {
    it("should mark all as read", async () => {
      (prismaService.notification.updateMany as jest.Mock).mockResolvedValue(
        {},
      );
      await service.markAsRead("u1", "all");
      expect(prismaService.notification.updateMany).toHaveBeenCalled();
    });

    it("should mark one as read", async () => {
      (prismaService.notification.update as jest.Mock).mockResolvedValue({});
      await service.markAsRead("u1", "n1");
      expect(prismaService.notification.update).toHaveBeenCalled();
    });
  });

  describe("deleteNotification", () => {
    it("should delete one notification", async () => {
      (prismaService.notification.delete as jest.Mock).mockResolvedValue({});
      await service.deleteNotification("u1", "n1");
      expect(prismaService.notification.delete).toHaveBeenCalled();
    });
  });
});

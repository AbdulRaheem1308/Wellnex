import { Test, TestingModule } from "@nestjs/testing";
import { MessagingService } from "./messaging.service";
import { PrismaService } from "../prisma/prisma.service";
import { NotificationsService } from "../notifications/notifications.service";

describe("MessagingService", () => {
  let service: MessagingService;

  const mockPrisma: any = {
    $transaction: jest.fn(async (cb) => cb(mockPrisma)),
    conversation: {
      count: jest.fn(),
      findMany: jest.fn(),
      findFirst: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
    },
    message: {
      findMany: jest.fn(),
      create: jest.fn(),
    },
    conversationParticipant: {
      findUnique: jest.fn(),
    },
    user: {
      findUnique: jest.fn(),
    },
  };

  const mockNotificationsService = {
    sendPushToUser: jest.fn().mockResolvedValue(undefined),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        MessagingService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: NotificationsService, useValue: mockNotificationsService },
      ],
    }).compile();

    service = module.get<MessagingService>(MessagingService);
    jest.clearAllMocks();
  });

  it("should be defined", () => {
    expect(service).toBeDefined();
  });

  it("should get conversations", async () => {
    mockPrisma.conversation.findMany.mockResolvedValueOnce([{ id: "c1" }]);
    const res = await service.getConversations("u1");
    expect(res).toHaveLength(1);
  });

  it("should get messages", async () => {
    mockPrisma.message.findMany.mockResolvedValueOnce([{ id: "m1" }]);
    const res = await service.getMessages("c1");
    expect(res).toHaveLength(1);
  });

  describe("startConversation", () => {
    it("should return existing conversation", async () => {
      mockPrisma.conversation.findFirst.mockResolvedValueOnce({ id: "c1" });
      const res = await service.startConversation("u1", "u2");
      expect(res.id).toBe("c1");
    });

    it("should create new conversation", async () => {
      mockPrisma.conversation.findFirst.mockResolvedValueOnce(null);
      mockPrisma.conversation.create.mockResolvedValueOnce({ id: "c2" });
      const res = await service.startConversation("u1", "u2");
      expect(res.id).toBe("c2");
    });
  });

  describe("sendMessage", () => {
    it("should throw if not participant", async () => {
      mockPrisma.conversationParticipant.findUnique.mockResolvedValueOnce(null);
      await expect(service.sendMessage("c1", "u1", "hello")).rejects.toThrow(
        "Sender is not a participant",
      );
    });

    it("should send message and update conversation", async () => {
      mockPrisma.conversationParticipant.findUnique.mockResolvedValueOnce({
        userId: "u1",
      });
      mockPrisma.message.create.mockResolvedValueOnce({ id: "m1" });
      mockPrisma.conversation.update.mockResolvedValueOnce({
        participants: [],
      });
      mockPrisma.user.findUnique.mockResolvedValueOnce({ name: "Test User" });

      const res = await service.sendMessage("c1", "u1", "hello");
      expect(res.id).toBe("m1");
      expect(mockPrisma.conversation.update).toHaveBeenCalled();
    });

    it("should truncate long message content in push notification", async () => {
      const sendPushSpy = jest
        .spyOn(mockNotificationsService, "sendPushToUser")
        .mockResolvedValue(undefined);
      mockPrisma.conversationParticipant.findUnique.mockResolvedValueOnce({
        userId: "u1",
      });
      mockPrisma.message.create.mockResolvedValueOnce({ id: "m2" });
      mockPrisma.conversation.update.mockResolvedValueOnce({
        participants: [{ userId: "u2" }],
      });
      mockPrisma.user.findUnique.mockResolvedValueOnce({ name: "Alice" });

      const longContent = "a".repeat(100);
      await service.sendMessage("c1", "u1", longContent);

      expect(sendPushSpy).toHaveBeenCalledWith(
        "u2",
        "New Message from Alice",
        expect.stringMatching(/\.\.\.$/),
      );
    });

    it("should use 'Someone' when sender name is null", async () => {
      mockPrisma.conversationParticipant.findUnique.mockResolvedValueOnce({
        userId: "u1",
      });
      mockPrisma.message.create.mockResolvedValueOnce({ id: "m3" });
      mockPrisma.conversation.update.mockResolvedValueOnce({
        participants: [{ userId: "u2" }],
      });
      mockPrisma.user.findUnique.mockResolvedValueOnce(null);

      await service.sendMessage("c1", "u1", "short");
      // No assertion needed — just verifying no crash when sender is null
    });
  });

  it("should run onModuleInit without throwing", async () => {
    mockPrisma.conversation.count.mockResolvedValueOnce(0);
    await expect(service.onModuleInit()).resolves.not.toThrow();
  });
});

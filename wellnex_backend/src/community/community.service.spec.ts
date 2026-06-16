import { Test, TestingModule } from "@nestjs/testing";
import { CommunityService } from "./community.service";
import { PrismaService } from "../prisma/prisma.service";
import { RedisService } from "../redis/redis.service";
import { NotificationsService } from "../notifications/notifications.service";

describe("CommunityService", () => {
  let service: CommunityService;

  const mockPrismaService = {
    feedPost: {
      findMany: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
    },
    feedReaction: {
      findUnique: jest.fn(),
      delete: jest.fn(),
      create: jest.fn(),
    },
    feedComment: {
      create: jest.fn(),
      findMany: jest.fn(),
    },
    $transaction: jest.fn(),
  };

  const mockRedisService = {
    getCache: jest.fn(),
    setCache: jest.fn(),
  };

  const mockNotificationsService = {
    createAndNotify: jest.fn().mockResolvedValue(true),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CommunityService,
        { provide: PrismaService, useValue: mockPrismaService },
        { provide: RedisService, useValue: mockRedisService },
        { provide: NotificationsService, useValue: mockNotificationsService },
      ],
    }).compile();

    service = module.get<CommunityService>(CommunityService);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it("should be defined", () => {
    expect(service).toBeDefined();
  });

  describe("getFeed", () => {
    it("should return cached feed if available and no cursor is provided", async () => {
      mockRedisService.getCache.mockResolvedValueOnce([{ id: "cached-post" }]);
      const result = await service.getFeed(20);
      expect(result).toEqual([{ id: "cached-post" }]);
      expect(mockRedisService.getCache).toHaveBeenCalledWith(
        "community:feed:20",
      );
      expect(mockPrismaService.feedPost.findMany).not.toHaveBeenCalled();
    });

    it("should query db, map counts, and cache result if no cursor and no cache", async () => {
      mockRedisService.getCache.mockResolvedValueOnce(null);
      const mockPosts = [{ id: "1", _count: { reactions: 5, comments: 2 } }];
      mockPrismaService.feedPost.findMany.mockResolvedValueOnce(mockPosts);

      const result = await service.getFeed(20);

      expect(mockPrismaService.feedPost.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          take: 20,
          orderBy: { createdAt: "desc" },
        }),
      );
      expect(result).toEqual([
        {
          id: "1",
          _count: { reactions: 5, comments: 2 },
          likesCount: 5,
          commentsCount: 2,
        },
      ]);
      expect(mockRedisService.setCache).toHaveBeenCalledWith(
        "community:feed:20",
        result,
        120,
      );
    });

    it("should use cursor and skip caching if cursor is provided", async () => {
      const mockPosts = [{ id: "2", _count: { reactions: 0, comments: 0 } }];
      mockPrismaService.feedPost.findMany.mockResolvedValueOnce(mockPosts);

      const result = await service.getFeed(20, "cursor-id");

      expect(mockRedisService.getCache).not.toHaveBeenCalled();
      expect(mockPrismaService.feedPost.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          take: 20,
          skip: 1,
          cursor: { id: "cursor-id" },
        }),
      );
      expect(mockRedisService.setCache).not.toHaveBeenCalled();
      expect(result).toEqual([
        {
          id: "2",
          _count: { reactions: 0, comments: 0 },
          likesCount: 0,
          commentsCount: 0,
        },
      ]);
    });
  });

  describe("createPost", () => {
    it("should create a feed post", async () => {
      mockPrismaService.feedPost.create.mockResolvedValueOnce({ id: "post1" });
      const result = await service.createPost("user1", "content", "type", {
        meta: "data",
      });
      expect(result).toEqual({ id: "post1" });
      expect(mockPrismaService.feedPost.create).toHaveBeenCalledWith({
        data: {
          userId: "user1",
          content: "content",
          type: "type",
          metadata: { meta: "data" },
        },
        include: {
          user: { select: { id: true, name: true, avatarUrl: true } },
        },
      });
    });
  });

  describe("reactToPost", () => {
    it("should remove reaction if it already exists", async () => {
      mockPrismaService.$transaction.mockImplementationOnce(async (cb) => {
        const tx = {
          feedReaction: {
            findUnique: jest.fn().mockResolvedValue({ id: "react1" }),
            delete: jest.fn().mockResolvedValue({}),
          },
          feedPost: {
            update: jest.fn().mockResolvedValue({}),
          },
        };
        return cb(tx);
      });

      const result = await service.reactToPost("user1", "post1");
      expect(result).toEqual({ reacted: false });
    });

    it("should add reaction if it does not exist", async () => {
      mockPrismaService.$transaction.mockImplementationOnce(async (cb) => {
        const tx = {
          feedReaction: {
            findUnique: jest.fn().mockResolvedValue(null),
            create: jest.fn().mockResolvedValue({}),
          },
          feedPost: {
            update: jest.fn().mockResolvedValue({ userId: "otherUser" }),
          },
          user: {
            findUnique: jest.fn().mockResolvedValue({ name: "User1 Name" }),
          },
          notification: {
            create: jest.fn().mockResolvedValue({}),
          },
        };
        return cb(tx);
      });

      const result = await service.reactToPost("user1", "post1", "fire");
      expect(result).toEqual({ reacted: true });
    });

    it("should not notify when user reacts to their own post", async () => {
      mockPrismaService.$transaction.mockImplementationOnce(async (cb) => {
        const tx = {
          feedReaction: {
            findUnique: jest.fn().mockResolvedValue(null),
            create: jest.fn().mockResolvedValue({}),
          },
          feedPost: {
            // userId === reactor, so no notification
            update: jest.fn().mockResolvedValue({ userId: "user1" }),
          },
        };
        return cb(tx);
      });

      const result = await service.reactToPost("user1", "post1", "fire");
      expect(result).toEqual({ reacted: true });
      // createAndNotify should NOT have been called because userId === postOwnerId
      expect(mockNotificationsService.createAndNotify).not.toHaveBeenCalled();
    });
  });

  describe("addComment", () => {
    it("should create comment and increment comment count", async () => {
      mockPrismaService.$transaction.mockImplementationOnce(async (cb) => {
        const tx = {
          feedComment: {
            create: jest.fn().mockResolvedValue({
              id: "comment1",
              user: { name: "Test User" },
            }),
          },
          feedPost: {
            update: jest.fn().mockResolvedValue({ userId: "otherUser" }),
          },
          notification: {
            create: jest.fn().mockResolvedValue({}),
          },
        };
        return cb(tx);
      });

      const result = await service.addComment("user1", "post1", "Great job!");
      expect(result).toEqual({
        id: "comment1",
        user: { name: "Test User" },
      });
    });

    it("should not notify when user comments on their own post", async () => {
      mockPrismaService.$transaction.mockImplementationOnce(async (cb) => {
        const tx = {
          feedComment: {
            create: jest
              .fn()
              .mockResolvedValue({ id: "comment2", user: { name: "User1" } }),
          },
          // userId === commenterId, so no notification
          feedPost: {
            update: jest.fn().mockResolvedValue({ userId: "user1" }),
          },
        };
        return cb(tx);
      });

      const result = await service.addComment("user1", "post1", "My own post!");
      expect(result.id).toBe("comment2");
      expect(mockNotificationsService.createAndNotify).not.toHaveBeenCalled();
    });
  });

  describe("getComments", () => {
    it("should return comments for a post", async () => {
      mockPrismaService.feedComment.findMany.mockResolvedValueOnce([
        { id: "c1" },
      ]);
      const result = await service.getComments("post1");
      expect(result).toEqual([{ id: "c1" }]);
      expect(mockPrismaService.feedComment.findMany).toHaveBeenCalledWith({
        where: { postId: "post1" },
        include: {
          user: { select: { id: true, name: true, avatarUrl: true } },
        },
        orderBy: { createdAt: "asc" },
      });
    });
  });

  describe("postMilestone", () => {
    it("should call createPost", async () => {
      jest
        .spyOn(service, "createPost")
        .mockResolvedValueOnce({ id: "post2" } as any);
      const result = await service.postMilestone(
        "user1",
        "MILESTONE",
        "content",
        {},
      );
      expect(result).toEqual({ id: "post2" });
      expect(service.createPost).toHaveBeenCalledWith(
        "user1",
        "content",
        "MILESTONE",
        {},
      );
    });
  });
});

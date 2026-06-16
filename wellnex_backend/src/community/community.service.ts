import { Injectable } from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { RedisService } from "../redis/redis.service";
import { NotificationsService } from "../notifications/notifications.service";

@Injectable()
export class CommunityService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
    private readonly notificationsService: NotificationsService,
  ) {}

  // Get community feed (Screen 19)
  async getFeed(limit = 20, cursor?: string) {
    const cacheKey = `community:feed:${limit}`;

    // Only cache the first page
    if (!cursor) {
      const cached = await this.redis.getCache<any[]>(cacheKey);
      if (cached) return cached;
    }

    const posts = await this.prisma.feedPost.findMany({
      take: limit,
      ...(cursor && {
        skip: 1,
        cursor: { id: cursor },
      }),
      include: {
        user: {
          select: { id: true, name: true, avatarUrl: true },
        },
        _count: {
          select: { reactions: true, comments: true },
        },
      },
      orderBy: { createdAt: "desc" },
    });

    const result = posts.map((post) => ({
      ...post,
      likesCount: post._count.reactions,
      commentsCount: post._count.comments,
    }));

    // Cache the first page for 2 minutes
    if (!cursor) {
      await this.redis.setCache(cacheKey, result, 120);
    }

    return result;
  }

  // Create a feed post (auto-generated on milestones or manual)
  async createPost(userId: string, content: string, type: any, metadata?: any) {
    return this.prisma.feedPost.create({
      data: {
        userId,
        content,
        type,
        metadata,
      },
      include: {
        user: { select: { id: true, name: true, avatarUrl: true } },
      },
    });
  }

  // React to a post (like, clap, fire)
  async reactToPost(userId: string, postId: string, reactionType = "like") {
    return this.prisma.$transaction(async (tx) => {
      // Toggle reaction
      const existing = await tx.feedReaction.findUnique({
        where: { postId_userId: { postId, userId } },
      });

      if (existing) {
        // Remove reaction
        await tx.feedReaction.delete({ where: { id: existing.id } });
        await tx.feedPost.update({
          where: { id: postId },
          data: { likesCount: { decrement: 1 } },
        });
        return { reacted: false };
      } else {
        // Add reaction
        await tx.feedReaction.create({
          data: { postId, userId, type: reactionType },
        });
        const updatedPost = await tx.feedPost.update({
          where: { id: postId },
          data: { likesCount: { increment: 1 } },
        });

        // Notify post owner
        if (updatedPost.userId !== userId) {
          const liker = await tx.user.findUnique({
            where: { id: userId },
            select: { name: true },
          });
          this.notificationsService
            .createAndNotify(
              updatedPost.userId,
              "New Like! ❤️",
              `${liker?.name || "Someone"} liked your post.`,
              "POST_LIKE",
            )
            .catch((e) => {
              // eslint-disable-next-line no-console
              console.error("Notification failed", e);
            });
        }

        return { reacted: true };
      }
    });
  }

  // Add a comment
  async addComment(userId: string, postId: string, content: string) {
    return this.prisma.$transaction(async (tx) => {
      const comment = await tx.feedComment.create({
        data: { postId, userId, content },
        include: {
          user: { select: { id: true, name: true, avatarUrl: true } },
        },
      });

      const updatedPost = await tx.feedPost.update({
        where: { id: postId },
        data: { commentsCount: { increment: 1 } },
      });

      // Notify post owner
      if (updatedPost.userId !== userId) {
        this.notificationsService
          .createAndNotify(
            updatedPost.userId,
            "New Comment! 💬",
            `${comment.user.name || "Someone"} commented on your post.`,
            "POST_COMMENT",
          )
          .catch((e) => {
            // eslint-disable-next-line no-console
            console.error("Notification failed", e);
          });
      }

      return comment;
    });
  }

  // Get comments for a post
  async getComments(postId: string) {
    return this.prisma.feedComment.findMany({
      where: { postId },
      include: {
        user: { select: { id: true, name: true, avatarUrl: true } },
      },
      orderBy: { createdAt: "asc" },
    });
  }

  // Auto-post milestone (called from other services)
  async postMilestone(
    userId: string,
    type: any,
    content: string,
    metadata?: any,
  ) {
    return this.createPost(userId, content, type, metadata);
  }
}

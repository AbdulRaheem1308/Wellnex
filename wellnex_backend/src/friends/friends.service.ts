import {
  Injectable,
  NotFoundException,
  ConflictException,
  BadRequestException,
} from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { RedisService } from "../redis/redis.service";
import { NotificationsService } from "../notifications/notifications.service";
import * as crypto from "node:crypto";

@Injectable()
export class FriendsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
    private readonly notificationsService: NotificationsService,
  ) {}

  /**
   * Get user's friends list with their step stats
   */
  async getFriends(userId: string) {
    const friendships = await this.prisma.friendship.findMany({
      where: {
        OR: [
          { userId, status: "ACCEPTED" },
          { friendId: userId, status: "ACCEPTED" },
        ],
      },
    });

    // Get friend IDs
    const friendIds = friendships.map(
      (f: { userId: string; friendId: string }) =>
        f.userId === userId ? f.friendId : f.userId,
    );

    if (friendIds.length === 0) return [];

    // Get friend details with today's steps
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const friends = await this.prisma.user.findMany({
      where: { id: { in: friendIds } },
      select: {
        id: true,
        name: true,
        avatarUrl: true,
        steps: {
          where: { date: { gte: today } },
          select: { stepCount: true },
        },
      },
    });

    // Check if boost was sent today to each friend
    const boostsSentToday = await this.prisma.friendBoost.findMany({
      where: {
        senderId: userId,
        sentAt: { gte: today },
      },
      select: { receiverId: true },
    });
    const boostReceiverIds = new Set(
      boostsSentToday.map((b: { receiverId: string }) => b.receiverId),
    );

    return friends.map((friend: any) => ({
      id: friend.id,
      name: friend.name || "Unknown",
      avatarUrl: friend.avatarUrl,
      dailyStepCount: friend.steps.reduce(
        (sum: number, s: any) => sum + s.stepCount,
        0,
      ),
      boostSentToday: boostReceiverIds.has(friend.id),
    }));
  }

  /**
   * Get pending friend requests
   */
  async getPendingRequests(userId: string) {
    const requests = await this.prisma.friendship.findMany({
      where: { friendId: userId, status: "PENDING" },
    });

    const senderIds = requests.map((r: { userId: string }) => r.userId);
    if (senderIds.length === 0) return [];

    const senders = await this.prisma.user.findMany({
      where: { id: { in: senderIds } },
      select: { id: true, name: true, avatarUrl: true },
    });

    return senders;
  }

  /**
   * Search users by name or email
   */
  async searchUsers(userId: string, query: string) {
    if (!query || query.length < 2) return [];

    const users = await this.prisma.user.findMany({
      where: {
        id: { not: userId },
        OR: [
          { name: { contains: query, mode: "insensitive" } },
          { email: { contains: query, mode: "insensitive" } },
        ],
      },
      select: { id: true, name: true, avatarUrl: true },
      take: 20,
    });

    // Check friendship status
    const friendships = await this.prisma.friendship.findMany({
      where: {
        OR: [
          { userId, friendId: { in: users.map((u: { id: string }) => u.id) } },
          {
            friendId: userId,
            userId: { in: users.map((u: { id: string }) => u.id) },
          },
        ],
      },
    });

    const friendshipMap = new Map<string, string>();
    friendships.forEach((f: any) => {
      const otherId = f.userId === userId ? f.friendId : f.userId;
      friendshipMap.set(otherId, f.status);
    });

    return users.map((user: any) => ({
      ...user,
      friendshipStatus: friendshipMap.get(user.id) || null,
    }));
  }

  /**
   * Send friend request
   */
  async sendFriendRequest(userId: string, friendId: string) {
    if (userId === friendId) {
      throw new BadRequestException("Cannot add yourself as friend");
    }

    // Check if friendship already exists
    const existing = await this.prisma.friendship.findFirst({
      where: {
        OR: [
          { userId, friendId },
          { userId: friendId, friendId: userId },
        ],
      },
    });

    if (existing) {
      throw new ConflictException("Friend request already exists");
    }

    const friendship = await this.prisma.friendship.create({
      data: { userId, friendId, status: "PENDING" },
    });

    const sender = await this.prisma.user.findUnique({ where: { id: userId } });
    if (sender) {
      await this.notificationsService
        .createAndNotify(
          friendId,
          "New Friend Request!",
          `${sender.name || "Someone"} wants to connect with you.`,
          "FRIEND_REQUEST",
        )
        .catch((e) => {
          // eslint-disable-next-line no-console
          console.error("Notification failed", e);
        });
    }

    return friendship;
  }

  /**
   * Accept friend request
   */
  async acceptFriendRequest(userId: string, requesterId: string) {
    const request = await this.prisma.friendship.findFirst({
      where: { userId: requesterId, friendId: userId, status: "PENDING" },
    });

    if (!request) {
      throw new NotFoundException("Friend request not found");
    }

    const updated = await this.prisma.friendship.update({
      where: { id: request.id },
      data: { status: "ACCEPTED" },
    });

    const accepter = await this.prisma.user.findUnique({
      where: { id: userId },
    });
    if (accepter) {
      await this.notificationsService
        .createAndNotify(
          requesterId,
          "Friend Request Accepted!",
          `${accepter.name || "Someone"} accepted your friend request.`,
          "FRIEND_ACCEPTED",
        )
        .catch((e) => {
          // eslint-disable-next-line no-console
          console.error("Notification failed", e);
        });
    }

    return updated;
  }

  /**
   * Send boost to a friend (limited per day)
   */
  async sendBoost(userId: string, friendId: string) {
    return this.prisma.$transaction(async (tx) => {
      // Check if already sent today
      const today = new Date();
      today.setHours(0, 0, 0, 0);

      const existingBoost = await tx.friendBoost.findFirst({
        where: {
          senderId: userId,
          receiverId: friendId,
          sentAt: { gte: today },
        },
      });

      if (existingBoost) {
        throw new ConflictException("Boost already sent to this friend today");
      }

      // Check if they are friends
      const friendship = await tx.friendship.findFirst({
        where: {
          status: "ACCEPTED",
          OR: [
            { userId, friendId },
            { userId: friendId, friendId: userId },
          ],
        },
      });

      if (!friendship) {
        throw new BadRequestException("You can only boost friends");
      }

      // Create boost record
      const boost = await tx.friendBoost.create({
        data: { senderId: userId, receiverId: friendId },
      });

      // Award coins to receiver (bonus motivation)
      await tx.wallet.upsert({
        where: { userId: friendId },
        update: { balance: { increment: 5 } },
        create: { userId: friendId, balance: 5, lifetimePoints: 5 },
      });

      // Create transaction
      await tx.transaction.create({
        data: {
          userId: friendId,
          type: "REFERRAL",
          points: 5,
          description: "Received a boost from a friend!",
        },
      });

      const sender = await tx.user.findUnique({ where: { id: userId } });
      if (sender) {
        this.notificationsService
          .createAndNotify(
            friendId,
            "Boost Received!",
            `${sender.name || "A friend"} sent you a boost. Keep stepping! 🔥`,
            "FRIEND_BOOST",
          )
          .catch((e) => {
            // eslint-disable-next-line no-console
            console.error("Notification failed", e);
          });
      }

      return { success: true, boost };
    });
  }

  /**
   * Get mini leaderboard (top friends by steps)
   */
  async getMiniLeaderboard(userId: string, _timeFrame: string = "weekly") {
    const friends = await this.getFriends(userId);

    // Sort by steps and take top 5
    const sortedFriends = [...friends].sort(
      (a: any, b: any) => b.dailyStepCount - a.dailyStepCount,
    );
    return sortedFriends.slice(0, 5).map((f: any, index: number) => ({
      ...f,
      rank: index + 1,
      isTopFriend: index === 0,
    }));
  }

  /**
   * Create invitation with referral code
   */
  async createInvitation(
    userId: string,
    inviteeEmail?: string,
    inviteePhone?: string,
  ) {
    const referralCode = this.generateReferralCode();

    return this.prisma.invitation.create({
      data: {
        inviterId: userId,
        inviteeEmail,
        inviteePhone,
        referralCode,
      },
    });
  }

  /**
   * Get user's sent invitations
   */
  async getInvitations(userId: string) {
    return this.prisma.invitation.findMany({
      where: { inviterId: userId },
      orderBy: { sentAt: "desc" },
    });
  }

  /**
   * Generate referral code
   */
  private generateReferralCode(): string {
    return "REF-" + crypto.randomBytes(3).toString("hex").toUpperCase();
  }

  /**
   * Remove friend
   */
  async removeFriend(userId: string, friendId: string) {
    const friendship = await this.prisma.friendship.findFirst({
      where: {
        OR: [
          { userId, friendId },
          { userId: friendId, friendId: userId },
        ],
      },
    });

    if (!friendship) {
      throw new NotFoundException("Friendship not found");
    }

    await this.prisma.friendship.delete({ where: { id: friendship.id } });
    return { success: true };
  }

  /**
  /**
   * Get global leaderboard (all users)
   */
  async getGlobalLeaderboard(timeFrame: string = "weekly") {
    const cacheKey = `leaderboard:global:${timeFrame}`;

    // 1. Try to fetch from Redis cache first
    const cachedData = await this.redis.getCache<any[]>(cacheKey);
    if (cachedData) {
      return cachedData;
    }

    let result: any[] = [];

    if (timeFrame === "monthly") {
      // Sort by Monthly XP
      const wallets = await this.prisma.wallet.findMany({
        take: 50,
        orderBy: { monthlyXp: "desc" } as any,
        include: {
          user: { select: { id: true, name: true, avatarUrl: true } },
        },
      });
      result = wallets.map((w: any, index) => ({
        id: w.user.id,
        name: w.user.name || "Unknown",
        avatarUrl: w.user.avatarUrl,
        xp: w.monthlyXp,
        todaySteps: w.monthlyXp, // Re-using field for frontend compatibility
        rank: index + 1,
      }));
    } else if (timeFrame === "allTime") {
      // Sort by Lifetime Points
      const wallets = await this.prisma.wallet.findMany({
        take: 50,
        orderBy: { lifetimePoints: "desc" },
        include: {
          user: { select: { id: true, name: true, avatarUrl: true } },
        },
      });
      result = wallets.map((w, index) => ({
        id: w.user.id,
        name: w.user.name || "Unknown",
        avatarUrl: w.user.avatarUrl,
        xp: w.lifetimePoints,
        todaySteps: w.lifetimePoints,
        rank: index + 1,
      }));
    } else {
      // Daily/Weekly - Default to steps (simpler for now, ideally strictly weekly steps)
      const today = new Date();
      today.setHours(0, 0, 0, 0);

      // Fetch users with their step count
      const users = await this.prisma.user.findMany({
        take: 50,
        select: {
          id: true,
          name: true,
          avatarUrl: true,
          steps: {
            where: { date: { gte: today } }, // Only today's steps
            select: { stepCount: true },
          },
        },
      });

      // Calculate steps and sort
      const usersWithSteps = users.map((u: any) => ({
        id: u.id,
        name: u.name || "Unknown",
        avatarUrl: u.avatarUrl,
        todaySteps: u.steps.reduce(
          (sum: number, s: any) => sum + s.stepCount,
          0,
        ),
        xp: u.steps.reduce((sum: number, s: any) => sum + s.stepCount, 0),
      }));
      const sortedUsers = [...usersWithSteps].sort(
        (a: any, b: any) => b.todaySteps - a.todaySteps,
      );
      result = sortedUsers.map((u: any, index: number) => ({
        ...u,
        rank: index + 1,
      }));
    }

    // 2. Store in Redis for 5 minutes (300 seconds) to prevent heavy DB queries
    await this.redis.setCache(cacheKey, result, 300);

    return result;
  }
}

import {
  Injectable,
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { NotificationsService } from "../notifications/notifications.service";

@Injectable()
export class TeamsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationsService: NotificationsService,
  ) {}

  // Get user's teams
  async getMyTeams(userId: string) {
    const memberships = await this.prisma.teamMember.findMany({
      where: { userId },
      include: {
        team: {
          include: {
            members: {
              include: {
                // Include user info if needed
              },
            },
          },
        },
      },
    });

    return memberships.map((m) =>
      this.formatTeam(m.team, m.role === "captain"),
    );
  }

  // Get public teams
  async getPublicTeams(userId: string) {
    // Get user's current team IDs
    const userTeamIds = await this.prisma.teamMember.findMany({
      where: { userId },
      select: { teamId: true },
    });
    const excludeIds = userTeamIds.map((t) => t.teamId);

    const teams = await this.prisma.team.findMany({
      where: {
        isPublic: true,
        id: { notIn: excludeIds },
      },
      include: {
        members: true,
      },
      orderBy: { weeklySteps: "desc" },
      take: 50,
    });

    return teams.map((t) => this.formatTeam(t, false));
  }

  // Get team details
  async getTeamDetails(teamId: string, _userId: string) {
    const team = await this.prisma.team.findUnique({
      where: { id: teamId },
      include: {
        members: {
          orderBy: { weeklySteps: "desc" },
        },
      },
    });

    if (!team) {
      throw new Error("Team not found");
    }

    // Get user names for members
    const userIds = team.members.map((m) => m.userId);
    const users = await this.prisma.user.findMany({
      where: { id: { in: userIds } },
      select: { id: true, name: true, avatarUrl: true },
    });
    const userMap = new Map(users.map((u) => [u.id, u]));

    const captain = userMap.get(team.captainId);

    return {
      id: team.id,
      name: team.name,
      description: team.description,
      imageUrl: team.imageUrl,
      captainId: team.captainId,
      captainName: captain?.name || "Unknown",
      memberCount: team.members.length,
      maxMembers: team.maxMembers,
      totalSteps: team.totalSteps,
      weeklySteps: team.weeklySteps,
      isPublic: team.isPublic,
      inviteCode: team.inviteCode,
      createdAt: team.createdAt,
      members: team.members.map((m) => ({
        id: m.id,
        userId: m.userId,
        name: userMap.get(m.userId)?.name || "Unknown",
        avatarUrl: userMap.get(m.userId)?.avatarUrl,
        steps: m.totalSteps,
        weeklySteps: m.weeklySteps,
        isCaptain: m.role === "captain",
        joinedAt: m.joinedAt,
      })),
    };
  }

  // Create a new team
  async createTeam(
    userId: string,
    data: {
      name: string;
      description?: string;
      maxMembers?: number;
      isPublic?: boolean;
    },
  ) {
    // Create team
    const team = await this.prisma.team.create({
      data: {
        name: data.name,
        description: data.description || "",
        captainId: userId,
        maxMembers: data.maxMembers || 10,
        isPublic: data.isPublic !== false,
      },
    });

    // Add creator as captain
    await this.prisma.teamMember.create({
      data: {
        teamId: team.id,
        userId: userId,
        role: "captain",
      },
    });

    return this.getTeamDetails(team.id, userId);
  }

  // Join a team
  async joinTeam(teamId: string, userId: string, inviteCode?: string) {
    const team = await this.prisma.team.findUnique({
      where: { id: teamId },
      include: { members: true },
    });

    if (!team) {
      throw new Error("Team not found");
    }

    if (team.members.length >= team.maxMembers) {
      throw new Error("Team is full");
    }

    // Check if already a member
    const existing = team.members.find((m) => m.userId === userId);
    if (existing) {
      throw new Error("Already a member");
    }

    // Private team requires invite code
    if (!team.isPublic && team.inviteCode !== inviteCode) {
      throw new Error("Invalid invite code");
    }

    await this.prisma.teamMember.create({
      data: {
        teamId: team.id,
        userId: userId,
        role: "member",
      },
    });

    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (user && team.captainId) {
      await this.notificationsService
        .createAndNotify(
          team.captainId,
          "New Team Member!",
          `${user.name || "A new walker"} just joined your team.`,
          "TEAM_JOIN",
        )
        .catch((e) => {
          // eslint-disable-next-line no-console
          console.error("Notification failed", e);
        });
    }

    return { success: true };
  }

  // Leave a team
  async leaveTeam(teamId: string, userId: string) {
    const team = await this.prisma.team.findUnique({
      where: { id: teamId },
      include: { members: true },
    });

    if (!team) {
      throw new Error("Team not found");
    }

    if (team.captainId === userId) {
      // Find other members to promote the next oldest to captain
      const otherMembers = await this.prisma.teamMember.findMany({
        where: {
          teamId,
          userId: { not: userId },
        },
        orderBy: { joinedAt: "asc" },
      });

      if (otherMembers.length > 0) {
        const nextCaptain = otherMembers[0];
        await this.prisma.$transaction([
          // Update team captain
          this.prisma.team.update({
            where: { id: teamId },
            data: { captainId: nextCaptain.userId },
          }),
          // Update next captain's role to captain
          this.prisma.teamMember.update({
            where: { id: nextCaptain.id },
            data: { role: "captain" },
          }),
          // Delete leaving captain's member record
          this.prisma.teamMember.deleteMany({
            where: { teamId, userId },
          }),
        ]);
      } else {
        // No other members, delete the team cleanly
        await this.prisma.$transaction([
          this.prisma.teamMember.deleteMany({
            where: { teamId },
          }),
          this.prisma.teamChallenge.deleteMany({
            where: { teamId },
          }),
          this.prisma.team.delete({
            where: { id: teamId },
          }),
        ]);
      }
    } else {
      // Standard member leaves the team
      await this.prisma.teamMember.deleteMany({
        where: { teamId, userId },
      });
    }

    return { success: true };
  }

  // Get team challenges
  async getTeamChallenges(teamId: string) {
    const challenges = await this.prisma.teamChallenge.findMany({
      where: { teamId },
      orderBy: { startDate: "desc" },
    });

    return challenges;
  }

  // Initiate a Team Battle
  async initiateBattle(
    challengerTeamId: string,
    opponentTeamId: string,
    userId: string,
  ) {
    if (challengerTeamId === opponentTeamId) {
      throw new BadRequestException("You cannot battle your own team.");
    }

    // Verify challenger is the captain of their team
    const challengerTeam = await this.prisma.team.findUnique({
      where: { id: challengerTeamId },
    });
    if (challengerTeam?.captainId !== userId) {
      throw new ForbiddenException(
        "Only the Team Captain can initiate a battle.",
      );
    }

    // Verify opponent exists
    const opponentTeam = await this.prisma.team.findUnique({
      where: { id: opponentTeamId },
    });
    if (!opponentTeam) {
      throw new NotFoundException("Opponent team not found.");
    }

    // Check if an active battle already exists between these two teams
    const existingBattle = await this.prisma.teamBattle.findFirst({
      where: {
        OR: [
          {
            challengerId: challengerTeamId,
            opponentId: opponentTeamId,
            status: "ACTIVE",
          },
          {
            challengerId: opponentTeamId,
            opponentId: challengerTeamId,
            status: "ACTIVE",
          },
        ],
      },
    });

    if (existingBattle) {
      throw new BadRequestException(
        "An active battle already exists between these teams.",
      );
    }

    const now = new Date();
    const nextWeek = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000); // 7 days from now

    const battle = await this.prisma.teamBattle.create({
      data: {
        challengerId: challengerTeamId,
        opponentId: opponentTeamId,
        status: "ACTIVE",
        startsAt: now,
        endsAt: nextWeek,
      },
    });

    if (opponentTeam?.captainId && challengerTeam) {
      await this.notificationsService
        .createAndNotify(
          opponentTeam.captainId,
          "Team Battle!",
          `${challengerTeam.name} has challenged your team to a step battle! ⚔️`,
          "TEAM_BATTLE",
        )
        .catch((e) => {
          // eslint-disable-next-line no-console
          console.error("Notification failed", e);
        });
    }

    return { success: true, battle };
  }

  // Get team leaderboard
  async getTeamLeaderboard() {
    const teams = await this.prisma.team.findMany({
      where: { isPublic: true },
      include: { members: true },
      orderBy: { weeklySteps: "desc" },
      take: 100,
    });

    return teams.map((t, index) => ({
      id: t.id,
      name: t.name,
      description: t.description,
      memberCount: t.members.length,
      maxMembers: t.maxMembers,
      totalSteps: t.totalSteps,
      weeklySteps: t.weeklySteps,
      rank: index + 1,
    }));
  }

  // Delete a team (with creator checks and active member/challenge restrictions)
  async deleteTeam(teamId: string, userId: string) {
    const team = await this.prisma.team.findUnique({
      where: { id: teamId },
      include: {
        members: true,
        teamChallenges: {
          where: { status: "active" },
        },
      },
    });

    if (!team) {
      throw new NotFoundException("Team not found");
    }

    if (team.captainId !== userId) {
      throw new ForbiddenException(
        "Only the team captain (creator) can delete this team",
      );
    }

    // Restriction 1: Active Challenges
    if (team.teamChallenges.length > 0) {
      throw new BadRequestException(
        "Cannot delete team while it is participating in active challenges.",
      );
    }

    // Restriction 2: Other members are still in the team
    const otherMembers = team.members.filter((m) => m.userId !== userId);
    if (otherMembers.length > 0) {
      throw new BadRequestException(
        "Cannot delete team with active members. Ask members to leave first.",
      );
    }

    // Delete team (Prisma Cascade deletes all team memberships and challenges automatically)
    await this.prisma.team.delete({
      where: { id: teamId },
    });

    return { success: true, message: "Team deleted successfully" };
  }

  // Helper to format team
  private formatTeam(team: any, isCaptain: boolean) {
    return {
      id: team.id,
      name: team.name,
      description: team.description,
      imageUrl: team.imageUrl,
      captainId: team.captainId,
      memberCount: team.members?.length || 0,
      maxMembers: team.maxMembers,
      totalSteps: team.totalSteps,
      weeklySteps: team.weeklySteps,
      isPublic: team.isPublic,
      inviteCode: isCaptain ? team.inviteCode : null,
      createdAt: team.createdAt,
    };
  }
}

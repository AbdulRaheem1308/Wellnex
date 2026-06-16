import { Test, TestingModule } from "@nestjs/testing";
import { TeamsService } from "./teams.service";
import { PrismaService } from "../prisma/prisma.service";
import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from "@nestjs/common";
import { NotificationsService } from "../notifications/notifications.service";

const mockPrismaService: any = {
  teamMember: {
    findMany: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
    deleteMany: jest.fn(),
  },
  team: {
    findMany: jest.fn(),
    findUnique: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
    delete: jest.fn(),
  },
  user: { findMany: jest.fn(), findUnique: jest.fn() },
  teamChallenge: { deleteMany: jest.fn(), findMany: jest.fn() },
  teamBattle: { findFirst: jest.fn(), create: jest.fn() },
  $transaction: jest.fn((queries: any): any => {
    if (typeof queries === "function") {
      return queries(mockPrismaService);
    }
    return Promise.resolve(queries);
  }),
};

describe("TeamsService", () => {
  let service: TeamsService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TeamsService,
        { provide: PrismaService, useValue: mockPrismaService },
        {
          provide: NotificationsService,
          useValue: { createAndNotify: jest.fn().mockResolvedValue(true) },
        },
      ],
    }).compile();
    service = module.get<TeamsService>(TeamsService);
    jest.clearAllMocks();
  });

  it("should be defined", () => {
    expect(service).toBeDefined();
  });

  describe("getMyTeams", () => {
    it("should return properly formatted user teams", async () => {
      mockPrismaService.teamMember.findMany.mockResolvedValue([
        {
          userId: "u1",
          role: "captain",
          team: {
            id: "t1",
            name: "Team 1",
            inviteCode: "CODE1",
            members: [{ id: "m1" }],
          },
        },
      ]);
      const result = await service.getMyTeams("u1");
      expect(result.length).toBe(1);
      expect(result[0].inviteCode).toBe("CODE1");
      expect(result[0].memberCount).toBe(1);
    });
  });

  describe("getPublicTeams", () => {
    it("should return public teams excluding user teams", async () => {
      mockPrismaService.teamMember.findMany.mockResolvedValue([
        { teamId: "t1" },
      ]);
      mockPrismaService.team.findMany.mockResolvedValue([
        { id: "t2", name: "Team 2", members: [] },
      ]);
      const result = await service.getPublicTeams("u1");
      expect(result.length).toBe(1);
      expect(result[0].id).toBe("t2");
    });
  });

  describe("getTeamDetails", () => {
    it("should throw Error if team not found", async () => {
      mockPrismaService.team.findUnique.mockResolvedValue(null);
      await expect(service.getTeamDetails("t1", "u1")).rejects.toThrow(
        "Team not found",
      );
    });
    it("should return formatted team details", async () => {
      mockPrismaService.team.findUnique.mockResolvedValue({
        id: "t1",
        captainId: "u1",
        members: [{ userId: "u1", role: "captain", totalSteps: 100 }],
      });
      mockPrismaService.user.findMany.mockResolvedValue([
        { id: "u1", name: "Captain" },
      ]);
      const result = await service.getTeamDetails("t1", "u1");
      expect(result.captainName).toBe("Captain");
    });
  });

  describe("createTeam", () => {
    it("should create team and add captain", async () => {
      mockPrismaService.team.create.mockResolvedValue({ id: "t1" });
      mockPrismaService.teamMember.create.mockResolvedValue({});
      jest.spyOn(service, "getTeamDetails").mockResolvedValue({} as any);
      await service.createTeam("u1", { name: "New Team", isPublic: false });
      expect(mockPrismaService.team.create).toHaveBeenCalled();
    });
  });

  describe("joinTeam", () => {
    it("should throw Error if team is full", async () => {
      mockPrismaService.team.findUnique.mockResolvedValue({
        maxMembers: 1,
        members: [{ id: "m1" }],
      });
      await expect(service.joinTeam("t1", "u1")).rejects.toThrow(
        "Team is full",
      );
    });

    it("should throw Error if team not found", async () => {
      mockPrismaService.team.findUnique.mockResolvedValue(null);
      await expect(service.joinTeam("t1", "u1")).rejects.toThrow(
        "Team not found",
      );
    });

    it("should throw Error if already a member", async () => {
      mockPrismaService.team.findUnique.mockResolvedValue({
        maxMembers: 10,
        members: [{ userId: "u1" }],
      });
      await expect(service.joinTeam("t1", "u1")).rejects.toThrow(
        "Already a member",
      );
    });

    it("should throw Error if invalid invite code for private team", async () => {
      mockPrismaService.team.findUnique.mockResolvedValue({
        maxMembers: 10,
        isPublic: false,
        inviteCode: "SEC1",
        members: [],
      });
      await expect(service.joinTeam("t1", "u1", "WRONG")).rejects.toThrow(
        "Invalid invite code",
      );
    });

    it("should join team successfully and notify captain", async () => {
      mockPrismaService.team.findUnique.mockResolvedValue({
        id: "t1",
        maxMembers: 10,
        isPublic: true,
        captainId: "captain1",
        members: [],
      });
      mockPrismaService.teamMember.create.mockResolvedValue({});
      mockPrismaService.user.findUnique.mockResolvedValue({
        name: "New Member",
      });
      // Access injected notification service via module
      const res = await service.joinTeam("t1", "u1");
      expect(res.success).toBe(true);
    });

    it("should join private team with correct invite code", async () => {
      mockPrismaService.team.findUnique.mockResolvedValue({
        id: "t1",
        maxMembers: 10,
        isPublic: false,
        inviteCode: "SECRET",
        captainId: "captain1",
        members: [],
      });
      mockPrismaService.teamMember.create.mockResolvedValue({});
      mockPrismaService.user.findUnique.mockResolvedValue(null);
      const res = await service.joinTeam("t1", "u1", "SECRET");
      expect(res.success).toBe(true);
    });
  });

  describe("leaveTeam", () => {
    it("should throw Error if team not found", async () => {
      mockPrismaService.team.findUnique.mockResolvedValue(null);
      await expect(service.leaveTeam("t1", "u1")).rejects.toThrow(
        "Team not found",
      );
    });

    it("should handle standard member leaving", async () => {
      mockPrismaService.team.findUnique.mockResolvedValue({
        id: "t1",
        captainId: "u2",
        members: [{ userId: "u1" }],
      });
      const res = await service.leaveTeam("t1", "u1");
      expect(res.success).toBe(true);
    });

    it("should handle captain leaving and promoting next member", async () => {
      mockPrismaService.team.findUnique.mockResolvedValue({
        id: "t1",
        captainId: "u1",
        members: [{ userId: "u1" }, { userId: "u2" }],
      });
      mockPrismaService.teamMember.findMany.mockResolvedValue([
        { id: "m2", userId: "u2" },
      ]);
      mockPrismaService.$transaction.mockResolvedValue([{}, {}, {}]);
      const res = await service.leaveTeam("t1", "u1");
      expect(res.success).toBe(true);
      expect(mockPrismaService.$transaction).toHaveBeenCalled();
    });

    it("should handle captain leaving with no other members cleanly deleting team", async () => {
      mockPrismaService.team.findUnique.mockResolvedValue({
        id: "t1",
        captainId: "u1",
        members: [{ userId: "u1" }],
      });
      mockPrismaService.teamMember.findMany.mockResolvedValue([]);
      mockPrismaService.$transaction.mockResolvedValue([{}, {}, {}]);
      const res = await service.leaveTeam("t1", "u1");
      expect(res.success).toBe(true);
    });
  });

  describe("getTeamChallenges", () => {
    it("should return team challenges", async () => {
      mockPrismaService.teamChallenge.findMany.mockResolvedValue([
        { id: "c1" },
      ]);
      const res = await service.getTeamChallenges("t1");
      expect(res.length).toBe(1);
    });
  });

  describe("initiateBattle", () => {
    it("should throw BadRequest if same team", async () => {
      await expect(service.initiateBattle("t1", "t1", "u1")).rejects.toThrow(
        BadRequestException,
      );
    });

    it("should throw Forbidden if not captain", async () => {
      mockPrismaService.team.findUnique.mockResolvedValue({ captainId: "u2" });
      await expect(service.initiateBattle("t1", "t2", "u1")).rejects.toThrow(
        ForbiddenException,
      );
    });

    it("should throw NotFound if opponent not found", async () => {
      mockPrismaService.team.findUnique
        .mockResolvedValueOnce({ captainId: "u1" })
        .mockResolvedValueOnce(null);
      await expect(service.initiateBattle("t1", "t2", "u1")).rejects.toThrow(
        NotFoundException,
      );
    });

    it("should throw BadRequest if active battle exists", async () => {
      mockPrismaService.team.findUnique
        .mockResolvedValueOnce({ captainId: "u1" })
        .mockResolvedValueOnce({ id: "t2" });
      mockPrismaService.teamBattle.findFirst.mockResolvedValue({ id: "b1" });
      await expect(service.initiateBattle("t1", "t2", "u1")).rejects.toThrow(
        BadRequestException,
      );
    });

    it("should create a battle successfully", async () => {
      mockPrismaService.team.findUnique
        .mockResolvedValueOnce({ captainId: "u1" })
        .mockResolvedValueOnce({ id: "t2" });
      mockPrismaService.teamBattle.findFirst.mockResolvedValue(null);
      mockPrismaService.teamBattle.create.mockResolvedValue({ id: "bnew" });
      const res = await service.initiateBattle("t1", "t2", "u1");
      expect(res.success).toBe(true);
    });
  });

  describe("getTeamLeaderboard", () => {
    it("should return team leaderboard", async () => {
      mockPrismaService.team.findMany.mockResolvedValue([
        { id: "t1", members: [{}] },
      ]);
      const res = await service.getTeamLeaderboard();
      expect(res.length).toBe(1);
      expect(res[0].rank).toBe(1);
    });
  });

  describe("deleteTeam", () => {
    it("should throw NotFound if team not found", async () => {
      mockPrismaService.team.findUnique.mockResolvedValue(null);
      await expect(service.deleteTeam("t1", "u1")).rejects.toThrow(
        NotFoundException,
      );
    });

    it("should throw Forbidden if not captain", async () => {
      mockPrismaService.team.findUnique.mockResolvedValue({ captainId: "u2" });
      await expect(service.deleteTeam("t1", "u1")).rejects.toThrow(
        ForbiddenException,
      );
    });

    it("should throw BadRequest if active challenges", async () => {
      mockPrismaService.team.findUnique.mockResolvedValue({
        captainId: "u1",
        teamChallenges: [{}],
      });
      await expect(service.deleteTeam("t1", "u1")).rejects.toThrow(
        BadRequestException,
      );
    });

    it("should throw BadRequest if other active members", async () => {
      mockPrismaService.team.findUnique.mockResolvedValue({
        captainId: "u1",
        teamChallenges: [],
        members: [{ userId: "u1" }, { userId: "u2" }],
      });
      await expect(service.deleteTeam("t1", "u1")).rejects.toThrow(
        BadRequestException,
      );
    });

    it("should delete team successfully", async () => {
      mockPrismaService.team.findUnique.mockResolvedValue({
        captainId: "u1",
        teamChallenges: [],
        members: [{ userId: "u1" }],
      });
      const res = await service.deleteTeam("t1", "u1");
      expect(res.success).toBe(true);
    });
  });
});

import { Request, Response, NextFunction } from "express";
import { prisma } from "../config/database";

export const getTeams = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const teams = await prisma.team.findMany({
      include: {
        _count: {
          select: { members: true, teamChallenges: true }
        }
      },
      orderBy: { createdAt: "desc" }
    });
    res.json({ success: true, data: teams });
  } catch (error) {
    next(error);
  }
};

export const deleteTeam = async (req: Request, res: Response, next: NextFunction) => {
  try {
    await prisma.team.delete({ where: { id: req.params.id } });
    res.json({ success: true, message: "Team disbanded successfully." });
  } catch (error) {
    next(error);
  }
};

export const getTeamBattles = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const battles = await prisma.teamBattle.findMany({
      include: {
        challenger: true,
        opponent: true
      },
      orderBy: { createdAt: "desc" }
    });
    res.json({ success: true, data: battles });
  } catch (error) {
    next(error);
  }
};

export const createTeam = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { name, isPrivate } = req.body;
    const team = await prisma.team.create({
      data: { name, totalSteps: 0 }
    });
    res.status(201).json({ success: true, data: team });
  } catch (error) {
    next(error);
  }
};

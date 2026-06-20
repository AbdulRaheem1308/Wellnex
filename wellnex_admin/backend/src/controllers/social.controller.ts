import { Request, Response, NextFunction } from "express";
import { prisma } from "../config/database";

export const getFeedPosts = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const posts = await prisma.feedPost.findMany({
      include: {
        user: true,
        _count: {
          select: { comments: true, reactions: true }
        }
      },
      orderBy: { createdAt: "desc" },
      take: 50
    });
    res.json({ success: true, data: posts });
  } catch (error) {
    next(error);
  }
};

export const deleteFeedPost = async (req: Request, res: Response, next: NextFunction) => {
  try {
    await prisma.feedPost.delete({ where: { id: req.params.id } });
    res.json({ success: true, message: "Post permanently deleted." });
  } catch (error) {
    next(error);
  }
};

export const getInvitations = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const invites = await prisma.invitation.findMany({
      orderBy: { sentAt: "desc" },
      take: 50
    });
    res.json({ success: true, data: invites });
  } catch (error) {
    next(error);
  }
};

export const createFeedPost = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { content, imageUrl } = req.body;
    // For admin posts, we can assign it to a random admin user or create a system user, but we need a valid userId.
    // Let's find any user to act as the "admin publisher" for now, or require a userId.
    const user = await prisma.user.findFirst();
    if (!user) return res.status(400).json({ success: false, message: "No users exist to publish post." });

    const post = await prisma.feedPost.create({
      data: {
        userId: user.id,
        content
      }
    });
    res.status(201).json({ success: true, data: post });
  } catch (error) {
    next(error);
  }
};

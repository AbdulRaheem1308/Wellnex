import { Request, Response, NextFunction } from "express";
import { createHash, timingSafeEqual } from "node:crypto";

export const adminAuthGuard = (req: Request, res: Response, next: NextFunction) => {
  const validKey = process.env.ADMIN_API_KEY;
  if (!validKey || validKey === "fallback-secret-admin-key-2026") {
    return res.status(503).json({ success: false, message: "Administrative access is not configured." });
  }
  const apiKey = req.headers["x-admin-api-key"];
  if (typeof apiKey !== "string" || !timingSafeEqual(
    createHash("sha256").update(apiKey).digest(),
    createHash("sha256").update(validKey).digest(),
  )) {
    return res.status(401).json({ success: false, message: "Unauthorized. Missing or invalid Admin API Key." });
  }
  next();
};

import {
  CanActivate,
  ExecutionContext,
  Injectable,
  ServiceUnavailableException,
  UnauthorizedException,
} from "@nestjs/common";
import { createHash, timingSafeEqual } from "node:crypto";

@Injectable()
export class AdminApiKeyGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const configured = process.env.ADMIN_API_KEY;
    if (!configured || configured === "fallback-secret-admin-key-2026") {
      throw new ServiceUnavailableException(
        "Administrative access is not configured",
      );
    }
    const provided = context.switchToHttp().getRequest().headers[
      "x-admin-api-key"
    ];
    if (
      typeof provided !== "string" ||
      !timingSafeEqual(
        createHash("sha256").update(provided).digest(),
        createHash("sha256").update(configured).digest(),
      )
    ) {
      throw new UnauthorizedException("Invalid administrative credentials");
    }
    return true;
  }
}

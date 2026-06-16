import { Controller, Get } from "@nestjs/common";
import { ApiOperation } from "@nestjs/swagger";

@Controller("health")
export class HealthController {
  @Get()
  checkHealth() {
    return {
      status: "ok",
      timestamp: new Date().toISOString(),
      service: "Wellnex API",
      version: "1.0.0",
    };
  }

  @Get("debug-sentry")
  @ApiOperation({ summary: "Test Sentry error tracking" })
  getError() {
    throw new Error("My first Sentry error from Wellnex!");
  }
}

import { Test } from "@nestjs/testing";
import { INestApplication } from "@nestjs/common";
import * as request from "supertest";
import { AnomaliesController } from "../anomalies/anomalies.controller";
import { AnomaliesService } from "../anomalies/anomalies.service";
import { UsersController } from "../users/users.controller";
import { UsersService } from "../users/users.service";
import { JwtAuthGuard } from "./guards/jwt-auth.guard";
import { AdminApiKeyGuard } from "./guards/admin-api-key.guard";

describe("Administrative HTTP authorization", () => {
  let app: INestApplication;
  const originalKey = process.env.ADMIN_API_KEY;
  const anomalyService = {
    getAnomalies: jest.fn().mockResolvedValue({ data: [] }),
    updateStatus: jest.fn().mockResolvedValue({}),
  };
  const usersService = {
    initializeAchievementsForAllUsers: jest
      .fn()
      .mockResolvedValue({ success: true }),
  };
  beforeAll(async () => {
    const module = await Test.createTestingModule({
      controllers: [AnomaliesController, UsersController],
      providers: [
        AdminApiKeyGuard,
        { provide: AnomaliesService, useValue: anomalyService },
        { provide: UsersService, useValue: usersService },
      ],
    })
      .overrideGuard(JwtAuthGuard)
      .useValue({ canActivate: () => true })
      .compile();
    app = module.createNestApplication();
    app.setGlobalPrefix("api/v1");
    await app.init();
  });
  beforeEach(() => {
    process.env.ADMIN_API_KEY = "test-admin-key-only";
    jest.clearAllMocks();
  });
  afterAll(async () => {
    if (originalKey === undefined) delete process.env.ADMIN_API_KEY;
    else process.env.ADMIN_API_KEY = originalKey;
    await app.close();
  });
  it("blocks unauthenticated anomaly reads and writes", async () => {
    await request(app.getHttpServer())
      .get("/api/v1/api/admin/anomalies")
      .expect(401);
    await request(app.getHttpServer())
      .patch("/api/v1/api/admin/anomalies/id/status")
      .send({ status: "RESOLVED" })
      .expect(401);
    expect(anomalyService.getAnomalies).not.toHaveBeenCalled();
    expect(anomalyService.updateStatus).not.toHaveBeenCalled();
  });
  it("blocks ordinary authenticated users from the global migration", async () => {
    await request(app.getHttpServer())
      .post("/api/v1/users/init-achievements")
      .expect(401);
    expect(
      usersService.initializeAchievementsForAllUsers,
    ).not.toHaveBeenCalled();
  });
  it("allows configured admin credentials", async () => {
    await request(app.getHttpServer())
      .get("/api/v1/api/admin/anomalies")
      .set("x-admin-api-key", "test-admin-key-only")
      .expect(200);
  });
  it("fails closed for missing or the legacy default secret", async () => {
    delete process.env.ADMIN_API_KEY;
    await request(app.getHttpServer())
      .get("/api/v1/api/admin/anomalies")
      .set("x-admin-api-key", "fallback-secret-admin-key-2026")
      .expect(503);
    process.env.ADMIN_API_KEY = "fallback-secret-admin-key-2026";
    await request(app.getHttpServer())
      .get("/api/v1/api/admin/anomalies")
      .set("x-admin-api-key", "fallback-secret-admin-key-2026")
      .expect(503);
  });
});

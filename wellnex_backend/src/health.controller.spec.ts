import { Test, TestingModule } from "@nestjs/testing";
import { HealthController } from "./health.controller";

describe("HealthController", () => {
  let controller: HealthController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [HealthController],
    }).compile();

    controller = module.get<HealthController>(HealthController);
  });

  it("should be defined", () => {
    expect(controller).toBeDefined();
  });

  it("should return health status", () => {
    // Mock date to ensure consistent timestamp testing if needed,
    // or just check for existence of properties.
    const result = controller.checkHealth();

    expect(result.status).toBe("ok");
    expect(result.service).toBe("Wellnex API");
    expect(result.version).toBe("1.0.0");
    expect(result.timestamp).toBeDefined();

    // Check if timestamp is a valid ISO string
    expect(() => new Date(result.timestamp)).not.toThrow();
  });
});

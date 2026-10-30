import { Test, TestingModule } from "@nestjs/testing";
import { JwtStrategy } from "./jwt.strategy";
import { ConfigService } from "@nestjs/config";
import { AuthService } from "../auth.service";
import { UnauthorizedException } from "@nestjs/common";

describe("JwtStrategy", () => {
  let strategy: JwtStrategy;
  let authService: AuthService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        JwtStrategy,
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn((key) => {
              if (key === "JWT_SECRET") return "test_secret";
              return null;
            }),
          },
        },
        {
          provide: AuthService,
          useValue: {
            validateUser: jest.fn(),
          },
        },
      ],
    }).compile();

    strategy = module.get<JwtStrategy>(JwtStrategy);
    authService = module.get<AuthService>(AuthService);
  });

  it("should be defined", () => {
    expect(strategy).toBeDefined();
  });

  it("rejects startup without a configured signing secret", () => {
    expect(
      () => new JwtStrategy({ get: () => undefined } as any, {} as any),
    ).toThrow("JWT_SECRET is required");
  });

  describe("validate", () => {
    it("should return user if validation is successful", async () => {
      const mockUser = { id: "1", email: "test@test.com" };
      const payload = { sub: "1", email: "test@test.com", type: "access" };

      (authService.validateUser as jest.Mock).mockResolvedValueOnce(mockUser);

      const result = await strategy.validate(payload as any);
      expect(result).toEqual(mockUser);
      expect(authService.validateUser).toHaveBeenCalledWith(payload);
    });

    it("should throw UnauthorizedException if validation fails", async () => {
      const payload = { sub: "2", email: "fail@test.com", type: "access" };

      (authService.validateUser as jest.Mock).mockResolvedValueOnce(null);

      await expect(strategy.validate(payload as any)).rejects.toThrow(
        UnauthorizedException,
      );
    });
  });
});

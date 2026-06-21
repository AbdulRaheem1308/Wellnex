import { Test, TestingModule } from "@nestjs/testing";
import { AuthController } from "./auth.controller";
import { AuthService } from "./auth.service";
import {
  SendOtpDto,
  VerifyOtpDto,
  RefreshTokenDto,
  SocialLoginDto,
} from "./dto/auth.dto";

describe("AuthController", () => {
  let controller: AuthController;
  let authService: AuthService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [AuthController],
      providers: [
        {
          provide: AuthService,
          useValue: {
            sendOtp: jest.fn(),
            verifyOtp: jest.fn(),
            loginWithSocial: jest.fn(),
            refreshToken: jest.fn(),
            logout: jest.fn(),
          },
        },
      ],
    }).compile();

    controller = module.get<AuthController>(AuthController);
    authService = module.get<AuthService>(AuthService);
  });

  it("should be defined", () => {
    expect(controller).toBeDefined();
  });

  describe("sendOtp", () => {
    it("should call authService.sendOtp", async () => {
      const dto: SendOtpDto = { email: "test@test.com" };
      const expectedResult = { message: "OTP sent" };
      (authService.sendOtp as jest.Mock).mockResolvedValueOnce(expectedResult);

      const result = await controller.sendOtp(dto);

      expect(result).toEqual(expectedResult);
      expect(authService.sendOtp).toHaveBeenCalledWith(dto);
    });
  });

  describe("verifyOtp", () => {
    it("should call authService.verifyOtp", async () => {
      const dto: VerifyOtpDto = { email: "test@test.com", otp: "123456" };
      const expectedResult = {
        accessToken: "access",
        refreshToken: "refresh",
        user: {} as any,
      };
      (authService.verifyOtp as jest.Mock).mockResolvedValueOnce(
        expectedResult,
      );

      const result = await controller.verifyOtp(dto);

      expect(result).toEqual(expectedResult);
      expect(authService.verifyOtp).toHaveBeenCalledWith(dto);
    });
  });

  describe("socialLogin", () => {
    it("should call authService.loginWithSocial", async () => {
      const dto: SocialLoginDto = { idToken: "token" };
      const expectedResult = {
        accessToken: "access",
        refreshToken: "refresh",
        user: {} as any,
      };
      (authService.loginWithSocial as jest.Mock).mockResolvedValueOnce(
        expectedResult,
      );

      const result = await controller.socialLogin(dto);

      expect(result).toEqual(expectedResult);
      expect(authService.loginWithSocial).toHaveBeenCalledWith(dto);
    });
  });

  describe("refresh", () => {
    it("should call authService.refreshToken", async () => {
      const dto: RefreshTokenDto = { refreshToken: "refresh_token" };
      const expectedResult = {
        accessToken: "new_access",
        refreshToken: "new_refresh",
      };
      (authService.refreshToken as jest.Mock).mockResolvedValueOnce(
        expectedResult,
      );

      const result = await controller.refresh(dto);

      expect(result).toEqual(expectedResult);
      expect(authService.refreshToken).toHaveBeenCalledWith(dto);
    });
  });

  describe("logout", () => {
    it("should call authService.logout", async () => {
      const dto: RefreshTokenDto = { refreshToken: "refresh_token" };
      const user = { email: "test@example.com" };

      const result = await controller.logout(dto, user);

      expect(result).toEqual({ message: "Logged out successfully" });
      expect(authService.logout).toHaveBeenCalledWith(dto.refreshToken, user);
    });
  });
});

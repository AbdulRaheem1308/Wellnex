import { Test, TestingModule } from "@nestjs/testing";
import { AuthService } from "./auth.service";
import { JwtService } from "@nestjs/jwt";
import { ConfigService } from "@nestjs/config";
import { BadRequestException, UnauthorizedException } from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { RedisService } from "../redis/redis.service";
import { OtpService } from "./otp.service";
import { UsersService } from "../users/users.service";
import { SocialAuthService } from "./social-auth.service";

// ── Mocks ──────────────────────────────────────────────────────────────────
const mockPrisma: any = {
  refreshToken: {
    create: jest.fn(),
    findUnique: jest.fn(),
    delete: jest.fn(),
    deleteMany: jest.fn(),
  },
  user: {
    findUnique: jest.fn(),
    update: jest.fn(),
  },
  wallet: { upsert: jest.fn() },
  transaction: { create: jest.fn() },
  $transaction: jest.fn((ops) => {
    if (typeof ops === "function") {
      return ops(mockPrisma);
    }
    return Promise.all(ops);
  }),
};

const mockRedis = {
  checkOtpRateLimit: jest.fn(),
  setOtp: jest.fn(),
  getOtp: jest.fn(),
  deleteOtp: jest.fn(),
};

const mockOtp = {
  generateOtp: jest.fn().mockReturnValue("123456"),
  sendSmsOtp: jest.fn(),
  sendEmailOtp: jest.fn(),
};

const mockUsers = {
  findByIdentifier: jest.fn(),
  findById: jest.fn(),
  create: jest.fn(),
  sanitizeUser: jest.fn((u) => ({ id: u.id, email: u.email, name: u.name })),
};

const mockJwt = {
  sign: jest.fn().mockReturnValue("mock-jwt-token"),
  verify: jest.fn().mockReturnValue({ sub: "user-id-1" }),
};

const mockConfig = {
  get: jest.fn((key: string, def?: any) => {
    const map: Record<string, any> = {
      OTP_EXPIRY_MINUTES: 5,
      JWT_REFRESH_SECRET: "refresh-secret",
      JWT_REFRESH_EXPIRY: "7d",
    };
    return map[key] ?? def;
  }),
};

const mockSocialAuth = {
  verifyIdToken: jest.fn(),
};

// ── Tests ──────────────────────────────────────────────────────────────────
describe("AuthService", () => {
  let service: AuthService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: JwtService, useValue: mockJwt },
        { provide: ConfigService, useValue: mockConfig },
        { provide: PrismaService, useValue: mockPrisma },
        { provide: RedisService, useValue: mockRedis },
        { provide: OtpService, useValue: mockOtp },
        { provide: UsersService, useValue: mockUsers },
        { provide: SocialAuthService, useValue: mockSocialAuth },
      ],
    }).compile();

    service = module.get<AuthService>(AuthService);
    jest.clearAllMocks();
  });

  // ── sendOtp ──────────────────────────────────────────────────────────────
  describe("sendOtp()", () => {
    it("should throw BadRequestException if no phone or email provided", async () => {
      await expect(service.sendOtp({} as any)).rejects.toThrow(
        BadRequestException,
      );
    });

    it("should throw BadRequestException if OTP rate limit exceeded", async () => {
      mockRedis.checkOtpRateLimit.mockResolvedValue(false);
      await expect(service.sendOtp({ phone: "+919876543210" })).rejects.toThrow(
        BadRequestException,
      );
    });

    it("should send OTP via SMS and return expiresIn on success", async () => {
      mockRedis.checkOtpRateLimit.mockResolvedValue(true);
      mockRedis.setOtp.mockResolvedValue(true);
      mockOtp.sendSmsOtp.mockResolvedValue(undefined);

      const result = await service.sendOtp({ phone: "+919876543210" });

      expect(mockOtp.generateOtp).toHaveBeenCalled();
      expect(mockOtp.sendSmsOtp).toHaveBeenCalledWith(
        "+919876543210",
        "123456",
      );
      expect(result.expiresIn).toBe(300); // 5 mins * 60
      expect(result.message).toContain("phone");
    });

    it("should send OTP via email when email provided", async () => {
      mockRedis.checkOtpRateLimit.mockResolvedValue(true);
      mockRedis.setOtp.mockResolvedValue(true);
      mockOtp.sendEmailOtp.mockResolvedValue(undefined);

      const result = await service.sendOtp({ email: "user@joinwellnex.com" });

      expect(mockOtp.sendEmailOtp).toHaveBeenCalledWith(
        "user@joinwellnex.com",
        "123456",
      );
      expect(result.message).toContain("email");
    });
  });

  // ── verifyOtp ────────────────────────────────────────────────────────────
  describe("verifyOtp()", () => {
    it("should throw BadRequestException if no phone or email provided", async () => {
      await expect(service.verifyOtp({ otp: "123456" } as any)).rejects.toThrow(
        BadRequestException,
      );
    });

    it("should throw UnauthorizedException if OTP is expired or not found", async () => {
      mockRedis.getOtp.mockResolvedValue(null);
      await expect(
        service.verifyOtp({ phone: "+919876543210", otp: "123456" }),
      ).rejects.toThrow(UnauthorizedException);
    });

    it("should throw UnauthorizedException if OTP is incorrect", async () => {
      mockRedis.getOtp.mockResolvedValue("654321");
      await expect(
        service.verifyOtp({ phone: "+919876543210", otp: "123456" }),
      ).rejects.toThrow(UnauthorizedException);
    });

    it("should create new user and return tokens for first-time login", async () => {
      mockRedis.getOtp.mockResolvedValue("123456");
      mockRedis.deleteOtp.mockResolvedValue(true);
      mockUsers.findByIdentifier.mockResolvedValue(null);
      const mockUser = {
        id: "user-1",
        phone: "+919876543210",
        email: null,
        name: null,
        isActive: true,
      };
      mockUsers.create.mockResolvedValue(mockUser);
      mockPrisma.refreshToken.create.mockResolvedValue({});

      const result = await service.verifyOtp({
        phone: "+919876543210",
        otp: "123456",
      });

      expect(result.isNewUser).toBe(true);
      expect(result.tokens.accessToken).toBe("mock-jwt-token");
    });

    it("should return isNewUser=false for existing user with a name", async () => {
      mockRedis.getOtp.mockResolvedValue("123456");
      mockRedis.deleteOtp.mockResolvedValue(true);
      const existingUser = {
        id: "user-1",
        phone: "+919876543210",
        name: "Raheem",
        isProfileCreated: true,
        isActive: true,
      };
      mockUsers.findByIdentifier.mockResolvedValue(existingUser);
      mockPrisma.refreshToken.create.mockResolvedValue({});

      const result = await service.verifyOtp({
        phone: "+919876543210",
        otp: "123456",
      });

      expect(result.isNewUser).toBe(false);
    });

    it("should return isNewUser=true if existing user has no name (incomplete profile)", async () => {
      mockRedis.getOtp.mockResolvedValue("123456");
      mockRedis.deleteOtp.mockResolvedValue(true);
      const existingUser = {
        id: "user-1",
        phone: "+919876543210",
        name: null,
        isActive: true,
      };
      mockUsers.findByIdentifier.mockResolvedValue(existingUser);
      mockPrisma.refreshToken.create.mockResolvedValue({});

      const result = await service.verifyOtp({
        phone: "+919876543210",
        otp: "123456",
      });

      expect(result.isNewUser).toBe(true);
    });
  });

  // ── refreshToken ─────────────────────────────────────────────────────────
  describe("refreshToken()", () => {
    it("should throw UnauthorizedException for an invalid token", async () => {
      mockJwt.verify.mockImplementation(() => {
        throw new Error("expired");
      });
      await expect(
        service.refreshToken({ refreshToken: "bad-token" }),
      ).rejects.toThrow(UnauthorizedException);
    });

    it("should throw UnauthorizedException if token record is not found in DB", async () => {
      mockJwt.verify.mockReturnValue({ sub: "user-1" });
      mockPrisma.refreshToken.findUnique.mockResolvedValue(null);
      await expect(
        service.refreshToken({ refreshToken: "some-token" }),
      ).rejects.toThrow(UnauthorizedException);
    });

    it("should throw UnauthorizedException if token is expired", async () => {
      mockJwt.verify.mockReturnValue({ sub: "user-1" });
      mockPrisma.refreshToken.findUnique.mockResolvedValue({
        id: "rt-1",
        token: "some-token",
        expiresAt: new Date(Date.now() - 1000), // Already expired
        user: { id: "user-1" },
      });
      await expect(
        service.refreshToken({ refreshToken: "some-token" }),
      ).rejects.toThrow(UnauthorizedException);
    });

    it("should return new tokens on successful refresh", async () => {
      mockJwt.verify.mockReturnValue({ sub: "user-1" });
      mockPrisma.refreshToken.findUnique.mockResolvedValue({
        id: "rt-1",
        token: "valid-token",
        expiresAt: new Date(Date.now() + 10000),
        user: { id: "user-1", email: "a@b.com", phone: null },
      });
      mockPrisma.refreshToken.delete.mockResolvedValue({});
      mockPrisma.refreshToken.create.mockResolvedValue({});

      const result = await service.refreshToken({
        refreshToken: "valid-token",
      });

      expect(result.accessToken).toBeDefined();
      expect(result.refreshToken).toBeDefined();
    });
  });

  // ── logout ───────────────────────────────────────────────────────────────
  describe("logout()", () => {
    it("should call deleteMany to remove refresh token on logout", async () => {
      mockPrisma.refreshToken.deleteMany.mockResolvedValue({ count: 1 });
      await service.logout("some-refresh-token");
      expect(mockPrisma.refreshToken.deleteMany).toHaveBeenCalledWith({
        where: { token: "some-refresh-token" },
      });
    });
  });

  // ── validateUser ─────────────────────────────────────────────────────────
  describe("validateUser()", () => {
    it("should throw UnauthorizedException if user is not found", async () => {
      mockUsers.findById.mockResolvedValue(null);
      await expect(service.validateUser({ sub: "ghost-id" })).rejects.toThrow(
        UnauthorizedException,
      );
    });

    it("should throw UnauthorizedException if user is inactive", async () => {
      mockUsers.findById.mockResolvedValue({ id: "user-1", isActive: false });
      await expect(service.validateUser({ sub: "user-1" })).rejects.toThrow(
        UnauthorizedException,
      );
    });

    it("should return user if active", async () => {
      const user = { id: "user-1", isActive: true };
      mockUsers.findById.mockResolvedValue(user);
      const result = await service.validateUser({ sub: "user-1" });
      expect(result).toEqual(user);
    });
  });

  // ── loginWithSocial ──────────────────────────────────────────────────────
  describe("loginWithSocial()", () => {
    it("should throw BadRequest if email missing from social token", async () => {
      mockSocialAuth.verifyIdToken.mockResolvedValue({});
      await expect(
        service.loginWithSocial({ idToken: "token" } as any),
      ).rejects.toThrow(BadRequestException);
    });

    it("should return existing user and generate tokens", async () => {
      mockSocialAuth.verifyIdToken.mockResolvedValue({
        email: "test@apple.com",
      });
      const mockUser = { id: "user-1", email: "test@apple.com", name: "Apple User", isProfileCreated: true };
      mockUsers.findByIdentifier.mockResolvedValue(mockUser);
      mockPrisma.refreshToken.create.mockResolvedValue({});

      const result = await service.loginWithSocial({ idToken: "token" });
      expect(result.isNewUser).toBe(false);
      expect(result.tokens.accessToken).toBe("mock-jwt-token");
    });

    it("should return isNewUser=true if existing user has no name (incomplete profile)", async () => {
      mockSocialAuth.verifyIdToken.mockResolvedValue({
        email: "test@apple.com",
      });
      const mockUser = { id: "user-1", email: "test@apple.com", name: null, isProfileCreated: false };
      mockUsers.findByIdentifier.mockResolvedValue(mockUser);
      mockPrisma.refreshToken.create.mockResolvedValue({});

      const result = await service.loginWithSocial({ idToken: "token" });
      expect(result.isNewUser).toBe(true);
    });

    it("should create new user, process referral, and return tokens", async () => {
      mockSocialAuth.verifyIdToken.mockResolvedValue({
        email: "new@apple.com",
        name: "Apple User",
      });
      mockUsers.findByIdentifier.mockResolvedValue(null);
      const mockUser = { id: "user-new", email: "new@apple.com" };
      mockUsers.create.mockResolvedValue(mockUser);
      mockPrisma.refreshToken.create.mockResolvedValue({});
      mockPrisma.user.findUnique.mockResolvedValue({ id: "inviter-1" });

      const result = await service.loginWithSocial({
        idToken: "token",
        referralCode: "REFCODE",
      });
      expect(result.isNewUser).toBe(true);
      expect(mockUsers.create).toHaveBeenCalledWith({
        email: "new@apple.com",
        name: "Apple User",
        referredBy: "REFCODE",
      });
      expect(mockPrisma.user.findUnique).toHaveBeenCalledWith({
        where: { referralCode: "REFCODE" },
        select: { id: true },
      });
    });
  });

  // ── attributeReferralRewards ─────────────────────────────────────────────
  describe("attributeReferralRewards()", () => {
    it("should fail silently if referral code is invalid", async () => {
      mockPrisma.user.findUnique.mockResolvedValue(null);
      // We trigger this indirectly via verifyOtp for a new user
      mockRedis.getOtp.mockResolvedValue("123456");
      mockRedis.deleteOtp.mockResolvedValue(true);
      mockUsers.findByIdentifier.mockResolvedValue(null);
      mockUsers.create.mockResolvedValue({ id: "user-new" });
      mockPrisma.refreshToken.create.mockResolvedValue({});

      await expect(
        service.verifyOtp({ phone: "123", otp: "123456", referralCode: "BAD" }),
      ).resolves.toBeDefined();
    });

    it("should fail silently if database transaction fails", async () => {
      mockPrisma.user.findUnique.mockResolvedValue({ id: "inviter-1" });
      mockPrisma.$transaction.mockRejectedValue(new Error("DB Error"));

      mockRedis.getOtp.mockResolvedValue("123456");
      mockRedis.deleteOtp.mockResolvedValue(true);
      mockUsers.findByIdentifier.mockResolvedValue(null);
      mockUsers.create.mockResolvedValue({ id: "user-new" });
      mockPrisma.refreshToken.create.mockResolvedValue({});

      // Should resolve without throwing error
      await expect(
        service.verifyOtp({
          phone: "123",
          otp: "123456",
          referralCode: "GOOD",
        }),
      ).resolves.toBeDefined();
    });
  });
});

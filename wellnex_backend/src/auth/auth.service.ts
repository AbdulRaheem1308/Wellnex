import {
  Injectable,
  UnauthorizedException,
  BadRequestException,
  Logger,
} from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import { ConfigService } from "@nestjs/config";
import { PrismaService } from "../prisma/prisma.service";
import { RedisService } from "../redis/redis.service";
import { OtpService } from "./otp.service";
import { UsersService } from "../users/users.service";
import {
  SendOtpDto,
  VerifyOtpDto,
  RefreshTokenDto,
  SocialLoginDto,
} from "./dto/auth.dto";
import { SocialAuthService } from "./social-auth.service";

export interface JwtPayload {
  sub: string;
  phone?: string;
  email?: string;
}

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
}

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
    private readonly otpService: OtpService,
    private readonly socialAuth: SocialAuthService,
    private readonly usersService: UsersService,
  ) {}

  /**
   * Send OTP to phone or email
   */
  async sendOtp(
    dto: SendOtpDto,
  ): Promise<{ message: string; expiresIn: number }> {
    const identifier = dto.phone || dto.email;
    if (!identifier) {
      throw new BadRequestException("Phone or email is required");
    }

    // Check rate limit
    const canSend = await this.redis.checkOtpRateLimit(identifier);
    if (!canSend) {
      throw new BadRequestException(
        "Too many OTP requests. Please try again later.",
      );
    }

    // Generate and store OTP
    const otp = this.otpService.generateOtp();
    const expiryMinutes = this.configService.get<number>(
      "OTP_EXPIRY_MINUTES",
      5,
    );

    await this.redis.setOtp(identifier, otp, expiryMinutes);

    // Send OTP via Twilio/Email
    if (dto.phone) {
      await this.otpService.sendSmsOtp(dto.phone, otp);
    } else if (dto.email) {
      await this.otpService.sendEmailOtp(dto.email, otp);
    }

    return {
      message: `OTP sent to ${dto.phone ? "phone" : "email"}`,
      expiresIn: expiryMinutes * 60,
    };
  }

  /**
   * Verify OTP and return tokens
   */
  async verifyOtp(
    dto: VerifyOtpDto,
  ): Promise<{ tokens: AuthTokens; user: any; isNewUser: boolean }> {
    const identifier = dto.phone || dto.email;
    if (!identifier) {
      throw new BadRequestException("Phone or email is required");
    }

    // Get stored OTP
    const storedOtp = await this.redis.getOtp(identifier);
    if (!storedOtp) {
      throw new UnauthorizedException("OTP expired or not found");
    }

    // Verify OTP
    if (storedOtp !== dto.otp) {
      throw new UnauthorizedException("Invalid OTP");
    }

    // Delete used OTP
    await this.redis.deleteOtp(identifier);

    // Find or create user
    let user = await this.usersService.findByIdentifier(identifier);
    let isNewUser = false;

    if (!user) {
      user = await this.usersService.create({
        phone: dto.phone,
        email: dto.email,
        referredBy: dto.referralCode,
      });
      isNewUser = true;

      if (dto.referralCode) {
        await this.attributeReferralRewards(user.id, dto.referralCode);
      }
    } else if (!user.name) {
      // Treat as new user if profile is incomplete (no name)
      isNewUser = true;
    }

    // Generate tokens
    const tokens = await this.generateTokens(user);

    return {
      tokens,
      user: this.usersService.sanitizeUser(user),
      isNewUser,
    };
  }

  /**
   * Social Login (Google/Apple) via Firebase ID Token
   */
  async loginWithSocial(
    dto: SocialLoginDto,
  ): Promise<{ tokens: AuthTokens; user: any; isNewUser: boolean }> {
    this.logger.log("🔴 [loginWithSocial] Starting social login process...");
    this.logger.log(
      `🔴 [loginWithSocial] ID Token provided (length): ${dto.idToken?.length}`,
    );

    // 1. Verify Token with Firebase Admin
    this.logger.log(
      "🔴 [loginWithSocial] Step 1: Verifying token with Firebase Admin...",
    );
    const decodedToken = await this.socialAuth.verifyIdToken(dto.idToken);
    this.logger.log(
      `🔴 [loginWithSocial] Firebase verification successful. Decoded keys: ${Object.keys(decodedToken).join(", ")}`,
    );

    const { email, name } = decodedToken;

    if (!email) {
      this.logger.log("🔴 [loginWithSocial] Error: No email in token");
      throw new BadRequestException(
        "Social account must have an email address",
      );
    }

    // 2. Find or Create User
    this.logger.log(
      `🔴 [loginWithSocial] Step 2: Looking up user by email (${email})...`,
    );
    let user = await this.usersService.findByIdentifier(email);
    let isNewUser = false;

    if (user) {
      this.logger.log(
        `🔴 [loginWithSocial] Existing user found (ID: ${user.id}).`,
      );
      if (!user.name) {
        // Treat as new user if profile is incomplete
        isNewUser = true;
      }
    } else {
      this.logger.log(
        "🔴 [loginWithSocial] User not found. Creating new user...",
      );
      user = await this.usersService.create({
        email: email,
        name: name || undefined,
        referredBy: dto.referralCode,
      });
      isNewUser = true;
      this.logger.log(
        `🔴 [loginWithSocial] New user created with ID: ${user.id}`,
      );

      if (dto.referralCode) {
        this.logger.log("🔴 [loginWithSocial] Processing referral code...");
        await this.attributeReferralRewards(user.id, dto.referralCode);
      }
    }

    // 3. Generate Tokens
    this.logger.log("🔴 [loginWithSocial] Step 3: Generating JWT tokens...");
    const tokens = await this.generateTokens(user);
    this.logger.log("🔴 [loginWithSocial] Tokens generated successfully.");

    return {
      tokens,
      user: this.usersService.sanitizeUser(user),
      isNewUser,
    };
  }

  /**
   * Refresh access token
   */
  async refreshToken(dto: RefreshTokenDto): Promise<AuthTokens> {
    try {
      // Verify refresh token
      this.jwtService.verify(dto.refreshToken, {
        secret: this.configService.get("JWT_REFRESH_SECRET"),
      });

      // Check if token exists in database
      const tokenRecord = await this.prisma.refreshToken.findUnique({
        where: { token: dto.refreshToken },
        include: { user: true },
      });

      if (!tokenRecord || tokenRecord.expiresAt < new Date()) {
        throw new UnauthorizedException("Invalid refresh token");
      }

      // Delete old refresh token
      await this.prisma.refreshToken.delete({
        where: { id: tokenRecord.id },
      });

      // Generate new tokens
      return this.generateTokens(tokenRecord.user);
    } catch (error: any) {
      throw new UnauthorizedException("Invalid refresh token", {
        cause: error,
      });
    }
  }

  /**
   * Logout - invalidate refresh token
   */
  async logout(refreshToken: string): Promise<void> {
    await this.prisma.refreshToken.deleteMany({
      where: { token: refreshToken },
    });
  }

  /**
   * Generate access and refresh tokens
   */
  private async generateTokens(user: any): Promise<AuthTokens> {
    const payload: JwtPayload = {
      sub: user.id,
      phone: user.phone,
      email: user.email,
    };

    const accessToken = this.jwtService.sign(payload);

    const refreshToken = this.jwtService.sign(payload, {
      secret: this.configService.get("JWT_REFRESH_SECRET"),
      expiresIn: this.configService.get("JWT_REFRESH_EXPIRY", "7d"),
    });

    // Store refresh token in database
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7); // 7 days

    await this.prisma.refreshToken.create({
      data: {
        token: refreshToken,
        userId: user.id,
        expiresAt,
      },
    });

    return { accessToken, refreshToken };
  }

  /**
   * Validate user from JWT payload
   */
  async validateUser(payload: JwtPayload): Promise<any> {
    const user = await this.usersService.findById(payload.sub);
    if (!user?.isActive) {
      throw new UnauthorizedException();
    }
    return user;
  }

  /**
   * Process Referral Rewards
   * Attributes 500 coins to the inviter and 200 coins to the invitee.
   */
  private async attributeReferralRewards(
    newUserId: string,
    referralCode: string,
  ) {
    // Find the inviter
    const inviter = await this.prisma.user.findUnique({
      where: { referralCode },
      select: { id: true },
    });

    if (!inviter) return; // Invalid referral code, fail silently

    try {
      await this.prisma.$transaction(async (tx) => {
        // 1. Reward Inviter (500 coins)
        await tx.wallet.upsert({
          where: { userId: inviter.id },
          update: {
            balance: { increment: 500 },
            lifetimePoints: { increment: 500 },
          },
          create: { userId: inviter.id, balance: 500, lifetimePoints: 500 },
        });

        await tx.transaction.create({
          data: {
            userId: inviter.id,
            type: "REFERRAL",
            points: 500,
            description: "Bonus for referring a new friend!",
          },
        });

        await tx.user.update({
          where: { id: inviter.id },
          data: {
            referralCount: { increment: 1 },
            referralCoinsEarned: { increment: 500 },
          },
        });

        // 2. Reward Invitee (200 coins)
        await tx.wallet.upsert({
          where: { userId: newUserId },
          update: {
            balance: { increment: 200 },
            lifetimePoints: { increment: 200 },
          },
          create: { userId: newUserId, balance: 200, lifetimePoints: 200 },
        });

        await tx.transaction.create({
          data: {
            userId: newUserId,
            type: "REFERRAL",
            points: 200,
            description: "Bonus for using a referral code!",
          },
        });
      });
    } catch (error) {
      this.logger.error(
        `Failed to attribute referral rewards for new user ${newUserId} using code ${referralCode}: ${error.message}`,
      );
      // Fail silently to not block auth flow
    }
  }
}

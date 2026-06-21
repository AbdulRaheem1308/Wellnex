import {
  Controller,
  Post,
  Body,
  UseGuards,
  HttpCode,
  HttpStatus,
} from "@nestjs/common";
import { AuthService } from "./auth.service";
import {
  SendOtpDto,
  VerifyOtpDto,
  RefreshTokenDto,
  SocialLoginDto,
} from "./dto/auth.dto";
import { JwtAuthGuard } from "./guards/jwt-auth.guard";
import { CurrentUser } from "../users/decorators/current-user.decorator";
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
} from "@nestjs/swagger";

@ApiTags("Authentication")
@Controller("auth")
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post("send-otp")
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: "Send OTP to phone or email" })
  @ApiResponse({ status: 200, description: "OTP sent successfully" })
  @ApiResponse({ status: 400, description: "Invalid input or rate limited" })
  async sendOtp(@Body() dto: SendOtpDto) {
    return this.authService.sendOtp(dto);
  }

  @Post("verify-otp")
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: "Verify OTP and login" })
  @ApiResponse({ status: 200, description: "Tokens generated successfully" })
  @ApiResponse({ status: 401, description: "Invalid or expired OTP" })
  async verifyOtp(@Body() dto: VerifyOtpDto) {
    return this.authService.verifyOtp(dto);
  }

  @Post("social-login")
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: "Login via Google or Apple Firebase Token" })
  @ApiResponse({ status: 200, description: "Tokens generated successfully" })
  @ApiResponse({ status: 400, description: "Invalid Firebase Token" })
  async socialLogin(@Body() dto: SocialLoginDto) {
    return this.authService.loginWithSocial(dto);
  }

  @Post("refresh")
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: "Refresh access token using refresh token" })
  @ApiResponse({ status: 200, description: "New tokens generated" })
  @ApiResponse({ status: 401, description: "Invalid or expired refresh token" })
  async refresh(@Body() dto: RefreshTokenDto) {
    return this.authService.refreshToken(dto);
  }

  @Post("logout")
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: "Logout and invalidate refresh token" })
  @ApiResponse({ status: 200, description: "Logged out successfully" })
  async logout(@Body() dto: RefreshTokenDto, @CurrentUser() user: any) {
    await this.authService.logout(dto.refreshToken, user);
    return { message: "Logged out successfully" };
  }
}

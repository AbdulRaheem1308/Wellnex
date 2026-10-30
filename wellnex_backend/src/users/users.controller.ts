import {
  Controller,
  Get,
  Put,
  Post,
  Delete,
  Body,
  Query,
  UseGuards,
} from "@nestjs/common";
import { AdminApiKeyGuard } from "../auth/guards/admin-api-key.guard";
import { UsersService } from "./users.service";
import {
  UpdateUserDto,
  ApplyReferralDto,
  UpdateSettingsDto,
} from "./dto/user.dto";
import { JwtAuthGuard } from "../auth/guards/jwt-auth.guard";
import { CurrentUser } from "../auth/decorators/current-user.decorator";
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiQuery,
} from "@nestjs/swagger";

@ApiTags("Users")
@ApiBearerAuth()
@Controller("users")
@UseGuards(JwtAuthGuard)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  /**
   * Get available avatars
   */
  @Get("avatars")
  @ApiOperation({ summary: "Get list of available avatars" })
  @ApiResponse({ status: 200, description: "Returns list of avatars" })
  async getAvatars() {
    return this.usersService.getAvatars();
  }

  /**
   * Get current user profile
   */
  @Get("me")
  @ApiOperation({ summary: "Get current user profile" })
  @ApiResponse({ status: 200, description: "Returns the current user profile" })
  async getProfile(@CurrentUser() user: any) {
    return this.usersService.findById(user.id);
  }

  /**
   * Update user profile
   */
  @Put("me")
  @ApiOperation({ summary: "Update current user profile" })
  @ApiResponse({ status: 200, description: "Profile updated successfully" })
  async updateProfile(@CurrentUser() user: any, @Body() dto: UpdateUserDto) {
    return this.usersService.update(user.id, dto);
  }

  /**
   * Get user statistics
   */
  @Get("me/stats")
  @ApiOperation({ summary: "Get lifetime statistics for the user" })
  @ApiResponse({ status: 200, description: "Returns user stats" })
  async getStats(@CurrentUser() user: any) {
    return this.usersService.getUserStats(user.id);
  }

  /**
   * Get referral leaderboard (Screen 18)
   */
  @Get("referral-leaderboard")
  @ApiOperation({ summary: "Get the global referral leaderboard" })
  @ApiQuery({ name: "limit", required: false, type: Number })
  @ApiResponse({ status: 200, description: "Returns the leaderboard" })
  async getReferralLeaderboard(@Query("limit") limit?: string) {
    const limitNum = Number.parseInt(limit || "20", 10) || 20;
    return this.usersService.getReferralLeaderboard(limitNum);
  }

  /**
   * Get current user's referral stats
   */
  @Get("me/referral")
  @ApiOperation({ summary: "Get current user's referral code and stats" })
  @ApiResponse({ status: 200, description: "Returns referral stats" })
  async getMyReferralStats(@CurrentUser() user: any) {
    return this.usersService.getReferralStats(user.id);
  }

  /**
   * Apply a referral code
   */
  @Post("me/apply-referral")
  @ApiOperation({ summary: "Apply a referral code to the account" })
  @ApiResponse({
    status: 201,
    description: "Referral code applied successfully",
  })
  @ApiResponse({ status: 400, description: "Invalid or already applied code" })
  async applyReferralCode(
    @CurrentUser() user: any,
    @Body() dto: ApplyReferralDto,
  ) {
    return this.usersService.applyReferralCode(user.id, dto.code);
  }

  /**
   * Initialize achievements for all existing users (one-time migration)
   */
  @UseGuards(AdminApiKeyGuard)
  @Post("init-achievements")
  @ApiOperation({
    summary: "Initialize achievements for all users (Admin/Dev)",
  })
  @ApiResponse({ status: 201, description: "Achievements initialized" })
  async initializeAllUsersAchievements() {
    return this.usersService.initializeAchievementsForAllUsers();
  }

  /**
   * Get user settings
   */
  @Get("me/settings")
  @ApiOperation({ summary: "Get user settings/preferences" })
  @ApiResponse({ status: 200, description: "Returns user settings" })
  async getSettings(@CurrentUser() user: any) {
    return this.usersService.getSettings(user.id);
  }

  /**
   * Update user settings
   */
  @Put("me/settings")
  @ApiOperation({ summary: "Update user settings/preferences" })
  @ApiResponse({ status: 200, description: "Settings updated successfully" })
  async updateSettings(
    @CurrentUser() user: any,
    @Body() dto: UpdateSettingsDto,
  ) {
    return this.usersService.updateSettings(user.id, dto);
  }

  /**
   * GDPR: Export user data
   */
  @Get("me/export")
  @ApiOperation({ summary: "GDPR: Export all user data as JSON" })
  @ApiResponse({ status: 200, description: "Returns all user data" })
  async exportData(@CurrentUser() user: any) {
    return this.usersService.exportData(user.id);
  }

  /**
   * GDPR: Delete account
   */
  @Delete("me")
  @ApiOperation({ summary: "GDPR: Delete account and all associated data" })
  @ApiResponse({ status: 200, description: "Account deleted successfully" })
  async deleteAccount(@CurrentUser() user: any) {
    return this.usersService.deleteAccount(user.id);
  }
}

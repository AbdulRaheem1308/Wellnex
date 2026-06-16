import {
  Controller,
  Get,
  Post,
  Query,
  Body,
  Param,
  UseGuards,
} from "@nestjs/common";
import { RewardsService } from "./rewards.service";
import { JwtAuthGuard } from "../auth/guards/jwt-auth.guard";
import { CurrentUser } from "../auth/decorators/current-user.decorator";
import { RedeemRewardDto } from "./dto/reward.dto";
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiQuery,
} from "@nestjs/swagger";

@ApiTags("Rewards")
@ApiBearerAuth()
@Controller("rewards")
@UseGuards(JwtAuthGuard)
export class RewardsController {
  constructor(private readonly rewardsService: RewardsService) {}

  /**
   * Get wallet balance
   * GET /api/v1/rewards/wallet
   */
  @Get("wallet")
  @ApiOperation({ summary: "Get user wallet balance" })
  @ApiResponse({ status: 200, description: "Returns the user's wallet" })
  async getWallet(@CurrentUser() user: any) {
    return this.rewardsService.getWallet(user.id);
  }

  /**
   * Get transaction history
   * GET /api/v1/rewards/transactions
   */
  @Get("transactions")
  @ApiOperation({ summary: "Get user transaction history" })
  @ApiQuery({ name: "page", required: false, type: Number })
  @ApiQuery({ name: "limit", required: false, type: Number })
  @ApiResponse({ status: 200, description: "Returns paginated transactions" })
  async getTransactions(
    @CurrentUser() user: any,
    @Query("page") page: number = 1,
    @Query("limit") limit: number = 20,
  ) {
    return this.rewardsService.getTransactions(user.id, page, limit);
  }

  /**
   * Get streak info
   * GET /api/v1/rewards/streak
   */
  @Get("streak")
  @ApiOperation({ summary: "Get user streak info" })
  @ApiResponse({ status: 200, description: "Returns the user's streak" })
  async getStreak(@CurrentUser() user: any) {
    return this.rewardsService.getStreak(user.id);
  }

  /**
   * Get achievements
   * GET /api/v1/rewards/achievements
   */
  @Get("achievements")
  @ApiOperation({ summary: "Get user achievements" })
  @ApiResponse({ status: 200, description: "Returns the user's achievements" })
  async getAchievements(@CurrentUser() user: any) {
    return this.rewardsService.getAchievements(user.id);
  }

  /**
   * Get all levels
   * GET /api/v1/rewards/levels (also aliased as /gamification/levels)
   */
  @Get("levels")
  @ApiOperation({ summary: "Get gamification levels" })
  @ApiResponse({ status: 200, description: "Returns all levels" })
  async getLevels() {
    return this.rewardsService.getLevels();
  }

  // ==========================================
  // REWARDS CATALOG & REDEMPTION
  // ==========================================

  /**
   * Get rewards catalog
   * GET /api/v1/rewards/catalog
   */
  @Get("catalog")
  @ApiOperation({ summary: "Get rewards catalog" })
  @ApiQuery({ name: "category", required: false, type: String })
  @ApiResponse({ status: 200, description: "Returns available rewards" })
  async getCatalog(
    @CurrentUser() user: any,
    @Query("category") category?: string,
  ) {
    return this.rewardsService.getRewardsCatalog(user.id, category);
  }

  /**
   * Get single reward details
   * GET /api/v1/rewards/catalog/:id
   */
  @Get("catalog/:id")
  @ApiOperation({ summary: "Get reward details" })
  @ApiResponse({ status: 200, description: "Returns specific reward details" })
  async getRewardDetails(@Param("id") id: string, @CurrentUser() user: any) {
    return this.rewardsService.getRewardDetails(id, user.id);
  }

  /**
   * Redeem a reward
   * POST /api/v1/rewards/redeem
   */
  @Post("redeem")
  @ApiOperation({ summary: "Redeem a reward from the catalog" })
  @ApiResponse({ status: 201, description: "Reward successfully redeemed" })
  @ApiResponse({
    status: 400,
    description: "Insufficient coins or out of stock",
  })
  async redeemReward(@CurrentUser() user: any, @Body() dto: RedeemRewardDto) {
    return this.rewardsService.redeemReward(user.id, dto.rewardId);
  }

  /**
   * Get user's redeemed rewards (My Offers)
   * GET /api/v1/rewards/my-offers
   */
  @Get("my-offers")
  @ApiOperation({ summary: "Get user's redeemed rewards" })
  @ApiQuery({ name: "status", required: false, type: String })
  @ApiResponse({ status: 200, description: "Returns redeemed rewards" })
  async getMyOffers(
    @CurrentUser() user: any,
    @Query("status") status?: string,
  ) {
    return this.rewardsService.getMyOffers(user.id, status);
  }

  /**
   * Seed demo rewards (dev only)
   * POST /api/v1/rewards/seed
   */
  @Post("seed")
  @ApiOperation({ summary: "Seed demo rewards (Dev only)" })
  async seedRewards() {
    return this.rewardsService.seedDemoRewards();
  }

  /**
   * Force sync rewards immediately (Admin/Manual Trigger)
   * POST /api/v1/rewards/sync-force
   */
  @Post("sync-force")
  @ApiOperation({
    summary:
      "Force rewards sync processing immediately without waiting for scheduler",
  })
  @ApiResponse({
    status: 200,
    description: "Rewards sync processed successfully",
  })
  async forceSyncRewards(@Query("userId") userId?: string) {
    return this.rewardsService.forceRewardsSync(userId);
  }
}

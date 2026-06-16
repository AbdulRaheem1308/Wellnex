import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Query,
  UseGuards,
} from "@nestjs/common";
import { JwtAuthGuard } from "../auth/guards/jwt-auth.guard";
import { CurrentUser } from "../auth/decorators/current-user.decorator";
import { ChallengesService } from "./challenges.service";
import {
  JoinChallengeDto,
  UpdateChallengeProgressDto,
  ChallengeStatus,
} from "./dto/challenge.dto";
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
} from "@nestjs/swagger";

@ApiTags("Challenges")
@ApiBearerAuth()
@Controller("challenges")
@UseGuards(JwtAuthGuard)
export class ChallengesController {
  constructor(private readonly challengesService: ChallengesService) {}

  @Get()
  @ApiOperation({ summary: "Get all available challenges" })
  @ApiResponse({ status: 200, description: "Returns list of challenges" })
  async findAll() {
    return this.challengesService.findAll();
  }

  @Get("new")
  @ApiOperation({ summary: "Get new challenges not joined by user" })
  @ApiResponse({ status: 200, description: "Returns new challenges" })
  async findNew(@CurrentUser() user: any) {
    return this.challengesService.findNewChallenges(user.id);
  }

  @Get("my")
  @ApiOperation({ summary: "Get user's challenges" })
  @ApiResponse({ status: 200, description: "Returns user challenges" })
  async findMy(
    @CurrentUser() user: any,
    @Query("status") status?: ChallengeStatus,
  ) {
    return this.challengesService.findUserChallenges(user.id, status);
  }

  @Get("ongoing")
  @ApiOperation({ summary: "Get user's ongoing challenges" })
  @ApiResponse({ status: 200, description: "Returns ongoing challenges" })
  async findOngoing(@CurrentUser() user: any) {
    return this.challengesService.findUserChallenges(
      user.id,
      ChallengeStatus.ONGOING,
    );
  }

  @Get("completed")
  @ApiOperation({ summary: "Get user's completed challenges" })
  @ApiResponse({ status: 200, description: "Returns completed challenges" })
  async findCompleted(@CurrentUser() user: any) {
    return this.challengesService.findUserChallenges(
      user.id,
      ChallengeStatus.COMPLETED,
    );
  }

  @Get(":id")
  @ApiOperation({ summary: "Get a single challenge by ID" })
  @ApiResponse({ status: 200, description: "Returns challenge details" })
  async findOne(@Param("id") id: string) {
    return this.challengesService.findOne(id);
  }

  @Post("join")
  @ApiOperation({ summary: "Join a challenge" })
  @ApiResponse({ status: 201, description: "Successfully joined challenge" })
  async join(@CurrentUser() user: any, @Body() dto: JoinChallengeDto) {
    return this.challengesService.join(user.id, dto.challengeId);
  }

  @Post("progress")
  @ApiOperation({ summary: "Update challenge progress" })
  @ApiResponse({ status: 201, description: "Progress updated successfully" })
  async updateProgress(
    @CurrentUser() user: any,
    @Body() dto: UpdateChallengeProgressDto,
  ) {
    return this.challengesService.updateProgress(
      user.id,
      dto.challengeId,
      dto.stepsToAdd,
    );
  }

  @Post("seed")
  @ApiOperation({ summary: "Seed demo challenges (dev only)" })
  async seed() {
    return this.challengesService.seedDemoChallenges();
  }

  @Post(":id/revive")
  @ApiOperation({ summary: "Revive a failed or expired challenge" })
  @ApiResponse({ status: 201, description: "Successfully revived challenge" })
  async revive(
    @CurrentUser() user: any,
    @Param("id") challengeId: string,
    @Body("method") method: "COINS" | "AD",
  ) {
    return this.challengesService.revive(
      user.id,
      challengeId,
      method || "COINS",
    );
  }

  @Post(":id/restart")
  @ApiOperation({ summary: "Restart a challenge if progress is below 5%" })
  @ApiResponse({ status: 201, description: "Successfully restarted challenge" })
  async restart(@CurrentUser() user: any, @Param("id") challengeId: string) {
    return this.challengesService.restart(user.id, challengeId);
  }
}

import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  UseGuards,
  ForbiddenException,
} from "@nestjs/common";
import { QuestsService } from "./quests.service";
import { JwtAuthGuard } from "../auth/guards/jwt-auth.guard";
import { CurrentUser } from "../auth/decorators/current-user.decorator";
import { JoinQuestDto } from "./dto/quest.dto";
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiParam,
} from "@nestjs/swagger";

@ApiTags("Quests")
@ApiBearerAuth()
@Controller("quests")
@UseGuards(JwtAuthGuard)
export class QuestsController {
  constructor(private readonly questsService: QuestsService) {}

  @Get()
  @ApiOperation({ summary: "Get all available quests" })
  @ApiResponse({ status: 200, description: "Returns list of quests" })
  async findAll() {
    return this.questsService.findAll();
  }

  @Post(":id/join")
  @ApiOperation({ summary: "Join a quest" })
  @ApiParam({ name: "id", description: "Quest ID" })
  @ApiResponse({ status: 201, description: "Successfully joined the quest" })
  @ApiResponse({
    status: 403,
    description: "Cannot join on behalf of another user",
  })
  async joinQuest(
    @Param("id") questId: string,
    @Body() dto: JoinQuestDto,
    @CurrentUser() user: any,
  ) {
    // IDOR Prevention: Enforce that body userId matches current token
    const resolvedUserId = dto.userId || user.id;
    if (dto.userId && dto.userId !== user.id) {
      throw new ForbiddenException(
        "Cannot join a quest on behalf of another user",
      );
    }
    return this.questsService.joinQuest(resolvedUserId, questId);
  }

  @Get("my-quests")
  @ApiOperation({ summary: "Get current user's active and completed quests" })
  @ApiResponse({ status: 200, description: "Returns user quests" })
  async getOwnQuests(@CurrentUser() user: any) {
    return this.questsService.getUserQuests(user.id);
  }

  @Get("my-quests/:userId")
  @ApiOperation({ summary: "Get user's active and completed quests" })
  @ApiParam({ name: "userId", description: "User ID or 'me'" })
  @ApiResponse({ status: 200, description: "Returns user quests" })
  @ApiResponse({
    status: 403,
    description: "Cannot view quests for another user",
  })
  async getMyQuests(@Param("userId") userId: string, @CurrentUser() user: any) {
    // IDOR Prevention: Support backwards compatibility for 'me' and enforce strict user checking
    const resolvedUserId = userId === "me" ? user.id : userId;
    if (resolvedUserId && resolvedUserId !== user.id) {
      throw new ForbiddenException(
        "Cannot view quests belonging to another user",
      );
    }
    return this.questsService.getUserQuests(resolvedUserId);
  }

  @Post(":id/revive")
  @ApiOperation({ summary: "Revive a failed or expired quest stage" })
  @ApiResponse({ status: 201, description: "Successfully revived quest" })
  async revive(
    @CurrentUser() user: any,
    @Param("id") questId: string,
    @Body("method") method: "COINS" | "AD",
  ) {
    return this.questsService.revive(user.id, questId, method || "COINS");
  }

  @Post(":id/restart")
  @ApiOperation({ summary: "Restart a quest stage" })
  @ApiResponse({ status: 201, description: "Successfully restarted quest" })
  async restart(@CurrentUser() user: any, @Param("id") questId: string) {
    return this.questsService.restart(user.id, questId);
  }
}

import {
  Controller,
  Get,
  Post,
  Delete,
  Param,
  Query,
  Body,
  UseGuards,
  Request,
} from "@nestjs/common";
import { NotificationsService } from "./notifications.service";
import { JwtAuthGuard } from "../auth/guards/jwt-auth.guard";
import { RegisterFcmTokenDto } from "./dto/notification.dto";
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiQuery,
} from "@nestjs/swagger";

@ApiTags("Notifications")
@ApiBearerAuth()
@Controller("notifications")
@UseGuards(JwtAuthGuard)
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Get()
  @ApiOperation({ summary: "Get in-app notifications for the current user" })
  @ApiQuery({ name: "limit", required: false, type: Number })
  @ApiResponse({ status: 200, description: "Returns list of notifications" })
  async getNotifications(@Request() req: any, @Query("limit") limit?: number) {
    return this.notificationsService.getUserNotifications(
      req.user.id || req.user.sub,
      limit || 20,
    );
  }

  @Post("fcm-token")
  @ApiOperation({ summary: "Register or update FCM push token" })
  @ApiResponse({ status: 201, description: "FCM token registered" })
  async registerFcmToken(
    @Request() req: any,
    @Body() dto: RegisterFcmTokenDto,
  ) {
    return this.notificationsService.registerFcmToken(
      req.user.id || req.user.sub,
      dto.token,
    );
  }

  @Post("all/read")
  @ApiOperation({ summary: "Mark all notifications as read" })
  @ApiResponse({ status: 201, description: "All notifications marked as read" })
  async markAllAsRead(@Request() req: any) {
    return this.notificationsService.markAsRead(
      req.user.id || req.user.sub,
      "all",
    );
  }

  @Post(":id/read")
  @ApiOperation({ summary: "Mark a notification as read" })
  @ApiResponse({ status: 201, description: "Notification marked as read" })
  async markAsRead(@Request() req: any, @Param("id") id: string) {
    return this.notificationsService.markAsRead(
      req.user.id || req.user.sub,
      id,
    );
  }

  @Delete(":id")
  @ApiOperation({ summary: "Delete a notification" })
  @ApiResponse({ status: 200, description: "Notification deleted" })
  async deleteNotification(@Request() req: any, @Param("id") id: string) {
    return this.notificationsService.deleteNotification(
      req.user.id || req.user.sub,
      id,
    );
  }
}

import { Module, Logger } from "@nestjs/common";
import { ConfigModule, ConfigService } from "@nestjs/config";
import { ThrottlerModule, ThrottlerGuard } from "@nestjs/throttler";
import { APP_GUARD } from "@nestjs/core";
import { BullModule } from "@nestjs/bullmq";
import { ScheduleModule } from "@nestjs/schedule";
import { I18nModule, AcceptLanguageResolver } from "nestjs-i18n";
import * as path from "node:path";

// Core modules
import { PrismaModule } from "./prisma/prisma.module";
import { RedisModule } from "./redis/redis.module";

// Feature modules
import { AuthModule } from "./auth/auth.module";
import { UsersModule } from "./users/users.module";
import { StepsModule } from "./steps/steps.module";
import { RewardsModule } from "./rewards/rewards.module";
import { AdsModule } from "./ads/ads.module";
import { ChallengesModule } from "./challenges/challenges.module";
import { FriendsModule } from "./friends/friends.module";
import { OffersModule } from "./offers/offers.module";
import { CommunityModule } from "./community/community.module";
import { DevicesModule } from "./devices/devices.module";
import { NotificationsModule } from "./notifications/notifications.module";
import { TeamsModule } from "./teams/teams.module";
import { CompaniesModule } from "./companies/companies.module";
import { QuestsModule } from "./quests/quests.module";
import { MessagingModule } from "./messaging/messaging.module";
import { AnalyticsModule } from "./analytics/analytics.module";

import { ActivitiesModule } from "./activities/activities.module";

// Controllers
import { HealthController } from "./health.controller";

// Services
import { KeepAwakeService } from "./keep-awake.service";
import { SentryModule } from "@sentry/nestjs/setup";

@Module({
  imports: [
    // Configuration
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ".env",
    }),
    ScheduleModule.forRoot(),
    SentryModule.forRoot(),

    // Internationalization (i18n)
    I18nModule.forRoot({
      fallbackLanguage: "en",
      loaderOptions: {
        path: path.join(__dirname, "/i18n/"),
        watch: true,
      },
      resolvers: [AcceptLanguageResolver],
    }),

    // Rate limiting
    ThrottlerModule.forRoot([
      {
        ttl: 60000, // 1 minute
        limit: 100, // 100 requests per minute
      },
    ]),

    // Asynchronous Background Queues (BullMQ)
    BullModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => {
        const redisUrl = configService.get("REDIS_URL");
        if (redisUrl) {
          try {
            const url = new URL(redisUrl);
            return {
              connection: {
                host: url.hostname,
                port: Number.parseInt(url.port, 10) || 6379,
                password: url.password || undefined,
                tls: redisUrl.startsWith("rediss://") ? {} : undefined,
              },
            };
          } catch (e) {
            Logger.warn(
              `Failed to parse REDIS_URL for BullMQ, falling back to HOST/PORT: ${e.message}`,
            );
          }
        }

        return {
          connection: {
            host: configService.get("REDIS_HOST", "localhost"),
            port: configService.get("REDIS_PORT", 6379),
            password: configService.get("REDIS_PASSWORD") || undefined,
          },
        };
      },
    }),

    // Core
    PrismaModule,
    RedisModule,

    // Features
    AuthModule,
    UsersModule,
    StepsModule,
    RewardsModule,
    AdsModule,
    ChallengesModule,
    FriendsModule,
    OffersModule,
    CommunityModule,
    DevicesModule,
    NotificationsModule,
    TeamsModule,
    CompaniesModule,
    QuestsModule,
    MessagingModule,
    AnalyticsModule,

    ActivitiesModule,
  ],
  controllers: [HealthController],
  providers: [
    KeepAwakeService,
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
  ],
})
export class AppModule {}

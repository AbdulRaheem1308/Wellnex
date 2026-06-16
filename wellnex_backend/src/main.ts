// IMPORTANT: Make sure to import `instrument.ts` at the top of your file.
import "./instrument";

// Start OpenTelemetry SDK first
import { otelSDK } from "./tracing";
otelSDK.start();

import { NestFactory, HttpAdapterHost } from "@nestjs/core";
import { ValidationPipe, Logger } from "@nestjs/common";
import { AppModule } from "./app.module";
import helmet from "helmet";
import { SwaggerModule, DocumentBuilder } from "@nestjs/swagger";
import {
  WinstonModule,
  utilities as nestWinstonModuleUtilities,
} from "nest-winston";
import * as winston from "winston";
import { SentryExceptionFilter } from "./common/filters/sentry-exception.filter";

async function bootstrap() {
  // Strip console logs in production for security and performance
  if (process.env.NODE_ENV === "production") {
    // eslint-disable-next-line no-console
    console.log = function () {};
    // eslint-disable-next-line no-console
    console.debug = function () {};
    // eslint-disable-next-line no-console
    console.info = function () {};
  }

  // Configure Winston structured and colorized logging
  const winstonLogger = WinstonModule.createLogger({
    transports: [
      new winston.transports.Console({
        format: winston.format.combine(
          winston.format.timestamp(),
          winston.format.ms(),
          process.env.NODE_ENV === "production"
            ? winston.format.json()
            : nestWinstonModuleUtilities.format.nestLike("Wellnex", {
                colors: true,
                prettyPrint: true,
              }),
        ),
      }),
    ],
  });

  const app = await NestFactory.create(AppModule, {
    logger: winstonLogger,
  });

  const { I18nService } = await import("nestjs-i18n");
  const i18nService = app.get(I18nService);

  // Global Sentry Exception Filter
  const { httpAdapter } = app.get(HttpAdapterHost);
  app.useGlobalFilters(new SentryExceptionFilter(httpAdapter, i18nService));

  // Global prefix for all routes
  app.setGlobalPrefix("api/v1");

  // Security Headers
  app.use(helmet());

  // Configure secure CORS policy
  const allowedOrigins = new Set([
    "http://localhost:3000",
    "http://localhost:5173",
    "https://joinwellnex.com",
    "https://admin.joinwellnex.com",
  ]);

  app.enableCors({
    origin: (
      origin: string,
      callback: (err: Error | null, allow?: boolean) => void,
    ) => {
      // Allow requests with no origin (like mobile apps) or specific allowed web origins
      if (!origin || allowedOrigins.has(origin)) {
        callback(null, true);
      } else {
        callback(new Error("Blocked by CORS"));
      }
    },
    credentials: true,
  });

  // Global validation pipe
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: {
        enableImplicitConversion: true,
      },
    }),
  );

  // Setup interactive Swagger documentation
  const config = new DocumentBuilder()
    .setTitle("Wellnex API")
    .setDescription(
      "Wellnex - Fitness Step Tracking API Documentation (Hardened & Secure)",
    )
    .setVersion("1.0.0")
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup("api/docs", app, document);

  const port = process.env.PORT || 3000;
  await app.listen(port, "0.0.0.0");

  const baseUrl =
    process.env.RENDER_EXTERNAL_URL ||
    process.env.APP_URL ||
    `http://localhost:${port}`;

  Logger.log(`🚀 Wellnex API running on: ${baseUrl}`);
  Logger.log(`📚 API Base URL: ${baseUrl}/api/v1`);
  Logger.log(`📖 Swagger API Docs: ${baseUrl}/api/docs`);
}

bootstrap();

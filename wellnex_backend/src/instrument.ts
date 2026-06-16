import * as Sentry from "@sentry/nestjs";
import * as dotenv from "dotenv";

// Load environment variables early so we can read SENTRY_DSN
dotenv.config();

Sentry.init({
  dsn: process.env.SENTRY_DSN || "https://mockDsnKey@o0.ingest.sentry.io/0",
  environment: process.env.NODE_ENV || "development",
  tracesSampleRate: 1,
});

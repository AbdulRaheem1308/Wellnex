import {
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
} from "@nestjs/common";
import { BaseExceptionFilter } from "@nestjs/core";
import * as Sentry from "@sentry/nestjs";
import { I18nService } from "nestjs-i18n";
import { Request, Response } from "express";
import { SentryExceptionCaptured } from "@sentry/nestjs";

@Catch()
export class SentryExceptionFilter extends BaseExceptionFilter {
  constructor(
    applicationRef: any,
    private readonly i18n: I18nService,
  ) {
    super(applicationRef);
  }

  @SentryExceptionCaptured()
  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    const isHttpException = exception instanceof HttpException;
    const status = isHttpException
      ? exception.getStatus()
      : HttpStatus.INTERNAL_SERVER_ERROR;

    if (status >= 500 || !isHttpException) {
      // Sentry is now capturing exceptions automatically via @SentryExceptionCaptured()
    }

    // Custom translation logic
    if (isHttpException) {
      const errorResponse = exception.getResponse() as any;
      const message = errorResponse.message || exception.message;

      // Try to translate the message if it's a known string key (e.g. "errors.NOT_FOUND")
      if (typeof message === "string" && message.includes(".")) {
        const translateResult = this.i18n.translate(message, {
          lang: (request.headers["accept-language"] as string) || "en",
        });

        if (typeof (translateResult as any)?.then === "function") {
          (translateResult as Promise<any>)
            .then((translated: any) => {
              response.status(status).json({
                statusCode: status,
                timestamp: new Date().toISOString(),
                path: request.url,
                message: translated,
              });
            })
            .catch(() => {
              response.status(status).json({
                statusCode: status,
                timestamp: new Date().toISOString(),
                path: request.url,
                message: message,
              });
            });
        } else {
          // If it's synchronous
          response.status(status).json({
            statusCode: status,
            timestamp: new Date().toISOString(),
            path: request.url,
            message: translateResult,
          });
        }
        return;
      }

      response.status(status).json({
        statusCode: status,
        timestamp: new Date().toISOString(),
        path: request.url,
        message: message,
      });
      return;
    }

    super.catch(exception, host);
  }
}

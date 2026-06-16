import { SentryExceptionFilter } from "./sentry-exception.filter";
import { HttpException } from "@nestjs/common";
import { I18nService } from "nestjs-i18n";
import * as Sentry from "@sentry/nestjs";
import { BaseExceptionFilter } from "@nestjs/core";

jest.mock("@sentry/nestjs", () => ({
  captureException: jest.fn(),
  SentryExceptionCaptured: jest.fn(() => {
    return (target: any, propertyKey: string, descriptor: PropertyDescriptor) => {
      return descriptor;
    };
  }),
}));

describe("SentryExceptionFilter", () => {
  let filter: SentryExceptionFilter;
  let i18nService: I18nService;
  let applicationRef: any;

  beforeEach(() => {
    jest.clearAllMocks();
    applicationRef = {};
    i18nService = {
      translate: jest.fn(),
    } as any;

    filter = new SentryExceptionFilter(applicationRef, i18nService);
    // Mock super.catch
    jest
      .spyOn(BaseExceptionFilter.prototype, "catch")
      .mockImplementation(jest.fn());
  });

  const mockArgumentsHost = (requestExtras = {}): any => {
    const res: any = {};
    res.status = jest.fn().mockReturnValue(res);
    res.json = jest.fn().mockReturnValue(res);

    return {
      switchToHttp: () => ({
        getRequest: () => ({
          url: "/test",
          headers: { "accept-language": "en" },
          ...requestExtras,
        }),
        getResponse: () => res,
      }),
    };
  };

  it("should format response for 500 exceptions", () => {
    const error = new HttpException("Internal error", 500);
    const host = mockArgumentsHost();

    filter.catch(error, host);
  });

  it("should handle < 500 HttpExceptions", () => {
    const error = new HttpException("Bad request", 400);
    const host = mockArgumentsHost();
    filter.catch(error, host);
  });

  it("should translate string keys and respond synchronously", () => {
    const error = new HttpException("errors.NOT_FOUND", 404);
    const host = mockArgumentsHost();
    const response = host.switchToHttp().getResponse();

    (i18nService.translate as jest.Mock).mockReturnValue(
      "Not Found Translated",
    );

    filter.catch(error, host);

    expect(i18nService.translate).toHaveBeenCalledWith("errors.NOT_FOUND", {
      lang: "en",
    });
    expect(response.status).toHaveBeenCalledWith(404);
    expect(response.json).toHaveBeenCalledWith(
      expect.objectContaining({
        message: "Not Found Translated",
        statusCode: 404,
      }),
    );
  });

  it("should translate string keys and respond asynchronously", async () => {
    const error = new HttpException("errors.NOT_FOUND", 404);
    const host = mockArgumentsHost();
    const response = host.switchToHttp().getResponse();

    (i18nService.translate as jest.Mock).mockReturnValue(
      Promise.resolve("Not Found Translated"),
    );

    filter.catch(error, host);

    await new Promise(process.nextTick);

    expect(response.status).toHaveBeenCalledWith(404);
    expect(response.json).toHaveBeenCalledWith(
      expect.objectContaining({
        message: "Not Found Translated",
      }),
    );
  });

  it("should handle async translation rejection", async () => {
    const error = new HttpException("errors.NOT_FOUND", 404);
    const host = mockArgumentsHost();
    const response = host.switchToHttp().getResponse();

    (i18nService.translate as jest.Mock).mockReturnValue(
      Promise.reject(new Error("Translation failed")),
    );

    filter.catch(error, host);

    await new Promise(process.nextTick);

    expect(response.status).toHaveBeenCalledWith(404);
    expect(response.json).toHaveBeenCalledWith(
      expect.objectContaining({
        message: "errors.NOT_FOUND",
      }),
    );
  });

  it("should handle non-translated string messages", () => {
    const error = new HttpException("Regular error message", 400);
    const host = mockArgumentsHost();
    const response = host.switchToHttp().getResponse();

    filter.catch(error, host);

    expect(i18nService.translate).not.toHaveBeenCalled();
    expect(response.status).toHaveBeenCalledWith(400);
    expect(response.json).toHaveBeenCalledWith(
      expect.objectContaining({
        message: "Regular error message",
      }),
    );
  });

  it("should handle non-HttpExceptions by delegating to super", () => {
    const error = new Error("Regular Error");
    const host = mockArgumentsHost();
    filter.catch(error, host);

    expect(BaseExceptionFilter.prototype.catch).toHaveBeenCalledWith(
      error,
      host,
    );
  });
});

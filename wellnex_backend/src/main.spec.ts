/* eslint-disable no-console */
import { Logger } from "@nestjs/common";

jest.mock("@nestjs/core", () => {
  const mockApp = {
    get: jest.fn().mockReturnValue({}),
    useGlobalFilters: jest.fn(),
    setGlobalPrefix: jest.fn(),
    use: jest.fn(),
    enableCors: jest.fn(),
    useGlobalPipes: jest.fn(),
    listen: jest.fn().mockResolvedValue(true),
  };
  return {
    NestFactory: {
      create: jest.fn().mockResolvedValue(mockApp),
    },
    HttpAdapterHost: jest.fn().mockImplementation(() => ({})),
  };
});

jest.mock("./app.module", () => ({
  AppModule: class {},
}));

jest.mock("./tracing", () => ({
  otelSDK: { start: jest.fn() },
}));

jest.mock("./instrument", () => ({}));

jest.mock("@sentry/nestjs", () => ({
  init: jest.fn(),
}));

jest.mock("./common/filters/sentry-exception.filter", () => ({
  SentryExceptionFilter: class {},
}));

jest.mock("nestjs-i18n", () => ({
  I18nService: class {},
}));

jest.mock("@nestjs/swagger", () => {
  return {
    SwaggerModule: {
      createDocument: jest.fn(),
      setup: jest.fn(),
    },
    DocumentBuilder: class {
      setTitle() {
        return this;
      }
      setDescription() {
        return this;
      }
      setVersion() {
        return this;
      }
      addBearerAuth() {
        return this;
      }
      build() {
        return {};
      }
    },
  };
});

describe("Main Bootstrap", () => {
  let loggerSpy: jest.SpyInstance;
  let originalEnv: string | undefined;
  let mockApp: any;

  beforeAll(() => {
    loggerSpy = jest.spyOn(Logger, "log").mockImplementation(() => {});
    originalEnv = process.env.NODE_ENV;
  });

  beforeEach(() => {
    jest.resetModules();

    mockApp = {
      get: jest.fn().mockReturnValue({}),
      useGlobalFilters: jest.fn(),
      setGlobalPrefix: jest.fn(),
      use: jest.fn(),
      enableCors: jest.fn(),
      useGlobalPipes: jest.fn(),
      listen: jest.fn().mockResolvedValue(true),
    };

    jest.mock("@nestjs/core", () => ({
      NestFactory: {
        create: jest.fn().mockResolvedValue(mockApp),
      },
      HttpAdapterHost: jest.fn().mockImplementation(() => ({})),
    }));

    jest.mock("./app.module", () => ({ AppModule: class {} }));
    jest.mock("./tracing", () => ({ otelSDK: { start: jest.fn() } }));
    jest.mock("./instrument", () => ({}));
    jest.mock("@sentry/nestjs", () => ({ init: jest.fn() }));
    jest.mock("./common/filters/sentry-exception.filter", () => ({
      SentryExceptionFilter: class {},
    }));
    jest.mock("nestjs-i18n", () => ({ I18nService: class {} }));
    jest.mock("@nestjs/swagger", () => ({
      SwaggerModule: { createDocument: jest.fn(), setup: jest.fn() },
      DocumentBuilder: class {
        setTitle() {
          return this;
        }
        setDescription() {
          return this;
        }
        setVersion() {
          return this;
        }
        addBearerAuth() {
          return this;
        }
        build() {
          return {};
        }
      },
    }));
  });

  afterAll(() => {
    loggerSpy.mockRestore();
    process.env.NODE_ENV = originalEnv;
  });

  it("should bootstrap the application in development mode", async () => {
    process.env.NODE_ENV = "development";
    require("./main");
    await new Promise((resolve) => setTimeout(resolve, 100));

    expect(mockApp.listen).toHaveBeenCalled();

    // Test CORS callback
    const corsArgs = mockApp.enableCors.mock.calls[0][0];
    const callback = jest.fn();
    corsArgs.origin("http://localhost:3000", callback);
    expect(callback).toHaveBeenCalledWith(null, true);

    const failCallback = jest.fn();
    corsArgs.origin("http://evil.com", failCallback);
    expect(failCallback).toHaveBeenCalledWith(expect.any(Error));

    const noOriginCallback = jest.fn();
    corsArgs.origin(undefined, noOriginCallback);
    expect(noOriginCallback).toHaveBeenCalledWith(null, true);
  });

  it("should strip console logs in production mode", async () => {
    process.env.NODE_ENV = "production";
    const originalConsoleLog = console.log;

    require("./main");
    await new Promise((resolve) => setTimeout(resolve, 100));

    expect(console.log).not.toBe(originalConsoleLog);

    // Reset console
    console.log = originalConsoleLog;
  });
});

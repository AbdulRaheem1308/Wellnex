import { Test, TestingModule } from "@nestjs/testing";
import { OtpService } from "./otp.service";
import { ConfigService } from "@nestjs/config";
import { Logger } from "@nestjs/common";

jest.mock("twilio", () => {
  return {
    __esModule: true,
    default: jest.fn().mockImplementation(() => {
      return {
        messages: {
          create: jest.fn().mockResolvedValue({ sid: "test-sid" }),
        },
      };
    }),
  };
});

jest.mock("resend", () => ({
  Resend: jest.fn().mockImplementation(() => ({
    emails: {
      send: jest.fn(),
    },
  })),
}));


describe("OtpService", () => {
  let mockConfigService: any;

  beforeEach(() => {
    jest.clearAllMocks();
    global.fetch = jest.fn();
    mockConfigService = {
      get: jest.fn((key) => {
        if (key === "NODE_ENV") return "development";
        if (key === "OTP_LENGTH") return 6;
        return null;
      }),
    };
  });

  describe("Initialization", () => {
    it("should initialize without twilio if missing config", () => {
      const warnSpy = jest.spyOn(Logger.prototype, "warn").mockImplementation();
      const service = new OtpService(mockConfigService);
      expect((service as any).twilioClient).toBeNull();
      expect(warnSpy).toHaveBeenCalledWith(
        "Twilio not configured - OTPs will be logged to console",
      );
      warnSpy.mockRestore();
    });

    it("should log critical error in production if twilio missing", () => {
      mockConfigService.get.mockImplementation((k: string) =>
        k === "NODE_ENV" ? "production" : null,
      );
      const errorSpy = jest
        .spyOn(Logger.prototype, "error")
        .mockImplementation();

      new OtpService(mockConfigService);
      expect(errorSpy).toHaveBeenCalledWith(
        "CRITICAL: Twilio credentials missing or invalid in PRODUCTION mode! SMS OTPs will fail.",
      );
      errorSpy.mockRestore();
    });

    it("should initialize twilio if config is valid", () => {
      mockConfigService.get.mockImplementation((k: string) => {
        if (k === "TWILIO_ACCOUNT_SID") return "valid-sid";
        if (k === "TWILIO_AUTH_TOKEN") return "valid-token";
        return null;
      });
      const logSpy = jest.spyOn(Logger.prototype, "log").mockImplementation();
      const validService = new OtpService(mockConfigService);
      expect((validService as any).twilioClient).not.toBeNull();
      logSpy.mockRestore();
    });
  });

  describe("Methods", () => {
    let service: OtpService;
    let loggerLogSpy: jest.SpyInstance;

    beforeEach(async () => {
      const module: TestingModule = await Test.createTestingModule({
        providers: [
          OtpService,
          { provide: ConfigService, useValue: mockConfigService },
        ],
      }).compile();

      service = module.get<OtpService>(OtpService);
      loggerLogSpy = jest
        .spyOn((service as any).logger, "log")
        .mockImplementation();
    });

    describe("generateOtp", () => {
      it("should generate a 6 digit otp by default", () => {
        const otp = service.generateOtp();
        expect(otp).toHaveLength(6);
        expect(Number(otp)).not.toBeNaN();
      });

      it("should respect OTP_LENGTH config", () => {
        mockConfigService.get.mockImplementation((k: string) => {
          if (k === "OTP_LENGTH") return 4;
          return null;
        });
        const lengthService = new OtpService(mockConfigService);
        const otp = lengthService.generateOtp();
        expect(otp).toHaveLength(4);
      });
    });

    describe("sendSmsOtp", () => {
      it("should use twilio if client initialized", async () => {
        mockConfigService.get.mockImplementation((k: string) => {
          if (k === "TWILIO_ACCOUNT_SID") return "valid-sid";
          if (k === "TWILIO_AUTH_TOKEN") return "valid-token";
          if (k === "TWILIO_PHONE_NUMBER") return "123456";
          return null;
        });

        const validService = new OtpService(mockConfigService);
        const validLoggerSpy = jest
          .spyOn((validService as any).logger, "log")
          .mockImplementation();

        await validService.sendSmsOtp("phone1", "123456");

        const twilioClient = (validService as any).twilioClient;
        expect(twilioClient.messages.create).toHaveBeenCalledWith({
          body: "Your Wellnex verification code is: 123456. Valid for 5 minutes.",
          from: "123456",
          to: "phone1",
        });
        expect(validLoggerSpy).toHaveBeenCalledWith("OTP sent to phone1");
      });

      it("should fallback to dev log if twilio fails to send", async () => {
        mockConfigService.get.mockImplementation((k: string) => {
          if (k === "TWILIO_ACCOUNT_SID") return "valid-sid";
          if (k === "TWILIO_AUTH_TOKEN") return "valid-token";
          return null;
        });

        const validService = new OtpService(mockConfigService);
        const validErrorSpy = jest
          .spyOn((validService as any).logger, "error")
          .mockImplementation();
        const validLogSpy = jest
          .spyOn((validService as any).logger, "log")
          .mockImplementation();

        const twilioClient = (validService as any).twilioClient;
        twilioClient.messages.create.mockRejectedValueOnce(
          new Error("Twilio error"),
        );

        await validService.sendSmsOtp("phone2", "111111");

        expect(validErrorSpy).toHaveBeenCalledWith(
          "Failed to send SMS to phone2:",
          "Twilio error",
        );
        expect(validLogSpy).toHaveBeenCalledWith("Code: 111111");
      });

      it("should log to console if no twilio client", async () => {
        await service.sendSmsOtp("phone3", "222222");
        expect(loggerLogSpy).toHaveBeenCalledWith("Code: 222222");
      });
    });

    describe("sendEmailOtp", () => {
      it("should use resend if client initialized", async () => {
        mockConfigService.get.mockImplementation((k: string) => {
          if (k === "RESEND_API_KEY") return "valid-key";
          return null;
        });

        const validService = new OtpService(mockConfigService);
        const validLoggerSpy = jest
          .spyOn((validService as any).logger, "log")
          .mockImplementation();

        const resendClient = (validService as any).resendClient;
        resendClient.emails.send.mockResolvedValueOnce({ id: "123" });

        await validService.sendEmailOtp("test@test.com", "555555");

        expect(resendClient.emails.send).toHaveBeenCalled();
        expect(validLoggerSpy).toHaveBeenCalledWith(
          "OTP sent via email to test@test.com",
        );
      });

      it("should fallback to brevo if resend fails", async () => {
        mockConfigService.get.mockImplementation((k: string) => {
          if (k === "RESEND_API_KEY") return "valid-key";
          if (k === "BREVO_API_KEY") return "valid-brevo-key";
          return null;
        });

        const validService = new OtpService(mockConfigService);
        const validLoggerSpy = jest
          .spyOn((validService as any).logger, "log")
          .mockImplementation();

        const resendClient = (validService as any).resendClient;

        resendClient.emails.send.mockRejectedValueOnce(
          new Error("resend down"),
        );
        
        (global.fetch as jest.Mock).mockResolvedValueOnce({
          ok: true,
          json: async () => ({ messageId: "456" }),
        });

        await validService.sendEmailOtp("test@test.com", "555555");

        expect(resendClient.emails.send).toHaveBeenCalled();
        expect(global.fetch).toHaveBeenCalledWith(
          "https://api.brevo.com/v3/smtp/email",
          expect.any(Object)
        );
        expect(validLoggerSpy).toHaveBeenCalledWith(
          "OTP successfully sent via Brevo fallback to test@test.com",
        );
      });

      it("should log email OTP to console if no resend client", async () => {
        await service.sendEmailOtp("test@test.com", "555555");
        expect(loggerLogSpy).toHaveBeenCalledWith("Code: 555555");
        expect(loggerLogSpy).toHaveBeenCalledWith(
          "DEV MODE - OTP for test@test.com",
        );
      });
    });
  });
});

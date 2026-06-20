import { Injectable, Logger } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import Twilio from "twilio";
import * as crypto from "node:crypto";
import { Resend } from "resend";
import * as brevo from "@getbrevo/brevo";

@Injectable()
export class OtpService {
  private readonly logger = new Logger(OtpService.name);
  private readonly twilioClient: Twilio.Twilio | null = null;
  private readonly resendClient: Resend | null = null;
  private readonly brevoClient: brevo.TransactionalEmailsApi | null = null;

  constructor(private readonly configService: ConfigService) {
    const accountSid = this.configService.get("TWILIO_ACCOUNT_SID");
    const authToken = this.configService.get("TWILIO_AUTH_TOKEN");
    const isProduction = this.configService.get("NODE_ENV") === "production";

    if (accountSid && authToken && !accountSid.startsWith("AC_YOUR")) {
      this.twilioClient = Twilio(accountSid, authToken);
      this.logger.log("Twilio client initialized");
    } else {
      if (isProduction) {
        this.logger.error(
          "CRITICAL: Twilio credentials missing or invalid in PRODUCTION mode! SMS OTPs will fail.",
        );
      }
      this.logger.warn(
        "Twilio not configured - OTPs will be logged to console",
      );
    }

    const resendApiKey = this.configService.get("RESEND_API_KEY");

    if (resendApiKey) {
      this.resendClient = new Resend(resendApiKey);
      this.logger.log("Resend client initialized");
    } else {
      if (isProduction) {
        this.logger.error(
          "CRITICAL: RESEND_API_KEY missing in PRODUCTION mode! Email OTPs will fail.",
        );
      }
      this.logger.warn(
        "Resend not configured - Email OTPs will be logged to console",
      );
    }

    const brevoApiKey = this.configService.get("BREVO_API_KEY");
    if (brevoApiKey) {
      this.brevoClient = new brevo.TransactionalEmailsApi();
      this.brevoClient.setApiKey(
        brevo.TransactionalEmailsApiApiKeys.apiKey,
        brevoApiKey,
      );
      this.logger.log("Brevo client initialized for fallback");
    }
  }

  generateOtp(): string {
    const length = this.configService.get<number>("OTP_LENGTH", 6);
    let otp = "";
    for (let i = 0; i < length; i++) {
      otp += crypto.randomInt(0, 10).toString();
    }
    return otp;
  }

  async sendSmsOtp(phone: string, otp: string): Promise<void> {
    const message = `Your Wellnex verification code is: ${otp}. Valid for 5 minutes.`;

    if (this.twilioClient) {
      try {
        await this.twilioClient.messages.create({
          body: message,
          from: this.configService.get("TWILIO_PHONE_NUMBER"),
          to: phone,
        });
        this.logger.log(`OTP sent to ${phone}`);
      } catch (error) {
        this.logger.error(`Failed to send SMS to ${phone}:`, error.message);
        this.logOtpForDevelopment(phone, otp);
      }
    } else {
      this.logOtpForDevelopment(phone, otp);
    }
  }

  async sendEmailOtp(email: string, otp: string): Promise<void> {
    if (this.resendClient) {
      try {
        const fromEmail = "Wellnex <no-reply@joinwellnex.com>";
        await this.resendClient.emails.send({
          from: fromEmail,
          to: email,
          subject: "Your Wellnex OTP Verification Code",
          text: `Your Wellnex verification code is: ${otp}. Valid for 5 minutes.`,
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 10px;">
              <h2 style="color: #4CAF50; text-align: center;">Welcome to Wellnex!</h2>
              <p style="font-size: 16px; color: #333;">Hello,</p>
              <p style="font-size: 16px; color: #333;">Your verification code is:</p>
              <div style="background-color: #f5f5f5; padding: 15px; border-radius: 5px; text-align: center; margin: 20px 0;">
                <span style="font-size: 24px; font-weight: bold; letter-spacing: 5px; color: #333;">${otp}</span>
              </div>
              <p style="font-size: 14px; color: #666;">This code is valid for 5 minutes. Please do not share it with anyone.</p>
              <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 20px 0;" />
              <p style="font-size: 12px; color: #999; text-align: center;">If you did not request this code, please ignore this email.</p>
            </div>
          `,
        });
        this.logger.log(`OTP sent via email to ${email}`);
      } catch (error: any) {
        this.logger.warn(`Resend failed for ${email}, attempting fallback to Brevo: ${error.message}`);
        
        if (this.brevoClient) {
          try {
            const sendSmtpEmail = new brevo.SendSmtpEmail();
            sendSmtpEmail.subject = "Your Wellnex OTP Verification Code";
            sendSmtpEmail.htmlContent = `
              <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 10px;">
                <h2 style="color: #4CAF50; text-align: center;">Welcome to Wellnex!</h2>
                <p style="font-size: 16px; color: #333;">Hello,</p>
                <p style="font-size: 16px; color: #333;">Your verification code is:</p>
                <div style="background-color: #f5f5f5; padding: 15px; border-radius: 5px; text-align: center; margin: 20px 0;">
                  <span style="font-size: 24px; font-weight: bold; letter-spacing: 5px; color: #333;">${otp}</span>
                </div>
                <p style="font-size: 14px; color: #666;">This code is valid for 5 minutes. Please do not share it with anyone.</p>
                <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 20px 0;" />
                <p style="font-size: 12px; color: #999; text-align: center;">If you did not request this code, please ignore this email.</p>
              </div>
            `;
            sendSmtpEmail.sender = { name: "Wellnex", email: "no-reply@joinwellnex.com" };
            sendSmtpEmail.to = [{ email: email }];
            
            await this.brevoClient.sendTransacEmail(sendSmtpEmail);
            this.logger.log(`OTP successfully sent via Brevo fallback to ${email}`);
          } catch (brevoError: any) {
            this.logger.error(`Both Resend and Brevo failed to send email to ${email}:`, brevoError.message);
            this.logOtpForDevelopment(email, otp);
          }
        } else {
          this.logger.error(`No Brevo client configured for fallback. Failed to send email to ${email}`);
          this.logOtpForDevelopment(email, otp);
        }
      }
    } else {
      this.logOtpForDevelopment(email, otp);
    }
  }

  private logOtpForDevelopment(identifier: string, otp: string): void {
    this.logger.log("\n========================================");
    this.logger.log(`DEV MODE - OTP for ${identifier}`);
    this.logger.log(`Code: ${otp}`);
    this.logger.log("========================================\n");
  }
}

import { Injectable, Logger } from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import * as admin from "firebase-admin";
import { Resend } from "resend";

export interface NotificationItem {
  id: string;
  title: string;
  message: string;
  type: string;
  isRead: boolean;
  createdAt: Date;
}

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);
  private readonly fcmEnabled: boolean;
  private readonly resendClient: Resend | null = null;
  private readonly brevoApiKey: string | null = null;

  constructor(private readonly prisma: PrismaService) {
    // Firebase Admin is initialized once in the app lifecycle.
    // If it hasn't been initialized yet (first service to use it), initialize now.
    if (!admin.apps.length) {
      const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;

      if (serviceAccountJson) {
        try {
          const serviceAccount = JSON.parse(serviceAccountJson);
          admin.initializeApp({
            credential: admin.credential.cert(serviceAccount),
          });
          this.logger.log(
            "Firebase Admin SDK initialized from FIREBASE_SERVICE_ACCOUNT_JSON",
          );
        } catch (e) {
          this.logger.error("Failed to parse FIREBASE_SERVICE_ACCOUNT_JSON", e);
        }
      } else {
        this.logger.warn(
          "FIREBASE_SERVICE_ACCOUNT_JSON not set — FCM push notifications disabled. " +
            "Download your Firebase service account JSON and set it as a single-line env var.",
        );
      }
    }

    this.fcmEnabled = admin.apps.length > 0;

    // Initialize Resend for Emails
    const resendApiKey = process.env.RESEND_API_KEY;
    if (resendApiKey) {
      this.resendClient = new Resend(resendApiKey);
    }

    const brevoApiKey = process.env.BREVO_API_KEY;
    if (brevoApiKey) {
      this.brevoApiKey = brevoApiKey;
      this.logger.log("Brevo API key initialized for notifications fallback");
    }
  }

  // ── FCM Token Registration ─────────────────────────────────────────────────

  /**
   * Store the FCM token for a user (called from mobile on login or token refresh).
   * The token is updated on every login so we always have the latest device token.
   */
  async registerFcmToken(
    userId: string,
    token: string,
  ): Promise<{ success: boolean }> {
    await this.prisma.user.update({
      where: { id: userId },
      data: { fcmToken: token },
    });
    this.logger.log(`FCM token registered for user ${userId}`);
    return { success: true };
  }

  // ── FCM Push Dispatch ──────────────────────────────────────────────────────

  /**
   * Send a push notification to a specific user.
   * Silently skips if user has no FCM token or FCM is not configured.
   */
  async sendPushToUser(
    userId: string,
    title: string,
    body: string,
    data?: Record<string, string>,
  ): Promise<void> {
    if (!this.fcmEnabled) return;

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        fcmToken: true,
        settings: {
          select: { pushNotifications: true },
        },
      },
    });

    if (!user?.fcmToken) {
      this.logger.debug(`No FCM token for user ${userId} — skipping push`);
      return;
    }

    // Explicitly check user settings (default is true if settings object doesn't exist yet)
    const pushEnabled = user.settings?.pushNotifications ?? true;
    if (!pushEnabled) {
      this.logger.debug(
        `User ${userId} has push notifications disabled in settings — skipping FCM dispatch`,
      );
      return;
    }

    await this.sendFcmMessage(user.fcmToken, title, body, data);
  }

  /**
   * Send a push notification directly to a known FCM token.
   */
  async sendFcmMessage(
    token: string,
    title: string,
    body: string,
    data?: Record<string, string>,
  ): Promise<void> {
    if (!this.fcmEnabled) return;

    const message: admin.messaging.Message = {
      token,
      notification: { title, body },
      data: data ?? {},
      android: {
        priority: "high",
        notification: {
          channelId: "wellnex_default",
          sound: "default",
          icon: "ic_notification",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    try {
      const result = await admin.messaging().send(message);
      this.logger.log(`FCM message sent: ${result}`);
    } catch (err: any) {
      // If token is invalid/expired, clear it from DB to avoid future attempts
      if (
        err?.code === "messaging/invalid-registration-token" ||
        err?.code === "messaging/registration-token-not-registered"
      ) {
        this.logger.warn(
          `FCM token invalid, clearing from DB for token ending in ...${token.slice(-8)}`,
        );
        await this.prisma.user.updateMany({
          where: { fcmToken: token },
          data: { fcmToken: null },
        });
      } else {
        this.logger.error(`FCM send failed: ${err?.message}`);
      }
    }
  }

  /**
   * Broadcast to all users with a stored FCM token (e.g. app-wide announcements).
   * Uses FCM multicast in batches of 500 (FCM limit).
   */
  async broadcastToAll(
    title: string,
    body: string,
    data?: Record<string, string>,
  ): Promise<void> {
    if (!this.fcmEnabled) return;

    const batchSize = 500;
    let cursorId: string | null = null;
    let hasMore = true;
    let batchNumber = 1;

    while (hasMore) {
      const query: any = {
        where: { fcmToken: { not: null }, isActive: true },
        select: { id: true, fcmToken: true },
        take: batchSize,
        orderBy: { id: "asc" },
      };

      if (cursorId) {
        query.skip = 1;
        query.cursor = { id: cursorId };
      }

      const users = await this.prisma.user.findMany(query);

      if (users.length === 0) {
        break;
      }

      cursorId = users.at(-1)!.id;

      const tokens = users
        .map((u: { fcmToken: string | null }) => u.fcmToken!)
        .filter(Boolean);

      if (tokens.length > 0) {
        const multicastMessage: admin.messaging.MulticastMessage = {
          tokens,
          notification: { title, body },
          data: data ?? {},
          android: { priority: "high" },
        };
        try {
          const result = await admin
            .messaging()
            .sendEachForMulticast(multicastMessage);
          this.logger.log(
            `Broadcast batch ${batchNumber}: ${result.successCount} sent, ${result.failureCount} failed`,
          );
        } catch (err: any) {
          this.logger.error(
            `Broadcast batch ${batchNumber} failed: ${err?.message}`,
          );
        }
      }

      if (users.length < batchSize) {
        hasMore = false;
      }
      batchNumber++;
    }
  }

  // ── In-App Notifications & Email (DB) ──────────────────────────────────────────────

  /**
   * Send an Email Notification
   */
  async sendEmail(to: string, subject: string, html: string): Promise<boolean> {
    if (!this.resendClient) {
      this.logger.debug(
        `Email not sent to ${to} (Resend API key not configured)`,
      );
      return false;
    }

    try {
      await this.resendClient.emails.send({
        from: "Wellnex <no-reply@joinwellnex.com>",
        to,
        subject,
        html,
      });
      this.logger.log(`Email sent successfully to ${to} via Resend`);
      return true;
    } catch (error: any) {
      this.logger.warn(
        `Resend failed for ${to}, attempting fallback to Brevo: ${error.message}`,
      );

      if (this.brevoApiKey) {
        try {
          const response = await fetch("https://api.brevo.com/v3/smtp/email", {
            method: "POST",
            headers: {
              "api-key": this.brevoApiKey,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              sender: { name: "Wellnex", email: "no-reply@joinwellnex.com" },
              to: [{ email: to }],
              subject: subject,
              htmlContent: html,
            }),
          });

          if (!response.ok) {
            throw new Error(`Brevo API error: ${response.statusText}`);
          }

          this.logger.log(
            `Email successfully sent via Brevo fallback to ${to}`,
          );
          return true;
        } catch (brevoError: any) {
          this.logger.error(
            `Both Resend and Brevo failed to send email to ${to}:`,
            brevoError.message,
          );
          return false;
        }
      } else {
        this.logger.error(
          `No Brevo client configured for fallback. Failed to send email to ${to}`,
        );
        return false;
      }
    }
  }

  /**
   * Create an in-app notification record AND send push/email if configured.
   */
  async createAndNotify(
    userId: string,
    title: string,
    message: string,
    type: string,
    pushData?: Record<string, string>,
    sendEmail: boolean = false,
  ): Promise<void> {
    // Store in DB
    await this.prisma.notification.create({
      data: { userId, title, message, type },
    });

    // Push to device
    await this.sendPushToUser(userId, title, message, pushData);

    // Send Email if requested
    if (sendEmail) {
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { email: true },
      });
      if (user?.email) {
        await this.sendEmail(
          user.email,
          title,
          `<h3>${title}</h3><p>${message}</p><br/><p>Keep stepping with Wellnex!</p>`,
        );
      }
    }
  }

  // Get user notifications from DB
  async getUserNotifications(
    userId: string,
    limit = 20,
  ): Promise<NotificationItem[]> {
    const notifications = await this.prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: "desc" },
      take: limit,
    });

    return notifications.map((n) => ({
      id: n.id,
      title: n.title,
      message: n.message,
      type: n.type,
      isRead: n.isRead,
      createdAt: n.createdAt,
    }));
  }

  // Mark notification as read
  async markAsRead(userId: string, notificationId: string) {
    if (notificationId === "all") {
      await this.prisma.notification.updateMany({
        where: { userId, isRead: false },
        data: { isRead: true },
      });
      return { success: true };
    }

    await this.prisma.notification.update({
      where: { id: notificationId },
      data: { isRead: true },
    });
    return { success: true };
  }

  // Delete notification
  async deleteNotification(userId: string, notificationId: string) {
    await this.prisma.notification.delete({
      where: { id: notificationId },
    });
    return { success: true };
  }
}

import { Injectable, OnModuleDestroy, Logger } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { Redis } from "ioredis";

@Injectable()
export class RedisService implements OnModuleDestroy {
  private readonly logger = new Logger(RedisService.name);
  private readonly client: Redis;
  private readonly isProduction: boolean;
  private readonly memoryStore = new Map<
    string,
    { value: any; expiry: number }
  >();
  private readonly sweepInterval: NodeJS.Timeout;

  constructor(private readonly configService: ConfigService) {
    this.isProduction = this.configService.get("NODE_ENV") === "production";

    // Memory leak prevention: sweep expired keys every 5 minutes
    this.sweepInterval = setInterval(
      () => {
        const now = Date.now();
        let swept = 0;
        for (const [key, item] of this.memoryStore.entries()) {
          if (item.expiry < now) {
            this.memoryStore.delete(key);
            swept++;
          }
        }
        if (swept > 0) {
          this.logger.debug(
            `Swept ${swept} expired items from fallback memory store`,
          );
        }
      },
      5 * 60 * 1000,
    );

    const redisUrl = this.configService.get("REDIS_URL");
    const redisOptions = {
      host: this.configService.get("REDIS_HOST", "localhost"),
      port: this.configService.get("REDIS_PORT", 6379),
      password: this.configService.get("REDIS_PASSWORD") || undefined,
      retryStrategy: (times: number) => {
        if (times > 3) {
          const msg = "⚠️ Redis connection failed, running without cache";
          if (this.isProduction)
            this.logger.error(
              "CRITICAL: Redis connection failing in PRODUCTION! Services degraded.",
            );
          else this.logger.warn(msg);
          return null;
        }
        return Math.min(times * 100, 3000);
      },
    };

    this.client = redisUrl
      ? new Redis(redisUrl, redisOptions)
      : new Redis(redisOptions);

    this.client.on("connect", () => {
      this.logger.log("🔴 Redis connected");
    });

    this.client.on("error", (err) => {
      if (this.isProduction)
        this.logger.error(
          `CRITICAL: Redis error in PRODUCTION: ${err.message}`,
        );
      else this.logger.warn(`⚠️ Redis error: ${err.message}`);
    });
  }

  async onModuleDestroy() {
    clearInterval(this.sweepInterval);
    await this.client.quit();
  }

  getClient(): Redis {
    return this.client;
  }

  private isRedisConnected(): boolean {
    return this.client.status === "ready";
  }

  // OTP Management
  async setOtp(
    identifier: string,
    otp: string,
    expiryMinutes: number,
  ): Promise<void> {
    if (!this.isRedisConnected()) {
      this.memoryStore.set(`otp:${identifier}`, {
        value: otp,
        expiry: Date.now() + expiryMinutes * 60 * 1000,
      });
      return;
    }
    const key = `otp:${identifier}`;
    await this.client.setex(key, expiryMinutes * 60, otp);
  }

  async getOtp(identifier: string): Promise<string | null> {
    if (!this.isRedisConnected()) {
      const item = this.memoryStore.get(`otp:${identifier}`);
      if (!item || item.expiry < Date.now()) {
        this.memoryStore.delete(`otp:${identifier}`);
        return null;
      }
      return item.value;
    }
    const key = `otp:${identifier}`;
    return this.client.get(key);
  }

  async deleteOtp(identifier: string): Promise<void> {
    if (!this.isRedisConnected()) {
      this.memoryStore.delete(`otp:${identifier}`);
      return;
    }
    const key = `otp:${identifier}`;
    await this.client.del(key);
  }

  // Rate limiting for OTP
  async checkOtpRateLimit(identifier: string): Promise<boolean> {
    if (!this.isRedisConnected()) return true; // Fail open for rate limits if Redis down

    try {
      const key = `otp_rate:${identifier}`;
      const count = await this.client.incr(key);
      if (count === 1) {
        await this.client.expire(key, 3600); // 1 hour window
      }
      return count <= 5; // Max 5 OTP requests per hour
    } catch (e: any) {
      this.logger.warn("Redis checkOtpRateLimit error", e);
      return true; // Fail open
    }
  }

  // Ad cooldown management
  async checkAdCooldown(userId: string): Promise<boolean> {
    if (!this.isRedisConnected()) return true; // Fail open

    const key = `ad_cooldown:${userId}`;
    const exists = await this.client.exists(key);
    return exists === 0; // true if no cooldown
  }

  async setAdCooldown(userId: string, cooldownMinutes: number): Promise<void> {
    if (!this.isRedisConnected()) return;

    const key = `ad_cooldown:${userId}`;
    await this.client.setex(key, cooldownMinutes * 60, "1");
  }

  async getAdCooldownRemaining(userId: string): Promise<number> {
    if (!this.isRedisConnected()) return 0;

    const key = `ad_cooldown:${userId}`;
    return this.client.ttl(key);
  }

  // Login cooldown management
  async checkLoginCooldown(identifier: string): Promise<boolean> {
    if (!this.isRedisConnected()) {
      const item = this.memoryStore.get(`login_cooldown:${identifier}`);
      if (item && item.expiry > Date.now()) {
        return false; // On cooldown
      }
      return true; // Not on cooldown
    }
    const key = `login_cooldown:${identifier}`;
    const exists = await this.client.exists(key);
    return exists === 0; // true if no cooldown
  }

  async setLoginCooldown(identifier: string, cooldownSeconds: number): Promise<void> {
    if (!this.isRedisConnected()) {
      this.memoryStore.set(`login_cooldown:${identifier}`, {
        value: "1",
        expiry: Date.now() + cooldownSeconds * 1000,
      });
      return;
    }
    const key = `login_cooldown:${identifier}`;
    await this.client.setex(key, cooldownSeconds, "1");
  }

  async getLoginCooldownRemaining(identifier: string): Promise<number> {
    if (!this.isRedisConnected()) {
      const item = this.memoryStore.get(`login_cooldown:${identifier}`);
      if (!item) return 0;
      return Math.max(0, Math.ceil((item.expiry - Date.now()) / 1000));
    }
    const key = `login_cooldown:${identifier}`;
    return this.client.ttl(key);
  }

  // Cache helpers
  async setCache(
    key: string,
    value: any,
    expirySeconds: number,
  ): Promise<void> {
    if (!this.isRedisConnected()) return;
    await this.client.setex(key, expirySeconds, JSON.stringify(value));
  }

  async getCache<T>(key: string): Promise<T | null> {
    if (!this.isRedisConnected()) return null;

    try {
      const data = await this.client.get(key);
      if (!data) return null;
      return JSON.parse(data) as T;
    } catch (e: any) {
      this.logger.warn("Redis getCache error", e);
      return null;
    }
  }

  async deleteCache(key: string): Promise<void> {
    if (!this.isRedisConnected()) return;
    await this.client.del(key);
  }

  /**
   * Nonce check to prevent replay attacks.
   * Returns true if the nonce is unique and successfully recorded, false otherwise.
   */
  async setNonce(nonce: string, expirySeconds: number): Promise<boolean> {
    const key = `nonce:${nonce}`;
    if (!this.isRedisConnected()) {
      const item = this.memoryStore.get(key);
      if (item && item.expiry > Date.now()) {
        return false; // Nonce already exists (replay)
      }
      this.memoryStore.set(key, {
        value: "used",
        expiry: Date.now() + expirySeconds * 1000,
      });
      return true;
    }

    try {
      const result = await this.client.set(
        key,
        "used",
        "EX",
        expirySeconds,
        "NX",
      );
      return result === "OK";
    } catch (e: any) {
      this.logger.warn("Redis setNonce error", e);
      // Fail secure (reject) on Redis issues to prevent reward exploits
      return false;
    }
  }
}

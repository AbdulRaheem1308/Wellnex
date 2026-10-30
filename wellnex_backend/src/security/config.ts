export function validateProductionConfig(config: Record<string, unknown>) {
  if (config.NODE_ENV !== "production") return config;
  for (const key of ["JWT_SECRET", "JWT_REFRESH_SECRET"]) {
    const value = config[key];
    if (
      typeof value !== "string" ||
      value.length < 32 ||
      value.startsWith("wellnex-dev-")
    ) {
      throw new Error(
        `${key} must be a unique secret of at least 32 characters in production`,
      );
    }
  }
  if (config.JWT_SECRET === config.JWT_REFRESH_SECRET) {
    throw new Error("Access and refresh token signing secrets must differ");
  }
  if (
    config.ADMIN_API_KEY !== undefined &&
    (typeof config.ADMIN_API_KEY !== "string" ||
      config.ADMIN_API_KEY.length < 32 ||
      config.ADMIN_API_KEY === "fallback-secret-admin-key-2026")
  ) {
    throw new Error(
      "ADMIN_API_KEY must be a strong secret of at least 32 characters when configured",
    );
  }
  return config;
}

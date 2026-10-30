import { validateProductionConfig } from "./config";
describe("Production security configuration", () => {
  const valid = {
    NODE_ENV: "production",
    JWT_SECRET: "a".repeat(40),
    JWT_REFRESH_SECRET: "b".repeat(40),
    ADMIN_API_KEY: "c".repeat(40),
  };
  it("accepts distinct configured signing secrets", () => {
    expect(validateProductionConfig(valid)).toEqual(valid);
  });
  it("rejects missing, weak, reused and legacy secrets", () => {
    for (const config of [
      { ...valid, JWT_SECRET: undefined },
      { ...valid, JWT_SECRET: "short" },
      { ...valid, JWT_REFRESH_SECRET: valid.JWT_SECRET },
      { ...valid, ADMIN_API_KEY: "fallback-secret-admin-key-2026" },
      { ...valid, JWT_SECRET: "wellnex-dev-" + "x".repeat(40) },
    ])
      expect(() => validateProductionConfig(config)).toThrow();
  });
  it("allows isolated nonproduction test configuration", () => {
    expect(validateProductionConfig({ NODE_ENV: "test" })).toEqual({
      NODE_ENV: "test",
    });
  });
});

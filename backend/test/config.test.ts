import { describe, expect, it } from "vitest";
import { loadConfig } from "../src/config.js";

describe("configuración", () => {
  it("usa claude-haiku-5-5 como modelo de traducción por defecto, con sus tarifas", () => {
    const cfg = loadConfig({ DATABASE_URL: "postgres://x", SUPABASE_JWT_SECRET: "x".repeat(32) });
    expect(cfg.TRANSLATION_MODEL).toBe("claude-haiku-5-5");
    expect(cfg.COST_TRANSLATION_INPUT_USD_PER_MTOK).toBe(0.1);
    expect(cfg.COST_TRANSLATION_OUTPUT_USD_PER_MTOK).toBe(0.5);
    expect(cfg.DEEPGRAM_KEYTERMS_ENABLED).toBe(true);
    expect(cfg.COST_STT_USD_PER_MIN).toBeCloseTo(0.009);
  });
});

describe("regla de traducción de texto", () => {
  it("1 minuto por cada 1,000 caracteres, redondeado hacia arriba", async () => {
    const { QuotaService } = await import("../src/quota/quota.js");
    const cfg = loadConfig({ DATABASE_URL: "postgres://x", SUPABASE_JWT_SECRET: "x".repeat(32) });
    expect(cfg.TEXT_CHARS_PER_QUOTA_MINUTE).toBe(1000);
    const q = new QuotaService(cfg);
    expect(q.textCostSeconds(0)).toBe(0);
    expect(q.textCostSeconds(1)).toBe(60);
    expect(q.textCostSeconds(1000)).toBe(60);
    expect(q.textCostSeconds(1001)).toBe(120);
    expect(q.textCostSeconds(20000)).toBe(1200);
  });
});

describe("conexión a la base de datos", () => {
  it("con certificado raíz usa TLS verificado y quita sslmode de la URL", async () => {
    const { pgConfig } = await import("../src/db.js");
    const c = pgConfig("postgres://u:p@db.example.com:5432/postgres?sslmode=require", "-----BEGIN CERTIFICATE-----\nX\n-----END CERTIFICATE-----");
    expect(c.connectionString).not.toContain("sslmode");
    expect(c.ssl).toMatchObject({ rejectUnauthorized: true });
  });
  it("sin certificado deja la URL tal cual", async () => {
    const { pgConfig } = await import("../src/db.js");
    expect(pgConfig("postgres://localhost/x", undefined)).toEqual({ connectionString: "postgres://localhost/x" });
  });
});

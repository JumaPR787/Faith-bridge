import { describe, expect, it } from "vitest";
import { loadConfig } from "../src/config.js";

describe("configuración", () => {
  it("usa claude-haiku-5-5 como modelo de traducción por defecto, con sus tarifas", () => {
    const cfg = loadConfig({ DATABASE_URL: "postgres://x", SUPABASE_JWT_SECRET: "x".repeat(32) });
    expect(cfg.TRANSLATION_MODEL).toBe("claude-haiku-5-5");
    expect(cfg.COST_TRANSLATION_INPUT_USD_PER_MTOK).toBe(0.1);
    expect(cfg.COST_TRANSLATION_OUTPUT_USD_PER_MTOK).toBe(0.5);
  });
});

import { z } from "zod";

/**
 * Configuración por entorno (development | test | staging | production).
 * Todos los secretos viven SOLO en el servidor. La app móvil nunca recibe
 * claves de Deepgram, Anthropic, RevenueCat ni la service key de Supabase.
 */
const boolFromString = z
  .enum(["true", "false", "1", "0"])
  .transform((v) => v === "true" || v === "1");

const EnvSchema = z.object({
  APP_ENV: z.enum(["development", "test", "staging", "production"]).default("development"),
  PORT: z.coerce.number().int().default(8080),
  HOST: z.string().default("0.0.0.0"),
  LOG_LEVEL: z.enum(["fatal", "error", "warn", "info", "debug", "trace"]).default("info"),

  DATABASE_URL: z.string().min(1),

  // Autenticación (Supabase Auth). En producción: JWKS. En dev/test: secreto HS256.
  SUPABASE_URL: z.string().url().optional(),
  SUPABASE_JWKS_URL: z.string().url().optional(),
  SUPABASE_JWT_SECRET: z.string().min(16).optional(),
  SUPABASE_JWT_AUDIENCE: z.string().default("authenticated"),
  SUPABASE_SERVICE_ROLE_KEY: z.string().optional(),

  // Proveedores. "fake" = adaptadores simulados (solo dev/test, claramente marcados).
  STT_PROVIDER: z.enum(["deepgram", "fake"]).default("deepgram"),
  DEEPGRAM_API_KEY: z.string().optional(),
  DEEPGRAM_MODEL: z.string().default("nova-3"),
  DEEPGRAM_KEYTERMS_ENABLED: boolFromString.default(false),
  TRANSLATION_PROVIDER: z.enum(["anthropic", "fake"]).default("anthropic"),
  ANTHROPIC_API_KEY: z.string().optional(),
  // Modelo de traducción elegido por el dueño del producto (ver docs/costos.md §4).
  TRANSLATION_MODEL: z.string().default("claude-haiku-5-5"),
  TRANSLATION_TIMEOUT_MS: z.coerce.number().int().default(15000),
  TRANSLATION_CONTEXT_SEGMENTS: z.coerce.number().int().min(0).max(6).default(3),

  // Suscripciones (RevenueCat).
  REVENUECAT_SECRET_API_KEY: z.string().optional(),
  REVENUECAT_WEBHOOK_AUTH: z.string().optional(),
  REVENUECAT_ENTITLEMENT_PERSONAL: z.string().default("personal"),
  REVENUECAT_ENTITLEMENT_CHURCH: z.string().default("church"),
  SANDBOX_PURCHASES: z.enum(["allow", "deny"]).default("allow"),

  // Cuotas (segundos). El servidor es la única fuente de verdad.
  QUOTA_PERSONAL_SECONDS: z.coerce.number().int().default(300 * 60),
  QUOTA_TRIAL_SECONDS: z.coerce.number().int().default(120 * 60),
  QUOTA_CHURCH_SECONDS: z.coerce.number().int().default(600 * 60),
  TEXT_CHARS_PER_QUOTA_MINUTE: z.coerce.number().int().default(1000),
  TEXT_MAX_CHARS: z.coerce.number().int().default(20000),

  // Protección contra abuso / límites operativos.
  MAX_SESSION_SECONDS: z.coerce.number().int().default(3 * 60 * 60),
  SESSION_STARTS_PER_HOUR: z.coerce.number().int().default(12),
  RESUME_GRACE_SECONDS: z.coerce.number().int().default(60),
  PAUSE_IDLE_CLOSE_SECONDS: z.coerce.number().int().default(600),

  // Tarifas usadas para estimar gasto (USD). Actualizar al cambiar contratos.
  COST_STT_USD_PER_MIN: z.coerce.number().default(0.0077),
  COST_TRANSLATION_INPUT_USD_PER_MTOK: z.coerce.number().default(0.1),
  COST_TRANSLATION_OUTPUT_USD_PER_MTOK: z.coerce.number().default(0.5),
  ALERT_WEBHOOK_URL: z.string().url().optional(),
});

export type Config = z.infer<typeof EnvSchema>;

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const parsed = EnvSchema.safeParse(env);
  if (!parsed.success) {
    // Nunca imprimir valores: solo nombres de variables con error.
    const names = parsed.error.issues.map((i) => i.path.join(".")).join(", ");
    throw new Error(`Invalid configuration for: ${names}`);
  }
  const cfg = parsed.data;
  assertProductionSafety(cfg);
  return cfg;
}

function assertProductionSafety(cfg: Config): void {
  const strict = cfg.APP_ENV === "production" || cfg.APP_ENV === "staging";
  if (!strict) return;
  const missing: string[] = [];
  if (cfg.STT_PROVIDER === "fake") missing.push("STT_PROVIDER must not be fake");
  if (cfg.TRANSLATION_PROVIDER === "fake") missing.push("TRANSLATION_PROVIDER must not be fake");
  if (!cfg.SUPABASE_JWKS_URL) missing.push("SUPABASE_JWKS_URL");
  if (cfg.SUPABASE_JWT_SECRET && cfg.APP_ENV === "production") missing.push("SUPABASE_JWT_SECRET must not be set in production (use JWKS)");
  if (!cfg.DEEPGRAM_API_KEY) missing.push("DEEPGRAM_API_KEY");
  if (!cfg.ANTHROPIC_API_KEY) missing.push("ANTHROPIC_API_KEY");
  if (!cfg.REVENUECAT_SECRET_API_KEY) missing.push("REVENUECAT_SECRET_API_KEY");
  if (!cfg.REVENUECAT_WEBHOOK_AUTH || cfg.REVENUECAT_WEBHOOK_AUTH.length < 24) missing.push("REVENUECAT_WEBHOOK_AUTH (>=24 chars)");
  if (missing.length) throw new Error(`Unsafe ${cfg.APP_ENV} configuration: ${missing.join("; ")}`);
}

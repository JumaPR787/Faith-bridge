import { buildApp, createFastify } from "./app.js";
import { createTokenVerifier } from "./auth.js";
import { HttpRevenueCatClient, type RevenueCatClient } from "./billing/revenuecat.js";
import { loadConfig } from "./config.js";
import type { AppContext } from "./context.js";
import { createDb } from "./db.js";
import { ChurchRegistry } from "./church/registry.js";
import { SessionRegistry } from "./live/session.js";
import { OpsGuard } from "./ops/guard.js";
import { DeepgramProvider } from "./providers/stt/deepgram.js";
import { FakeSttProvider } from "./providers/stt/fake.js";
import { AnthropicTranslator } from "./providers/translation/anthropic.js";
import { FakeTranslator } from "./providers/translation/fake.js";
import { runPurge } from "./ops/purge.js";
import { QuotaService } from "./quota/quota.js";

const cfg = loadConfig();
const app = createFastify(cfg.LOG_LEVEL);
const db = createDb(cfg.DATABASE_URL);

const stt =
  cfg.STT_PROVIDER === "deepgram"
    ? new DeepgramProvider(required(cfg.DEEPGRAM_API_KEY, "DEEPGRAM_API_KEY"), cfg.DEEPGRAM_MODEL, cfg.DEEPGRAM_KEYTERMS_ENABLED, undefined, (msg) =>
        app.log.warn(msg),
      )
    : new FakeSttProvider();
const translator =
  cfg.TRANSLATION_PROVIDER === "anthropic"
    ? new AnthropicTranslator(required(cfg.ANTHROPIC_API_KEY, "ANTHROPIC_API_KEY"), cfg.TRANSLATION_MODEL, cfg.TRANSLATION_TIMEOUT_MS)
    : new FakeTranslator();
const revenuecat: RevenueCatClient = cfg.REVENUECAT_SECRET_API_KEY
  ? new HttpRevenueCatClient(cfg.REVENUECAT_SECRET_API_KEY)
  : {
      getSubscriber: async () => {
        throw new Error("revenuecat_not_configured");
      },
      deleteSubscriber: async () => undefined,
    };

const ctx: AppContext = {
  cfg,
  db,
  log: app.log,
  verifyToken: createTokenVerifier(cfg),
  stt,
  translator,
  revenuecat,
  quota: new QuotaService(cfg),
  guard: new OpsGuard(db, cfg, app.log),
  registry: new SessionRegistry(),
  church: new ChurchRegistry(db, app.log),
  deleteAuthUser: async (userId) => {
    if (cfg.SUPABASE_URL && cfg.SUPABASE_SERVICE_ROLE_KEY) {
      const res = await fetch(`${cfg.SUPABASE_URL}/auth/v1/admin/users/${userId}`, {
        method: "DELETE",
        headers: { apikey: cfg.SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${cfg.SUPABASE_SERVICE_ROLE_KEY}` },
        signal: AbortSignal.timeout(10_000),
      });
      if (!res.ok && res.status !== 404) throw new Error(`supabase_admin_${res.status}`);
    } else if (cfg.APP_ENV === "development" || cfg.APP_ENV === "test") {
      await db.query("delete from auth.users where id = $1", [userId]);
    } else {
      throw new Error("auth_admin_not_configured");
    }
  },
};

function required(v: string | undefined, name: string): string {
  if (!v) throw new Error(`${name} is required for the selected provider`);
  return v;
}

await buildApp(ctx, app);
if (cfg.STT_PROVIDER === "fake" || cfg.TRANSLATION_PROVIDER === "fake") {
  app.log.warn("⚠️  Running with SIMULATED providers (development only). No real speech recognition or translation.");
}

// Retención: purga al arrancar y luego periódicamente (no requiere cron externo).
let purgeTimer: NodeJS.Timeout | null = null;
if (cfg.PURGE_INTERVAL_HOURS > 0) {
  const purge = () =>
    runPurge(db)
      .then((r) => app.log.info({ transcripts: r.transcripts }, "retention purge done"))
      .catch((e) => app.log.error({ err: e instanceof Error ? e.message.slice(0, 120) : "unknown" }, "retention purge failed"));
  setTimeout(purge, 60_000).unref();
  purgeTimer = setInterval(purge, cfg.PURGE_INTERVAL_HOURS * 3600_000);
  purgeTimer.unref();
}

async function shutdown() {
  if (purgeTimer) clearInterval(purgeTimer);
  app.log.info("shutting down: ending live sessions");
  await Promise.allSettled(ctx.registry.all().map((s) => s.end("server_shutdown")));
  await app.close();
  await db.end();
  process.exit(0);
}
process.on("SIGTERM", () => void shutdown());
process.on("SIGINT", () => void shutdown());

await app.listen({ port: cfg.PORT, host: cfg.HOST });

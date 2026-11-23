import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { syncEntitlement } from "../billing/sync.js";
import type { AppContext } from "../context.js";
import { getConfigValue } from "../db.js";
import { requireUser } from "./util.js";

const Settings = z.object({
  uiLocale: z.enum(["es", "en"]).optional(),
  transcriptRetentionDays: z.number().int().min(1).max(3650).optional(),
});

export function registerMeRoutes(app: FastifyInstance, ctx: AppContext): void {
  app.get("/v1/me", async (req) => {
    const user = await requireUser(ctx, req);
    const p = await ctx.db.query<{ ui_locale: string; transcript_retention_days: number }>(
      "select ui_locale, transcript_retention_days from public.profiles where user_id = $1",
      [user.id],
    );
    const quota = await ctx.quota.getStatus(ctx.db, user.id);
    const liveEnabled = await getConfigValue(ctx.db, "live_sessions_enabled", true);
    return {
      userId: user.id,
      settings: { uiLocale: p.rows[0]?.ui_locale ?? "es", transcriptRetentionDays: p.rows[0]?.transcript_retention_days ?? 365 },
      quota,
      service: { liveSessionsEnabled: liveEnabled, churchModeEnabled: await getConfigValue(ctx.db, "church_mode_enabled", false) },
      limits: { maxSessionSeconds: ctx.cfg.MAX_SESSION_SECONDS, textMaxChars: ctx.cfg.TEXT_MAX_CHARS, textCharsPerQuotaMinute: ctx.cfg.TEXT_CHARS_PER_QUOTA_MINUTE },
    };
  });

  app.patch("/v1/me/settings", async (req, reply) => {
    const user = await requireUser(ctx, req);
    const b = Settings.safeParse(req.body);
    if (!b.success) return reply.code(400).send({ error: "bad_request" });
    await ctx.db.query(
      `update public.profiles set ui_locale = coalesce($2, ui_locale),
         transcript_retention_days = coalesce($3, transcript_retention_days) where user_id = $1`,
      [user.id, b.data.uiLocale ?? null, b.data.transcriptRetentionDays ?? null],
    );
    return { ok: true };
  });

  /** Tras comprar o restaurar en el teléfono: el servidor consulta RevenueCat. */
  app.post("/v1/subscription/sync", async (req, reply) => {
    const user = await requireUser(ctx, req);
    try {
      await syncEntitlement(ctx.db, ctx.revenuecat, ctx.cfg, user.id);
    } catch (err) {
      req.log.warn({ err: err instanceof Error ? err.message : "unknown" }, "subscription sync failed");
      return reply.code(502).send({ error: "store_unavailable" });
    }
    return { quota: await ctx.quota.getStatus(ctx.db, user.id) };
  });
}

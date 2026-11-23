import { createHash } from "node:crypto";
import type { FastifyInstance } from "fastify";
import type { AppContext } from "../context.js";
import { requireUser } from "./util.js";

/**
 * Eliminación de cuenta (requisito de Apple y Google).
 * - Cierra la sesión en vivo si existe.
 * - Borra transcripciones, glosario, uso, beneficios y perfil (cascada).
 * - Pide a RevenueCat borrar el suscriptor (datos personales) si está configurado.
 * - Borra el usuario en Supabase Auth.
 * NOTA: borrar la cuenta NO cancela la suscripción en la tienda; la app lo
 * explica y enlaza a la administración de suscripciones antes de confirmar.
 */
export function registerAccountRoutes(app: FastifyInstance, ctx: AppContext): void {
  app.delete("/v1/account", async (req, reply) => {
    const user = await requireUser(ctx, req);
    const hash = createHash("sha256").update(user.id).digest("hex");
    const log = await ctx.db.query<{ id: string }>("insert into public.account_deletions (user_id_hash) values ($1) returning id", [hash]);

    await ctx.registry.activeForUser(user.id)?.end("user_stopped");
    await ctx.db.query("delete from public.transcripts where user_id = $1", [user.id]);
    await ctx.db.query("delete from public.glossary_terms where user_id = $1", [user.id]);
    await ctx.db.query("delete from public.usage_events where user_id = $1", [user.id]);
    await ctx.db.query("delete from public.usage_periods where user_id = $1", [user.id]);
    await ctx.db.query("delete from public.live_sessions where user_id = $1", [user.id]);
    await ctx.db.query("delete from public.entitlements where user_id = $1", [user.id]);
    await ctx.db.query("delete from public.profiles where user_id = $1", [user.id]);

    const warnings: string[] = [];
    try {
      await ctx.revenuecat.deleteSubscriber(user.id);
    } catch {
      warnings.push("revenuecat_delete_pending");
    }
    try {
      await ctx.deleteAuthUser(user.id);
    } catch {
      warnings.push("auth_delete_pending");
    }
    if (warnings.length === 0) {
      await ctx.db.query("update public.account_deletions set completed_at = now() where id = $1", [log.rows[0]!.id]);
    } else {
      req.log.error({ warnings }, "account deletion incomplete; retry required");
    }
    return reply.code(202).send({ ok: true, warnings });
  });
}

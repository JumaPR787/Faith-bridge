import type { FastifyInstance } from "fastify";
import { z } from "zod";
import type { AppContext } from "../context.js";
import type { Lang } from "../providers/stt/types.js";
import type { ContextPair } from "../providers/translation/prompt.js";
import { loadGlossary } from "./glossary.js";
import { requireUser } from "./util.js";

const Body = z
  .object({
    source: z.enum(["en", "es"]),
    target: z.enum(["en", "es"]),
    text: z.string().max(200_000).optional(),
    transcriptId: z.string().uuid().optional(),
    /** Debe ser true para procesar: la app muestra antes el costo en cuota. */
    confirm: z.boolean().optional(),
  })
  .refine((b) => b.source !== b.target, { message: "same_language" })
  .refine((b) => (b.text ? 1 : 0) + (b.transcriptId ? 1 : 0) === 1, { message: "text_xor_transcript" });

/** Divide texto pegado en fragmentos por oración (≤ ~800 caracteres). */
export function chunkText(text: string, max = 800): string[] {
  const sentences = text.replace(/\r/g, "").split(/(?<=[.?!…])\s+|\n{2,}/);
  const out: string[] = [];
  let cur = "";
  for (const s of sentences) {
    const piece = s.trim();
    if (!piece) continue;
    if (piece.length > max) {
      if (cur) out.push(cur), (cur = "");
      for (let i = 0; i < piece.length; i += max) out.push(piece.slice(i, i + max));
      continue;
    }
    if ((cur + " " + piece).trim().length > max) {
      out.push(cur);
      cur = piece;
    } else cur = (cur + " " + piece).trim();
  }
  if (cur) out.push(cur);
  return out;
}

export function registerTranslateRoutes(app: FastifyInstance, ctx: AppContext): void {
  const inFlight = new Set<string>();

  async function resolveInput(userId: string, b: z.infer<typeof Body>) {
    if (b.text !== undefined) {
      const pieces = chunkText(b.text);
      return { kind: "text" as const, pieces: pieces.map((p) => ({ seq: null as number | null, text: p })) };
    }
    const t = await ctx.db.query("select 1 from public.transcripts where id = $1 and user_id = $2", [b.transcriptId, userId]);
    if (!t.rowCount) return null;
    const s = await ctx.db.query<{ seq: number; source_text: string }>(
      "select seq, source_text from public.transcript_segments where transcript_id = $1 order by seq",
      [b.transcriptId],
    );
    return { kind: "transcript" as const, pieces: s.rows.map((r) => ({ seq: r.seq as number | null, text: r.source_text })) };
  }

  /** Estimación: informa cuánta cuota consumirá ANTES de procesar. */
  app.post("/v1/translate/estimate", async (req, reply) => {
    const user = await requireUser(ctx, req);
    const b = Body.safeParse(req.body);
    if (!b.success) return reply.code(400).send({ error: "bad_request" });
    const input = await resolveInput(user.id, b.data);
    if (!input) return reply.code(404).send({ error: "not_found" });
    const chars = input.pieces.reduce((n, p) => n + p.text.length, 0);
    const cost = ctx.quota.textCostSeconds(chars);
    const q = await ctx.quota.getStatus(ctx.db, user.id);
    return {
      chars,
      maxChars: ctx.cfg.TEXT_MAX_CHARS,
      costSeconds: cost,
      remainingSeconds: q.remainingSeconds,
      allowed: q.hasAccess && chars > 0 && chars <= ctx.cfg.TEXT_MAX_CHARS && cost <= q.remainingSeconds,
      reason: !q.hasAccess ? "no_entitlement" : chars === 0 ? "empty" : chars > ctx.cfg.TEXT_MAX_CHARS ? "too_long" : cost > q.remainingSeconds ? "quota_exhausted" : null,
    };
  });

  app.post("/v1/translate", async (req, reply) => {
    const user = await requireUser(ctx, req);
    const b = Body.safeParse(req.body);
    if (!b.success) return reply.code(400).send({ error: "bad_request" });
    if (b.data.confirm !== true) return reply.code(400).send({ error: "confirmation_required" });
    const denial = await ctx.guard.checkTextTranslation();
    if (denial) return reply.code(503).send({ error: denial });
    if (inFlight.has(user.id)) return reply.code(429).send({ error: "translation_in_progress" });

    const input = await resolveInput(user.id, b.data);
    if (!input) return reply.code(404).send({ error: "not_found" });
    const chars = input.pieces.reduce((n, p) => n + p.text.length, 0);
    if (chars === 0) return reply.code(400).send({ error: "empty" });
    if (chars > ctx.cfg.TEXT_MAX_CHARS) return reply.code(413).send({ error: "too_long" });
    const q = await ctx.quota.getStatus(ctx.db, user.id);
    if (!q.hasAccess) return reply.code(402).send({ error: "no_entitlement" });
    if (ctx.quota.textCostSeconds(chars) > q.remainingSeconds) return reply.code(402).send({ error: "quota_exhausted" });

    inFlight.add(user.id);
    try {
      const source = b.data.source as Lang;
      const target = b.data.target as Lang;
      const glossary = await loadGlossary(ctx.db, user.id, source, target);
      const results: Array<{ seq: number | null; text: string | null; status: "ok" | "failed" }> = [];
      const context: ContextPair[] = [];
      let translatedChars = 0;
      for (const p of input.pieces) {
        try {
          const r = await ctx.translator.translate({ text: p.text, source, target, context: context.slice(-2), glossary });
          results.push({ seq: p.seq, text: r.text, status: "ok" });
          context.push({ source: p.text, target: r.text });
          translatedChars += p.text.length;
          await ctx.guard.addSpend("translation", r.inputTokens + r.outputTokens, ctx.guard.translationCostUsd(r.inputTokens, r.outputTokens));
        } catch {
          results.push({ seq: p.seq, text: null, status: "failed" });
        }
      }
      // Solo se descuenta lo que efectivamente se tradujo.
      const charged = ctx.quota.textCostSeconds(translatedChars);
      await ctx.quota.record(ctx.db, user.id, q.periodStart!, charged, "text_translation", null);
      if (input.kind === "transcript") {
        for (const r of results) {
          await ctx.db.query(
            "update public.transcript_segments set translated_text = $3, translation_status = $4 where transcript_id = $1 and seq = $2",
            [b.data.transcriptId, r.seq, r.text, r.status],
          );
        }
        await ctx.db.query("update public.transcripts set target_lang = $2 where id = $1", [b.data.transcriptId, target]);
      }
      return {
        chargedSeconds: charged,
        failedPieces: results.filter((r) => r.status === "failed").length,
        pieces: results,
        text: input.kind === "text" ? results.map((r) => r.text ?? "[traducción no disponible / translation unavailable]").join("\n\n") : undefined,
      };
    } finally {
      inFlight.delete(user.id);
    }
  });
}

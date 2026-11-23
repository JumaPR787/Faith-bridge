import type { FastifyInstance } from "fastify";
import { z } from "zod";
import type { AppContext } from "../context.js";
import { requireUser } from "./util.js";

const Id = z.string().uuid();

export function registerTranscriptRoutes(app: FastifyInstance, ctx: AppContext): void {
  app.get("/v1/transcripts", async (req) => {
    const user = await requireUser(ctx, req);
    const r = await ctx.db.query(
      `select t.id, t.title, t.source_lang as "sourceLang", t.target_lang as "targetLang",
              t.created_at as "createdAt", t.expires_at as "expiresAt",
              (select count(*)::int from public.transcript_segments s where s.transcript_id = t.id) as "segmentCount"
       from public.transcripts t where t.user_id = $1 order by t.created_at desc limit 200`,
      [user.id],
    );
    return { transcripts: r.rows };
  });

  app.get("/v1/transcripts/:id", async (req, reply) => {
    const user = await requireUser(ctx, req);
    const id = Id.safeParse((req.params as { id?: string }).id);
    if (!id.success) return reply.code(400).send({ error: "bad_request" });
    const t = await ctx.db.query(
      `select id, title, source_lang as "sourceLang", target_lang as "targetLang", created_at as "createdAt", expires_at as "expiresAt"
       from public.transcripts where id = $1 and user_id = $2`,
      [id.data, user.id],
    );
    // 404 tanto si no existe como si es de otra persona (no revela existencia).
    if (!t.rows[0]) return reply.code(404).send({ error: "not_found" });
    const s = await ctx.db.query(
      `select seq, start_ms as "startMs", end_ms as "endMs", source_text as "sourceText",
              translated_text as "translatedText", translation_status as "translationStatus"
       from public.transcript_segments where transcript_id = $1 order by seq`,
      [id.data],
    );
    return { ...t.rows[0], segments: s.rows };
  });

  app.delete("/v1/transcripts/:id", async (req, reply) => {
    const user = await requireUser(ctx, req);
    const id = Id.safeParse((req.params as { id?: string }).id);
    if (!id.success) return reply.code(400).send({ error: "bad_request" });
    const r = await ctx.db.query("delete from public.transcripts where id = $1 and user_id = $2", [id.data, user.id]);
    return reply.code(r.rowCount ? 204 : 404).send();
  });
}

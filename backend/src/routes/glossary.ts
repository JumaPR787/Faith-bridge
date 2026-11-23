import type { FastifyInstance } from "fastify";
import { z } from "zod";
import type { AppContext } from "../context.js";
import type { Queryable } from "../db.js";
import type { Lang } from "../providers/stt/types.js";
import { defaultGlossary, mergeGlossary, type GlossaryTerm } from "../providers/translation/glossary.js";
import { requireUser } from "./util.js";

export async function loadGlossary(db: Queryable, userId: string, source: Lang, target: Lang): Promise<GlossaryTerm[]> {
  const r = await db.query<{ source_term: string; target_term: string }>(
    `select source_term, target_term from public.glossary_terms
     where user_id = $1 and source_lang = $2 and target_lang = $3 order by created_at limit 150`,
    [userId, source, target],
  );
  const user = r.rows.map((x) => ({ source: x.source_term, target: x.target_term }));
  return mergeGlossary(user, defaultGlossary(source, target));
}

const LangPair = z.object({ source: z.enum(["en", "es"]), target: z.enum(["en", "es"]) }).refine((v) => v.source !== v.target);
const TermBody = z.object({
  source: z.enum(["en", "es"]),
  target: z.enum(["en", "es"]),
  sourceTerm: z.string().trim().min(1).max(80),
  targetTerm: z.string().trim().min(1).max(80),
}).refine((v) => v.source !== v.target);

export function registerGlossaryRoutes(app: FastifyInstance, ctx: AppContext): void {
  app.get("/v1/glossary", async (req, reply) => {
    const user = await requireUser(ctx, req);
    const q = LangPair.safeParse(req.query);
    if (!q.success) return reply.code(400).send({ error: "bad_request" });
    const own = await ctx.db.query(
      `select id, source_term as "sourceTerm", target_term as "targetTerm" from public.glossary_terms
       where user_id = $1 and source_lang = $2 and target_lang = $3 order by created_at`,
      [user.id, q.data.source, q.data.target],
    );
    return { custom: own.rows, defaults: defaultGlossary(q.data.source, q.data.target) };
  });

  app.post("/v1/glossary", async (req, reply) => {
    const user = await requireUser(ctx, req);
    const b = TermBody.safeParse(req.body);
    if (!b.success) return reply.code(400).send({ error: "bad_request" });
    const count = await ctx.db.query<{ n: string }>("select count(*) as n from public.glossary_terms where user_id = $1", [user.id]);
    if (Number(count.rows[0]?.n ?? 0) >= 150) return reply.code(409).send({ error: "glossary_full" });
    const r = await ctx.db.query(
      `insert into public.glossary_terms (user_id, source_lang, target_lang, source_term, target_term)
       values ($1,$2,$3,$4,$5) on conflict do nothing returning id`,
      [user.id, b.data.source, b.data.target, b.data.sourceTerm, b.data.targetTerm],
    );
    if (!r.rows[0]) return reply.code(409).send({ error: "duplicate_term" });
    return reply.code(201).send({ id: (r.rows[0] as { id: string }).id });
  });

  app.delete("/v1/glossary/:id", async (req, reply) => {
    const user = await requireUser(ctx, req);
    const id = z.string().uuid().safeParse((req.params as { id?: string }).id);
    if (!id.success) return reply.code(400).send({ error: "bad_request" });
    const r = await ctx.db.query("delete from public.glossary_terms where id = $1 and user_id = $2", [id.data, user.id]);
    return reply.code(r.rowCount ? 204 : 404).send();
  });
}

import { randomUUID } from "node:crypto";
import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";
import { z } from "zod";
import type { AppContext } from "../context.js";
import { getConfigValue, type Queryable } from "../db.js";
import { requireUser } from "../routes/util.js";
import { generateJoinCode, hashJoinCode, normalizeJoinCode, qrPayload } from "./codes.js";
import { signListenerToken } from "./tokens.js";

export type OrgRole = "owner" | "admin" | "member";

export async function memberRole(db: Queryable, orgId: string, userId: string): Promise<OrgRole | null> {
  const r = await db.query<{ role: OrgRole }>("select role from public.organization_members where org_id = $1 and user_id = $2", [orgId, userId]);
  return r.rows[0]?.role ?? null;
}

const Id = z.string().uuid();
const MAX_ORGS_PER_USER = 3;

/** Límite simple de intentos por IP para unirse (contra adivinar códigos). */
class AttemptLimiter {
  private hits = new Map<string, number[]>();
  constructor(private readonly perMinute: number) {}
  allow(key: string): boolean {
    const now = Date.now();
    const arr = (this.hits.get(key) ?? []).filter((t) => now - t < 60_000);
    if (arr.length >= this.perMinute) {
      this.hits.set(key, arr);
      return false;
    }
    arr.push(now);
    this.hits.set(key, arr);
    if (this.hits.size > 10_000) this.hits.clear();
    return true;
  }
}

export function registerChurchRoutes(app: FastifyInstance, ctx: AppContext): void {
  const limiter = new AttemptLimiter(ctx.cfg.JOIN_ATTEMPTS_PER_MINUTE);

  async function enabled(reply: FastifyReply): Promise<boolean> {
    if (await getConfigValue(ctx.db, "church_mode_enabled", false)) return true;
    await reply.code(503).send({ error: "church_mode_disabled" });
    return false;
  }

  async function requireManager(req: FastifyRequest, reply: FastifyReply, orgId: string) {
    const user = await requireUser(ctx, req);
    const role = await memberRole(ctx.db, orgId, user.id);
    if (!role) {
      await reply.code(404).send({ error: "not_found" }); // no revela si existe
      return null;
    }
    if (role === "member") {
      await reply.code(403).send({ error: "not_allowed" });
      return null;
    }
    return { user, role };
  }

  // ───────── Organizaciones ─────────
  app.post("/v1/orgs", async (req, reply) => {
    if (!(await enabled(reply))) return;
    const user = await requireUser(ctx, req);
    const b = z.object({ name: z.string().trim().min(2).max(120), attestAudioAuthorization: z.literal(true) }).safeParse(req.body);
    if (!b.success) return reply.code(400).send({ error: "bad_request" });
    const n = await ctx.db.query<{ n: string }>("select count(*) as n from public.organization_members where user_id = $1 and role = 'owner'", [user.id]);
    if (Number(n.rows[0]?.n ?? 0) >= MAX_ORGS_PER_USER) return reply.code(409).send({ error: "org_limit" });
    const org = await ctx.db.query<{ id: string }>(
      "insert into public.organizations (name, created_by, audio_authorization_attested_at) values ($1,$2, now()) returning id",
      [b.data.name, user.id],
    );
    await ctx.db.query("insert into public.organization_members (org_id, user_id, role) values ($1,$2,'owner')", [org.rows[0]!.id, user.id]);
    return reply.code(201).send({ id: org.rows[0]!.id });
  });

  app.get("/v1/orgs", async (req) => {
    const user = await requireUser(ctx, req);
    const r = await ctx.db.query(
      `select o.id, o.name, m.role from public.organizations o
       join public.organization_members m on m.org_id = o.id where m.user_id = $1 order by o.created_at`,
      [user.id],
    );
    return { orgs: r.rows, churchModeEnabled: await getConfigValue(ctx.db, "church_mode_enabled", false) };
  });

  app.get("/v1/orgs/:id", async (req, reply) => {
    const id = Id.safeParse((req.params as { id?: string }).id);
    if (!id.success) return reply.code(400).send({ error: "bad_request" });
    const user = await requireUser(ctx, req);
    const role = await memberRole(ctx.db, id.data, user.id);
    if (!role) return reply.code(404).send({ error: "not_found" });
    const org = await ctx.db.query("select id, name, audio_authorization_attested_at as \"attestedAt\" from public.organizations where id = $1", [id.data]);
    const members =
      role === "member"
        ? []
        : (
            await ctx.db.query(
              `select m.user_id as "userId", u.email, m.role from public.organization_members m
               join auth.users u on u.id = m.user_id where m.org_id = $1 order by m.added_at`,
              [id.data],
            )
          ).rows;
    const sessions = await ctx.db.query(
      `select id, status, source_lang as "sourceLang", target_lang as "targetLang", max_listeners as "maxListeners",
              save_transcript as "saveTranscript", created_at as "createdAt", join_expires_at as "joinExpiresAt"
       from public.church_sessions where org_id = $1 order by created_at desc limit 20`,
      [id.data],
    );
    const usage = await ctx.db.query(
      `select period_start as "periodStart", broadcast_seconds as "broadcastSeconds", peak_listeners as "peakListeners",
              listener_seconds as "listenerSeconds", egress_bytes as "egressBytes"
       from public.church_usage where org_id = $1 order by period_start desc limit 6`,
      [id.data],
    );
    return {
      ...org.rows[0],
      role,
      members,
      sessions: sessions.rows.map((s: { id: string }) => ({ ...s, listeners: ctx.church.listenerCount(s.id), broadcasting: ctx.church.isBroadcasting(s.id) })),
      usage: usage.rows,
    };
  });

  // ───────── Miembros ─────────
  app.post("/v1/orgs/:id/members", async (req, reply) => {
    if (!(await enabled(reply))) return;
    const id = Id.safeParse((req.params as { id?: string }).id);
    const b = z.object({ email: z.string().trim().toLowerCase().email(), role: z.enum(["admin", "member"]) }).safeParse(req.body);
    if (!id.success || !b.success) return reply.code(400).send({ error: "bad_request" });
    const m = await requireManager(req, reply, id.data);
    if (!m) return;
    const u = await ctx.db.query<{ id: string }>("select id from auth.users where lower(email) = $1", [b.data.email]);
    // La persona debe haber creado su cuenta en la app antes.
    if (!u.rows[0]) return reply.code(404).send({ error: "user_not_found" });
    await ctx.db.query(
      `insert into public.organization_members (org_id, user_id, role) values ($1,$2,$3)
       on conflict (org_id, user_id) do update set role = excluded.role where public.organization_members.role <> 'owner'`,
      [id.data, u.rows[0].id, b.data.role],
    );
    return reply.code(201).send({ userId: u.rows[0].id });
  });

  app.delete("/v1/orgs/:id/members/:userId", async (req, reply) => {
    const p = req.params as { id?: string; userId?: string };
    const id = Id.safeParse(p.id);
    const uid = Id.safeParse(p.userId);
    if (!id.success || !uid.success) return reply.code(400).send({ error: "bad_request" });
    const m = await requireManager(req, reply, id.data);
    if (!m) return;
    const target = await memberRole(ctx.db, id.data, uid.data);
    if (!target) return reply.code(404).send({ error: "not_found" });
    if (target === "owner") return reply.code(409).send({ error: "cannot_remove_owner" });
    await ctx.db.query("delete from public.organization_members where org_id = $1 and user_id = $2", [id.data, uid.data]);
    return reply.code(204).send();
  });

  // ───────── Sesiones de iglesia ─────────
  app.post("/v1/orgs/:id/sessions", async (req, reply) => {
    if (!(await enabled(reply))) return;
    const id = Id.safeParse((req.params as { id?: string }).id);
    const b = z
      .object({
        sourceLang: z.enum(["en", "es"]),
        targetLang: z.enum(["en", "es"]).nullable(),
        maxListeners: z.number().int().min(1).optional(),
        saveTranscript: z.boolean().default(false),
        attestAudioAuthorization: z.literal(true),
      })
      .refine((v) => v.targetLang === null || v.targetLang !== v.sourceLang)
      .safeParse(req.body);
    if (!id.success || !b.success) return reply.code(400).send({ error: "bad_request" });
    const m = await requireManager(req, reply, id.data);
    if (!m) return;
    const q = await ctx.quota.getStatus(ctx.db, m.user.id);
    if (!q.hasAccess || q.plan !== "church") return reply.code(402).send({ error: "no_church_plan" });
    const maxListeners = Math.min(b.data.maxListeners ?? ctx.cfg.CHURCH_MAX_LISTENERS, ctx.cfg.CHURCH_MAX_LISTENERS);
    for (let attempt = 0; attempt < 5; attempt++) {
      const code = generateJoinCode();
      const r = await ctx.db.query<{ id: string; join_expires_at: Date }>(
        `insert into public.church_sessions (org_id, created_by, join_code_hash, source_lang, target_lang, max_listeners, save_transcript, join_expires_at)
         values ($1,$2,$3,$4,$5,$6,$7, now() + make_interval(hours => $8))
         on conflict (join_code_hash) do nothing returning id, join_expires_at`,
        [id.data, m.user.id, hashJoinCode(code.replace("-", "")), b.data.sourceLang, b.data.targetLang, maxListeners, b.data.saveTranscript, ctx.cfg.CHURCH_JOIN_HOURS],
      );
      if (!r.rows[0]) continue;
      await ctx.db.query("update public.organizations set audio_authorization_attested_at = now() where id = $1", [id.data]);
      // El código en claro SOLO se devuelve aquí (se guarda únicamente su hash).
      return reply.code(201).send({ id: r.rows[0].id, code, qr: qrPayload(code), joinExpiresAt: r.rows[0].join_expires_at, maxListeners });
    }
    return reply.code(500).send({ error: "internal" });
  });

  app.post("/v1/orgs/:id/sessions/:sid/end", async (req, reply) => {
    const p = req.params as { id?: string; sid?: string };
    const id = Id.safeParse(p.id);
    const sid = Id.safeParse(p.sid);
    if (!id.success || !sid.success) return reply.code(400).send({ error: "bad_request" });
    const m = await requireManager(req, reply, id.data);
    if (!m) return;
    const r = await ctx.db.query("select 1 from public.church_sessions where id = $1 and org_id = $2", [sid.data, id.data]);
    if (!r.rowCount) return reply.code(404).send({ error: "not_found" });
    const live = ctx.church.broadcastFor(sid.data);
    if (live) await live.end("user_stopped");
    else ctx.church.endWithoutBroadcast(sid.data);
    await ctx.db.query("update public.church_sessions set status = 'ended', ended_at = coalesce(ended_at, now()) where id = $1", [sid.data]);
    return { ok: true };
  });

  // ───────── Unirse (asistentes; sin cuenta) ─────────
  app.post("/v1/church/join", async (req, reply) => {
    if (!(await enabled(reply))) return;
    if (!limiter.allow(req.ip)) return reply.code(429).send({ error: "rate_limited" });
    const b = z.object({ code: z.string().max(40) }).safeParse(req.body);
    const code = b.success ? normalizeJoinCode(b.data.code) : null;
    if (!code) return reply.code(404).send({ error: "invalid_code" });
    if (!ctx.cfg.LISTENER_TOKEN_SECRET) return reply.code(503).send({ error: "church_mode_disabled" });
    const r = await ctx.db.query<{ id: string; status: string; source_lang: string; target_lang: string | null; join_expires_at: Date; name: string; max_listeners: number }>(
      `select cs.id, cs.status, cs.source_lang, cs.target_lang, cs.join_expires_at, cs.max_listeners, o.name
       from public.church_sessions cs join public.organizations o on o.id = cs.org_id
       where cs.join_code_hash = $1 and cs.status <> 'ended' and cs.join_expires_at > now()`,
      [hashJoinCode(code)],
    );
    const s = r.rows[0];
    // Mismo error para código inexistente, vencido o terminado.
    if (!s) return reply.code(404).send({ error: "invalid_code" });
    if (ctx.church.listenerCount(s.id) >= s.max_listeners) return reply.code(409).send({ error: "session_full" });
    const token = await signListenerToken(ctx.cfg.LISTENER_TOKEN_SECRET, { listenerId: randomUUID(), churchSessionId: s.id }, s.join_expires_at);
    return {
      token,
      churchSessionId: s.id,
      orgName: s.name,
      sourceLang: s.source_lang,
      targetLang: s.target_lang,
      broadcasting: ctx.church.isBroadcasting(s.id),
    };
  });
}

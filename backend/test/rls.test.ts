import { describe, expect, it } from "vitest";
import { createUser, testDb } from "./helpers.js";

/**
 * Políticas RLS: se ejecutan consultas como el rol "authenticated" con el
 * claim "sub" de cada usuario, igual que hace Supabase con su JWT.
 */
async function asUser<T>(userId: string, fn: (q: (sql: string, p?: unknown[]) => Promise<any[]>) => Promise<T>): Promise<T> {
  const c = await testDb().connect();
  try {
    await c.query("begin");
    await c.query("set local role authenticated");
    await c.query("select set_config('request.jwt.claims', $1, true)", [JSON.stringify({ sub: userId, role: "authenticated" })]);
    return await fn(async (sql, p) => (await c.query(sql, p)).rows);
  } finally {
    await c.query("rollback");
    c.release();
  }
}

describe("aislamiento por usuario y organización (RLS)", () => {
  it("un usuario solo ve sus transcripciones y segmentos", async () => {
    const db = testDb();
    const a = await createUser(db);
    const b = await createUser(db);
    const t = await db.query<{ id: string }>("insert into public.transcripts (user_id, source_lang, expires_at) values ($1,'en', now()+interval '1 day') returning id", [b]);
    await db.query("insert into public.transcript_segments (transcript_id, seq, start_ms, end_ms, source_text) values ($1,0,0,1,'secret sermon')", [t.rows[0]!.id]);
    await asUser(a, async (q) => {
      expect(await q("select * from public.transcripts")).toHaveLength(0);
      expect(await q("select * from public.transcript_segments")).toHaveLength(0);
      await q("delete from public.transcripts where id = $1", [t.rows[0]!.id]);
    });
    expect((await db.query("select count(*)::int n from public.transcripts where id=$1", [t.rows[0]!.id])).rows[0].n).toBe(1);
    await asUser(b, async (q) => {
      expect(await q("select * from public.transcript_segments")).toHaveLength(1);
    });
  });

  it("los usuarios no pueden modificar beneficios ni cuotas ni leer tablas operativas", async () => {
    const db = testDb();
    const a = await createUser(db);
    await asUser(a, async (q) => {
      await expect(q("insert into public.entitlements (user_id, plan, status) values ($1,'personal','active')", [a])).rejects.toThrow(/permission denied/);
    });
    await asUser(a, async (q) => {
      await expect(q("update public.usage_periods set used_seconds = 0")).rejects.toThrow(/permission denied/);
    });
    for (const t of ["webhook_events", "app_config", "spend_ledger", "account_deletions"]) {
      await asUser(a, async (q) => {
        await expect(q(`select * from public.${t}`)).rejects.toThrow(/permission denied/);
      });
    }
  });

  it("aislamiento entre iglesias: no miembros no ven organizaciones ni sesiones; no hay listado público", async () => {
    const db = testDb();
    const owner = await createUser(db);
    const outsider = await createUser(db);
    const org = await db.query<{ id: string }>("insert into public.organizations (name, created_by) values ('Iglesia A', $1) returning id", [owner]);
    await db.query("insert into public.organization_members (org_id, user_id, role) values ($1,$2,'owner')", [org.rows[0]!.id, owner]);
    await db.query("insert into public.church_sessions (org_id, created_by, join_code_hash, source_lang, target_lang) values ($1,$2,$3,'en','es')", [org.rows[0]!.id, owner, `h-${owner}`]);
    await asUser(outsider, async (q) => {
      expect(await q("select * from public.organizations")).toHaveLength(0);
      expect(await q("select * from public.church_sessions")).toHaveLength(0);
      expect(await q("select * from public.organization_members")).toHaveLength(0);
    });
    await asUser(owner, async (q) => {
      expect(await q("select * from public.church_sessions")).toHaveLength(1);
    });
  });

  it("glosario: términos del sistema visibles, los de otros no; no se puede insertar a nombre de otro", async () => {
    const db = testDb();
    const a = await createUser(db);
    const b = await createUser(db);
    await db.query("insert into public.glossary_terms (user_id, source_lang, target_lang, source_term, target_term) values ($1,'en','es','covenant','pacto')", [b]);
    await asUser(a, async (q) => {
      expect(await q("select * from public.glossary_terms where user_id is not null")).toHaveLength(0);
      await expect(q("insert into public.glossary_terms (user_id, source_lang, target_lang, source_term, target_term) values ($1,'en','es','x','y')", [b])).rejects.toThrow(/row-level security/);
    });
  });
});

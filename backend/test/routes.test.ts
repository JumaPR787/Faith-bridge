import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { api, createUser, grant, startServer, testDb, tokenFor, type TestServer } from "./helpers.js";

describe("rutas HTTP", () => {
  let srv: TestServer;
  beforeAll(async () => {
    srv = await startServer();
  });
  afterAll(async () => srv.close());

  it("exige autenticación", async () => {
    expect((await api(srv.baseUrl, "GET", "/v1/me")).status).toBe(401);
    expect((await api(srv.baseUrl, "GET", "/v1/transcripts", "garbage.token.value")).status).toBe(401);
  });

  it("traducción de texto: estima, exige confirmación y descuenta cuota", async () => {
    const db = testDb();
    const u = await createUser(db);
    await grant(db, u);
    const token = await tokenFor(u);
    const text = "Grace is a gift. ".repeat(100); // se cuentan los caracteres enviados (sin espacios entre fragmentos) → 2 minutos
    const est = await api(srv.baseUrl, "POST", "/v1/translate/estimate", token, { source: "en", target: "es", text });
    expect(est.json).toMatchObject({ chars: 1697, costSeconds: 120, allowed: true });
    const noConfirm = await api(srv.baseUrl, "POST", "/v1/translate", token, { source: "en", target: "es", text });
    expect(noConfirm.status).toBe(400);
    const ok = await api(srv.baseUrl, "POST", "/v1/translate", token, { source: "en", target: "es", text, confirm: true });
    expect(ok.status).toBe(200);
    expect(ok.json.chargedSeconds).toBe(120);
    expect(ok.json.text).toContain("[SIM→es]");
    const me = await api(srv.baseUrl, "GET", "/v1/me", token);
    expect(me.json.quota.usedSeconds).toBe(120);
  });

  it("traducción de texto sin suscripción o demasiado largo", async () => {
    const db = testDb();
    const u = await createUser(db);
    const token = await tokenFor(u);
    const est = await api(srv.baseUrl, "POST", "/v1/translate/estimate", token, { source: "en", target: "es", text: "Hello" });
    expect(est.json).toMatchObject({ allowed: false, reason: "no_entitlement" });
    await grant(db, u);
    const long = await api(srv.baseUrl, "POST", "/v1/translate", token, { source: "en", target: "es", text: "a".repeat(20001), confirm: true });
    expect(long.status).toBe(413);
  });

  it("glosario personal: crear, listar, duplicado, borrar", async () => {
    const db = testDb();
    const u = await createUser(db);
    const token = await tokenFor(u);
    const c = await api(srv.baseUrl, "POST", "/v1/glossary", token, { source: "en", target: "es", sourceTerm: "fellowship", targetTerm: "comunión" });
    expect(c.status).toBe(201);
    expect((await api(srv.baseUrl, "POST", "/v1/glossary", token, { source: "en", target: "es", sourceTerm: "Fellowship", targetTerm: "x" })).status).toBe(409);
    const l = await api(srv.baseUrl, "GET", "/v1/glossary?source=en&target=es", token);
    expect(l.json.custom).toHaveLength(1);
    expect(l.json.defaults.length).toBeGreaterThan(10);
    const other = await tokenFor(await createUser(db));
    expect((await api(srv.baseUrl, "DELETE", `/v1/glossary/${c.json.id}`, other)).status).toBe(404);
    expect((await api(srv.baseUrl, "DELETE", `/v1/glossary/${c.json.id}`, token)).status).toBe(204);
  });

  it("eliminación de cuenta borra datos del usuario y no de otros", async () => {
    const db = testDb();
    const u = await createUser(db);
    const keep = await createUser(db);
    await grant(db, u);
    await grant(db, keep);
    const token = await tokenFor(u);
    await api(srv.baseUrl, "GET", "/v1/me", token);
    await db.query("insert into public.transcripts (user_id, source_lang, expires_at) values ($1,'en', now() + interval '1 day'), ($2,'en', now() + interval '1 day')", [u, keep]);
    const r = await api(srv.baseUrl, "DELETE", "/v1/account", token);
    expect(r.status).toBe(202);
    expect(r.json.warnings).toEqual([]);
    expect(srv.rc.deleted).toContain(u);
    for (const t of ["transcripts", "entitlements", "profiles", "usage_periods"]) {
      const n = await db.query(`select count(*)::int as n from public.${t} where user_id = $1`, [u]);
      expect(n.rows[0].n, t).toBe(0);
    }
    expect((await db.query("select count(*)::int as n from auth.users where id = $1", [u])).rows[0].n).toBe(0);
    expect((await db.query("select count(*)::int as n from public.transcripts where user_id = $1", [keep])).rows[0].n).toBe(1);
    const del = await db.query("select user_id_hash, completed_at from public.account_deletions order by id desc limit 1");
    expect(del.rows[0].user_id_hash).not.toContain(u);
    expect(del.rows[0].completed_at).not.toBeNull();
  });

  it("purga transcripciones vencidas", async () => {
    const db = testDb();
    const u = await createUser(db);
    await db.query("insert into public.transcripts (user_id, source_lang, expires_at) values ($1,'en', now() - interval '1 day')", [u]);
    const r = await db.query("select public.purge_expired_transcripts() as n");
    expect(r.rows[0].n).toBeGreaterThanOrEqual(1);
  });
});

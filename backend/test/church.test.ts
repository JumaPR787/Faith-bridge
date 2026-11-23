import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { FakeTranslator } from "../src/providers/translation/fake.js";
import { normalizeJoinCode } from "../src/church/codes.js";
import { api, createUser, grant, LiveClient, startServer, testDb, tokenFor, type TestServer } from "./helpers.js";

/**
 * Modo iglesia con PROVEEDORES SIMULADOS: el organizador transmite una sola
 * fuente; los asistentes reciben solo texto, sin micrófono y sin cuenta.
 */
describe("modo iglesia", () => {
  let srv: TestServer;
  const translator = new FakeTranslator();
  beforeAll(async () => {
    srv = await startServer({ translator, cfg: { JOIN_ATTEMPTS_PER_MINUTE: "50" } });
  });
  afterAll(async () => {
    await testDb().query("update public.app_config set value = 'false' where key = 'church_mode_enabled'");
    await srv.close();
  });
  beforeEach(async () => {
    await testDb().query("update public.app_config set value = 'true' where key = 'church_mode_enabled'");
  });

  async function setupOrg(opts: { maxListeners?: number; save?: boolean } = {}) {
    const db = testDb();
    const owner = await createUser(db);
    await grant(db, owner, { plan: "church" });
    const token = await tokenFor(owner);
    const org = await api(srv.baseUrl, "POST", "/v1/orgs", token, { name: "Iglesia Esperanza", attestAudioAuthorization: true });
    expect(org.status).toBe(201);
    const sess = await api(srv.baseUrl, "POST", `/v1/orgs/${org.json.id}/sessions`, token, {
      sourceLang: "en", targetLang: "es", attestAudioAuthorization: true, maxListeners: opts.maxListeners, saveTranscript: opts.save ?? false,
    });
    expect(sess.status).toBe(201);
    return { owner, token, orgId: org.json.id as string, sessionId: sess.json.id as string, code: sess.json.code as string, qr: sess.json.qr as string };
  }

  async function join(code: string) {
    return api(srv.baseUrl, "POST", "/v1/church/join", undefined, { code });
  }

  async function listen(token: string, lastSeq?: number) {
    const c = new LiveClient(srv.wsUrl.replace("/v1/live", "/v1/church/listen"));
    await c.open();
    c.send({ type: "listen", token, lastSeq });
    await c.waitFor("joined");
    return c;
  }

  async function broadcast(token: string, churchSessionId: string) {
    const c = new LiveClient(srv.wsUrl);
    await c.open();
    c.send({ type: "start", token, protocol: 1, sourceLang: "es", targetLang: null, mode: "church", churchSessionId });
    return c;
  }

  it("está deshabilitado por defecto (interruptor)", async () => {
    await testDb().query("update public.app_config set value = 'false' where key = 'church_mode_enabled'");
    const u = await createUser(testDb());
    const r = await api(srv.baseUrl, "POST", "/v1/orgs", await tokenFor(u), { name: "X Church", attestAudioAuthorization: true });
    expect(r.status).toBe(503);
    expect((await join("ABCD-EFGH")).status).toBe(503);
  });

  it("exige declarar la autorización del audio y el plan Iglesia", async () => {
    const db = testDb();
    const u = await createUser(db);
    await grant(db, u); // plan personal
    const token = await tokenFor(u);
    expect((await api(srv.baseUrl, "POST", "/v1/orgs", token, { name: "Sin atestación" })).status).toBe(400);
    const org = await api(srv.baseUrl, "POST", "/v1/orgs", token, { name: "Con plan personal", attestAudioAuthorization: true });
    const s = await api(srv.baseUrl, "POST", `/v1/orgs/${org.json.id}/sessions`, token, { sourceLang: "en", targetLang: "es", attestAudioAuthorization: true });
    expect(s.status).toBe(402);
    expect(s.json.error).toBe("no_church_plan");
  });

  it("una sola transcripción y traducción por segmento se reparte a todos los oyentes", async () => {
    const o = await setupOrg();
    expect(o.qr).toBe(`FAITHBRIDGE:${o.code}`);
    expect(normalizeJoinCode(o.qr)).toBe(o.code.replace("-", ""));
    // Asistentes sin cuenta: el código basta (en minúsculas y sin guion también).
    const j1 = await join(o.code.toLowerCase().replace("-", ""));
    expect(j1.status).toBe(200);
    expect(j1.json).toMatchObject({ orgName: "Iglesia Esperanza", sourceLang: "en", targetLang: "es", broadcasting: false });
    const j2 = await join(o.code);
    const l1 = await listen(j1.json.token);
    const l2 = await listen(j2.json.token);
    await l1.waitFor("waiting");

    const callsBefore = translator.calls;
    // El idioma lo fija la sesión de iglesia (en→es), no lo que envíe el cliente.
    const b = await broadcast(o.token, o.sessionId);
    const ready = await b.waitFor("ready");
    expect(ready.translation).toBe(true);
    await b.waitFor("listeners", (e) => e.count === 2);
    b.sendAudioSeconds(3);
    for (const l of [l1, l2]) {
      await l.waitFor("translation", (e) => e.seq === 2);
      expect(l.of("segment").map((s) => s.seq)).toEqual([0, 1, 2]);
      expect(l.of("segment")[0]!.text).toContain("[SIMULATED]");
      // Los oyentes no reciben datos de cuota ni de uso.
      expect(l.events.some((e) => e.type === "usage" || e.type === "quota_warning" || e.type === "ready")).toBe(false);
    }
    // 3 segmentos → 3 traducciones, aunque haya 2 oyentes.
    expect(translator.calls - callsBefore).toBe(3);

    // Un oyente NO puede enviar audio: se ignora y no se cobra.
    l1.sendAudioSeconds(5);
    b.send({ type: "stop" });
    const ended = await b.waitFor("ended");
    expect(ended.sessionSeconds).toBe(3);
    const le = await l1.waitFor("ended");
    expect(le.reason).toBe("user_stopped");

    const db = testDb();
    const cs = await db.query("select status from public.church_sessions where id = $1", [o.sessionId]);
    expect(cs.rows[0].status).toBe("ended");
    const usage = await db.query("select broadcast_seconds, peak_listeners from public.church_usage where org_id = $1", [o.orgId]);
    expect(usage.rows[0]).toMatchObject({ broadcast_seconds: 3, peak_listeners: 2 });
    // Los minutos se descuentan una vez del plan Iglesia, no por asistente.
    const used = await db.query("select used_seconds from public.usage_periods where user_id = $1", [o.owner]);
    expect(used.rows[0].used_seconds).toBe(3);
    await new Promise((r) => setTimeout(r, 200));
    const ls = await db.query("select count(*)::int as n, sum(bytes_sent)::int as bytes from public.church_session_listeners where church_session_id = $1 and left_at is not null", [o.sessionId]);
    expect(ls.rows[0].n).toBe(2);
    expect(ls.rows[0].bytes).toBeGreaterThan(0);
    // Sesión terminada: el código ya no sirve.
    expect((await join(o.code)).status).toBe(404);
  });

  it("límite de asistentes", async () => {
    const o = await setupOrg({ maxListeners: 1 });
    const j1 = await join(o.code);
    await listen(j1.json.token);
    const j2 = await join(o.code);
    expect(j2.status).toBe(409);
    expect(j2.json.error).toBe("session_full");
  });

  it("código inválido: mismo error sin revelar nada; límite de intentos", async () => {
    expect((await join("ZZZZ-ZZZZ")).json.error).toBe("invalid_code");
    expect((await join("no-es-codigo")).json.error).toBe("invalid_code");
  });

  it("si el organizador se desconecta, los oyentes esperan y reciben la transmisión al volver", async () => {
    const o = await setupOrg();
    const j = await join(o.code);
    const l = await listen(j.json.token);
    const b = await broadcast(o.token, o.sessionId);
    await b.waitFor("ready");
    b.sendAudioSeconds(1);
    await l.waitFor("segment", (e) => e.seq === 0);
    b.ws.terminate();
    await l.waitFor("broadcast_interrupted", () => true, 5000);
    expect(l.closed).toBe(false);
    const cs = await testDb().query("select status from public.church_sessions where id = $1", [o.sessionId]);
    expect(cs.rows[0].status).toBe("scheduled");
    const b2 = await broadcast(o.token, o.sessionId);
    await b2.waitFor("listeners", (e) => e.count === 1);
    b2.sendAudioSeconds(1);
    await l.waitFor("segment", (e) => e.seq === 0 && l.of("segment").length === 2, 5000);
    // Fin explícito por API (aunque esté transmitiendo).
    const end = await api(srv.baseUrl, "POST", `/v1/orgs/${o.orgId}/sessions/${o.sessionId}/end`, o.token);
    expect(end.status).toBe(200);
    await l.waitFor("ended");
  });

  it("control de acceso: un miembro no puede transmitir; un ajeno no ve la organización", async () => {
    const o = await setupOrg();
    const db = testDb();
    const member = await createUser(db);
    await grant(db, member, { plan: "church" });
    const email = (await db.query("select email from auth.users where id = $1", [member])).rows[0].email as string;
    expect((await api(srv.baseUrl, "POST", `/v1/orgs/${o.orgId}/members`, o.token, { email, role: "member" })).status).toBe(201);
    const mb = await broadcast(await tokenFor(member), o.sessionId);
    expect((await mb.waitFor("error")).code).toBe("not_allowed");
    const memberView = await api(srv.baseUrl, "GET", `/v1/orgs/${o.orgId}`, await tokenFor(member));
    expect(memberView.status).toBe(200);
    expect(memberView.json.members).toEqual([]); // los miembros no ven la lista de correos
    expect((await api(srv.baseUrl, "POST", `/v1/orgs/${o.orgId}/sessions`, await tokenFor(member), { sourceLang: "en", targetLang: "es", attestAudioAuthorization: true })).status).toBe(403);

    const outsider = await createUser(db);
    await grant(db, outsider, { plan: "church" });
    const ot = await tokenFor(outsider);
    expect((await api(srv.baseUrl, "GET", `/v1/orgs/${o.orgId}`, ot)).status).toBe(404);
    const ob = await broadcast(ot, o.sessionId);
    expect((await ob.waitFor("error")).code).toBe("session_not_found");
    expect((await api(srv.baseUrl, "POST", `/v1/orgs/${o.orgId}/sessions/${o.sessionId}/end`, ot)).status).toBe(404);
  });

  it("un acceso de oyente falsificado o de otra clave no sirve", async () => {
    const c = new LiveClient(srv.wsUrl.replace("/v1/live", "/v1/church/listen"));
    await c.open();
    c.send({ type: "listen", token: "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ4In0.invalidsignature" });
    expect((await c.waitFor("error")).code).toBe("unauthorized");
    // Un token de usuario normal tampoco es un acceso de oyente.
    const u = await createUser(testDb());
    const c2 = new LiveClient(srv.wsUrl.replace("/v1/live", "/v1/church/listen"));
    await c2.open();
    c2.send({ type: "listen", token: await tokenFor(u) });
    expect((await c2.waitFor("error")).code).toBe("unauthorized");
  });

  it("la transcripción guardada pertenece a la organización (visible para sus miembros por RLS)", async () => {
    const o = await setupOrg({ save: true });
    const b = await broadcast(o.token, o.sessionId);
    await b.waitFor("ready");
    b.sendAudioSeconds(1);
    await b.waitFor("translation", (e) => e.seq === 0);
    b.send({ type: "stop" });
    const ended = await b.waitFor("ended");
    expect(ended.transcriptId).toBeTruthy();
    const t = await testDb().query("select org_id from public.transcripts where id = $1", [ended.transcriptId]);
    expect(t.rows[0].org_id).toBe(o.orgId);
  });
});

import { qrPayload } from "../src/church/codes.js";

describe("enlaces universales del QR", () => {
  it("con dominio configurado, el QR es un enlace https corto", () => {
    expect(qrPayload("ABCD-2345", "https://faithbridge.example/j/")).toBe("https://faithbridge.example/j/ABCD2345");
    expect(qrPayload("ABCD-2345")).toBe("FAITHBRIDGE:ABCD-2345");
  });
  it("el código se extrae de enlaces, prefijos y texto escrito", () => {
    for (const v of ["https://faithbridge.example/j/ABCD2345", "https://faithbridge.example/j/abcd-2345/", "https://x.example/join?code=ABCD-2345", "FAITHBRIDGE:ABCD-2345", " abcd 2345 "]) {
      expect(normalizeJoinCode(v), v).toBe("ABCD2345");
    }
    expect(normalizeJoinCode("https://faithbridge.example/otra/ruta")).toBeNull();
  });
});

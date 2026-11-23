import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { FakeTranslator } from "../src/providers/translation/fake.js";
import { api, createUser, grant, LiveClient, startServer, testDb, tokenFor, type TestServer } from "./helpers.js";

/**
 * Recorrido completo con PROVEEDORES SIMULADOS (FakeSttProvider/FakeTranslator):
 * audio → STT → segmentos → traducción → eventos al cliente, cuota en servidor.
 */
describe("sesión en vivo (WebSocket)", () => {
  let srv: TestServer;
  // Traducción con demora inversa: la 1ª tarda más que la 2ª → llegan desordenadas.
  const translator = new FakeTranslator({ delayMs: (t) => (t.includes("Good morning") ? 300 : 10), failWhen: (t) => t.includes("pray") });
  beforeAll(async () => {
    srv = await startServer({ translator });
  });
  afterAll(async () => {
    await srv.close();
  });

  async function startClient(token: string, extra: Record<string, unknown> = {}) {
    const c = new LiveClient(srv.wsUrl);
    await c.open();
    c.send({ type: "start", token, protocol: 1, sourceLang: "en", targetLang: "es", saveTranscript: false, ...extra });
    return c;
  }

  it("transcribe y traduce; traducciones fuera de orden conservan su seq; fallos se marcan", async () => {
    const db = testDb();
    const u = await createUser(db);
    await grant(db, u);
    const c = await startClient(await tokenFor(u));
    const ready = await c.waitFor("ready");
    expect(ready.translation).toBe(true);
    expect(ready.simulated).toBe(true);
    expect(ready.quota.remainingSeconds).toBe(300 * 60);
    c.sendAudioSeconds(4); // FakeStt: 1 frase por segundo
    await c.waitFor("translation", (e) => e.seq === 3);
    await c.waitFor("translation", (e) => e.seq === 0);
    const segs = c.of("segment");
    expect(segs.map((s) => s.seq)).toEqual([0, 1, 2, 3]);
    expect(segs[0]!.text).toContain("[SIMULATED] Good morning church.");
    const tr = c.of("translation");
    // Llegada desordenada, pero cada traducción referencia su seq.
    expect(tr.findIndex((t) => t.seq === 1)).toBeLessThan(tr.findIndex((t) => t.seq === 0));
    expect(tr.find((t) => t.seq === 3)).toMatchObject({ status: "failed", text: null });
    expect(tr.find((t) => t.seq === 1)!.text).toBe("[SIM→es] [SIMULATED] Today we read John 3:16.");
    // Cada seq tiene a lo sumo una traducción (sin duplicados).
    expect(new Set(tr.map((t) => t.seq)).size).toBe(tr.length);

    c.send({ type: "stop" });
    const ended = await c.waitFor("ended");
    expect(ended).toMatchObject({ reason: "user_stopped", transcriptId: null, sessionSeconds: 4 });
    // Uso medido en servidor: 4 s, contados una sola vez (transcripción + traducción).
    const used = await db.query("select used_seconds from public.usage_periods where user_id = $1", [u]);
    expect(used.rows[0].used_seconds).toBe(4);
    // Sin guardar: no hay transcripción persistida.
    const t = await db.query("select count(*)::int as n from public.transcripts where user_id = $1", [u]);
    expect(t.rows[0].n).toBe(0);
  });

  it("solo transcripción (sin idioma destino) no llama al traductor", async () => {
    const db = testDb();
    const u = await createUser(db);
    await grant(db, u);
    const before = translator.calls;
    const c = await startClient(await tokenFor(u), { targetLang: null, sourceLang: "es" });
    expect((await c.waitFor("ready")).translation).toBe(false);
    c.sendAudioSeconds(2);
    await c.waitFor("segment", (e) => e.seq === 1);
    expect(c.of("segment")[0]!.text).toContain("[SIMULADO]");
    expect(translator.calls).toBe(before);
    c.send({ type: "stop" });
    await c.waitFor("ended");
  });

  it("guarda la transcripción solo si el usuario lo elige, y se puede consultar y borrar", async () => {
    const db = testDb();
    const u = await createUser(db);
    await grant(db, u);
    const token = await tokenFor(u);
    const c = await startClient(token, { saveTranscript: true });
    await c.waitFor("ready");
    c.sendAudioSeconds(2);
    await c.waitFor("translation", (e) => e.seq === 1);
    await c.waitFor("translation", (e) => e.seq === 0);
    c.send({ type: "stop" });
    const ended = await c.waitFor("ended");
    expect(ended.transcriptId).toBeTruthy();
    const detail = await api(srv.baseUrl, "GET", `/v1/transcripts/${ended.transcriptId}`, token);
    expect(detail.status).toBe(200);
    expect(detail.json.segments).toHaveLength(2);
    expect(detail.json.segments[0]).toMatchObject({ seq: 0, translationStatus: "ok" });
    // Otro usuario no puede verla (404, sin revelar existencia).
    const other = await createUser(db);
    expect((await api(srv.baseUrl, "GET", `/v1/transcripts/${ended.transcriptId}`, await tokenFor(other))).status).toBe(404);
    expect((await api(srv.baseUrl, "DELETE", `/v1/transcripts/${ended.transcriptId}`, token)).status).toBe(204);
    expect((await api(srv.baseUrl, "GET", `/v1/transcripts/${ended.transcriptId}`, token)).status).toBe(404);
  });

  it("detiene la sesión al agotar la cuota (sin cobro extra)", async () => {
    const db = testDb();
    const u = await createUser(db);
    await grant(db, u, { status: "trial" });
    const token = await tokenFor(u);
    const c0 = await startClient(token);
    expect((await c0.waitFor("ready")).quota.remainingSeconds).toBe(120 * 60);
    c0.send({ type: "stop" });
    await c0.waitFor("ended");
    await db.query("update public.usage_periods set used_seconds = quota_seconds - 3 where user_id = $1", [u]);
    const c = await startClient(token);
    expect((await c.waitFor("ready")).quota.remainingSeconds).toBe(3);
    c.sendAudioSeconds(6);
    const ended = await c.waitFor("ended");
    expect(ended.reason).toBe("quota_exhausted");
    expect(ended.sessionSeconds).toBe(3);
    // Nuevo intento: rechazado con quota_exhausted.
    const c2 = await startClient(token);
    expect((await c2.waitFor("error")).code).toBe("quota_exhausted");
  });

  it("rechaza sin beneficio activo y con token inválido", async () => {
    const db = testDb();
    const u = await createUser(db);
    const c = await startClient(await tokenFor(u));
    expect((await c.waitFor("error")).code).toBe("no_entitlement");
    const c2 = await startClient("not-a-valid-token-xxxxx");
    expect((await c2.waitFor("error")).code).toBe("unauthorized");
  });

  it("interruptor operativo bloquea nuevas sesiones sin afectar datos guardados", async () => {
    const db = testDb();
    const u = await createUser(db);
    await grant(db, u);
    await db.query("update public.app_config set value = 'false' where key = 'live_sessions_enabled'");
    try {
      const c = await startClient(await tokenFor(u));
      expect((await c.waitFor("error")).code).toBe("service_paused");
    } finally {
      await db.query("update public.app_config set value = 'true' where key = 'live_sessions_enabled'");
    }
  });

  it("límite diario de gasto bloquea nuevas sesiones", async () => {
    const db = testDb();
    const u = await createUser(db);
    await grant(db, u);
    await db.query("update public.app_config set value = '0' where key = 'daily_cost_limit_usd'");
    try {
      const c = await startClient(await tokenFor(u));
      expect((await c.waitFor("error")).code).toBe("daily_budget_reached");
    } finally {
      await db.query("update public.app_config set value = '25' where key = 'daily_cost_limit_usd'");
    }
  });

  it("reanuda tras caída de red y reenvía solo lo que faltó", async () => {
    const db = testDb();
    const u = await createUser(db);
    await grant(db, u);
    const token = await tokenFor(u);
    const c = await startClient(token);
    const ready = await c.waitFor("ready");
    c.sendAudioSeconds(2);
    await c.waitFor("segment", (e) => e.seq === 1);
    c.ws.terminate(); // corte abrupto
    await new Promise((r) => setTimeout(r, 100));
    const c2 = new LiveClient(srv.wsUrl);
    await c2.open();
    c2.send({ type: "start", token, protocol: 1, sourceLang: "en", targetLang: "es", resumeSessionId: ready.sessionId, lastSeq: 0 });
    expect((await c2.waitFor("ready")).resumed).toBe(true);
    await c2.waitFor("segment", (e) => e.seq === 1);
    expect(c2.of("segment").map((s) => s.seq)).toEqual([1]);
    c2.sendAudioSeconds(1);
    await c2.waitFor("segment", (e) => e.seq === 2);
    c2.send({ type: "stop" });
    await c2.waitFor("ended");
    // Otro usuario no puede reanudar una sesión ajena.
    const intruder = await createUser(db);
    await grant(db, intruder);
    const c3 = new LiveClient(srv.wsUrl);
    await c3.open();
    c3.send({ type: "start", token: await tokenFor(intruder), protocol: 1, sourceLang: "en", targetLang: "es", resumeSessionId: ready.sessionId });
    expect((await c3.waitFor("error")).code).toBe("session_not_found");
  });

  it("si el cliente no vuelve dentro del periodo de gracia, la sesión termina", async () => {
    const db = testDb();
    const u = await createUser(db);
    await grant(db, u);
    const c = await startClient(await tokenFor(u));
    const ready = await c.waitFor("ready");
    c.ws.terminate();
    await new Promise((r) => setTimeout(r, 2600));
    const r = await db.query("select status, end_reason from public.live_sessions where id = $1", [ready.sessionId]);
    expect(r.rows[0]).toEqual({ status: "ended", end_reason: "client_gone" });
  });

  it("pausa: el audio enviado en pausa no se cobra", async () => {
    const db = testDb();
    const u = await createUser(db);
    await grant(db, u);
    const c = await startClient(await tokenFor(u), { targetLang: null });
    await c.waitFor("ready");
    c.sendAudioSeconds(1);
    c.send({ type: "pause" });
    await c.waitFor("provider_status", (e) => e.status === "paused");
    c.sendAudioSeconds(3);
    c.send({ type: "resume" });
    c.sendAudioSeconds(1);
    c.send({ type: "stop" });
    expect((await c.waitFor("ended")).sessionSeconds).toBe(2);
  });

  it("una sola sesión activa por usuario: la nueva reemplaza la anterior", async () => {
    const db = testDb();
    const u = await createUser(db);
    await grant(db, u);
    const token = await tokenFor(u);
    const a = await startClient(token);
    await a.waitFor("ready");
    const b = await startClient(token);
    await b.waitFor("ready");
    expect((await a.waitFor("ended")).reason).toBe("superseded");
    const r = await db.query("select count(*)::int as n from public.live_sessions where user_id = $1 and status = 'active'", [u]);
    expect(r.rows[0].n).toBe(1);
    b.send({ type: "stop" });
    await b.waitFor("ended");
  });
});

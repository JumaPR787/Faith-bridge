import { afterAll, beforeAll, describe, expect, it } from "vitest";
import type { RcSubscriber } from "../src/billing/entitlements.js";
import { api, createUser, startServer, testDb, tokenFor, WEBHOOK_AUTH, type TestServer } from "./helpers.js";

const iso = (days: number) => new Date(Date.now() + days * 86400_000).toISOString();
function rcSub(o: { trial?: boolean; start?: string; end?: string; refunded?: string | null; unsub?: string | null } = {}): RcSubscriber {
  const s = {
    expires_date: o.end ?? iso(o.trial ? 7 : 30), purchase_date: o.start ?? iso(0), period_type: o.trial ? "trial" : "normal",
    store: "play_store", is_sandbox: true, unsubscribe_detected_at: o.unsub ?? null, billing_issues_detected_at: null, refunded_at: o.refunded ?? null,
  };
  return { entitlements: { personal: { expires_date: s.expires_date, product_identifier: "fb_personal", purchase_date: s.purchase_date } }, subscriptions: { fb_personal: s } };
}

describe("suscripciones: webhook + sincronización + cuotas", () => {
  let srv: TestServer;
  beforeAll(async () => {
    srv = await startServer();
  });
  afterAll(async () => srv.close());

  const hook = (body: unknown, auth = WEBHOOK_AUTH) =>
    fetch(`${srv.baseUrl}/webhooks/revenuecat`, { method: "POST", headers: { authorization: auth, "content-type": "application/json" }, body: JSON.stringify(body) });

  it("rechaza webhooks sin el secreto correcto", async () => {
    expect((await hook({ event: { id: "x", type: "TEST" } }, "wrong")).status).toBe(401);
    expect((await fetch(`${srv.baseUrl}/webhooks/revenuecat`, { method: "POST", headers: { "content-type": "application/json" }, body: "{}" })).status).toBe(401);
  });

  it("prueba → 120 min; idempotente; conversión a pago → 300 min en el nuevo periodo", async () => {
    const db = testDb();
    const u = await createUser(db);
    const token = await tokenFor(u);
    const trialStart = iso(-1);
    srv.rc.subscribers.set(u, rcSub({ trial: true, start: trialStart, end: iso(6) }));
    const ev = { event: { id: `evt-${u}-1`, type: "INITIAL_PURCHASE", app_user_id: u } };
    expect((await hook(ev)).status).toBe(200);
    const callsAfterFirst = srv.rc.calls;
    const dup = await hook(ev);
    expect(await dup.json()).toMatchObject({ ok: true, duplicate: true });
    expect(srv.rc.calls).toBe(callsAfterFirst); // no reprocesa

    let me = await api(srv.baseUrl, "GET", "/v1/me", token);
    expect(me.json.quota).toMatchObject({ status: "trial", isTrial: true, quotaSeconds: 7200, remainingSeconds: 7200, hasAccess: true });

    // Agotar la prueba NO adelanta el cobro: solo bloquea el uso hasta la conversión.
    await db.query("update public.usage_periods set used_seconds = quota_seconds where user_id = $1", [u]);
    me = await api(srv.baseUrl, "GET", "/v1/me", token);
    expect(me.json.quota).toMatchObject({ remainingSeconds: 0, status: "trial", periodEnd: expect.any(String) });

    // La tienda cobra al final de la prueba → RENEWAL → periodo pagado nuevo.
    srv.rc.subscribers.set(u, rcSub({ start: iso(6), end: iso(36) }));
    // (simulamos que ya pasó el inicio del nuevo periodo)
    srv.rc.subscribers.set(u, rcSub({ start: iso(-0.01), end: iso(30) }));
    expect((await hook({ event: { id: `evt-${u}-2`, type: "RENEWAL", app_user_id: u } })).status).toBe(200);
    me = await api(srv.baseUrl, "GET", "/v1/me", token);
    expect(me.json.quota).toMatchObject({ status: "active", isTrial: false, quotaSeconds: 18000, remainingSeconds: 18000 });
  });

  it("reembolso y vencimiento quitan el acceso", async () => {
    const db = testDb();
    const u = await createUser(db);
    const token = await tokenFor(u);
    srv.rc.subscribers.set(u, rcSub({ start: iso(-2) }));
    await hook({ event: { id: `evt-${u}-a`, type: "INITIAL_PURCHASE", app_user_id: u } });
    expect((await api(srv.baseUrl, "GET", "/v1/me", token)).json.quota.hasAccess).toBe(true);
    srv.rc.subscribers.set(u, rcSub({ start: iso(-2), refunded: iso(-0.5) }));
    await hook({ event: { id: `evt-${u}-b`, type: "CANCELLATION", app_user_id: u } });
    const q = (await api(srv.baseUrl, "GET", "/v1/me", token)).json.quota;
    expect(q).toMatchObject({ hasAccess: false, status: "refunded" });

    srv.rc.subscribers.set(u, rcSub({ start: iso(-31), end: iso(-1) }));
    await hook({ event: { id: `evt-${u}-c`, type: "EXPIRATION", app_user_id: u } });
    expect((await api(srv.baseUrl, "GET", "/v1/me", token)).json.quota).toMatchObject({ hasAccess: false, status: "expired" });
  });

  it("si RevenueCat falla responde 500 y el reintento sí se procesa", async () => {
    const db = testDb();
    const u = await createUser(db);
    srv.rc.subscribers.set(u, rcSub());
    srv.rc.failNext = 1;
    const ev = { event: { id: `evt-${u}-r`, type: "INITIAL_PURCHASE", app_user_id: u } };
    expect((await hook(ev)).status).toBe(500);
    const r2 = await hook(ev);
    expect(r2.status).toBe(200);
    expect(await r2.json()).toMatchObject({ users: 1 });
  });

  it("una segunda prueba para el mismo usuario no recibe minutos (anti-abuso)", async () => {
    const db = testDb();
    const u = await createUser(db);
    const token = await tokenFor(u);
    srv.rc.subscribers.set(u, rcSub({ trial: true, start: iso(-40), end: iso(-33) }));
    await db.query(
      "insert into public.usage_periods (user_id, period_start, period_end, kind, quota_seconds) values ($1,$2,$3,'trial',7200)",
      [u, iso(-40), iso(-33)],
    );
    srv.rc.subscribers.set(u, rcSub({ trial: true, start: iso(-1), end: iso(6) }));
    await api(srv.baseUrl, "POST", "/v1/subscription/sync", token);
    const q = (await api(srv.baseUrl, "GET", "/v1/me", token)).json.quota;
    expect(q).toMatchObject({ isTrial: true, trialAlreadyUsed: true, quotaSeconds: 0 });
  });

  it("sincronización iniciada por la app tras compra/restauración", async () => {
    const db = testDb();
    const u = await createUser(db);
    const token = await tokenFor(u);
    srv.rc.subscribers.set(u, rcSub());
    const r = await api(srv.baseUrl, "POST", "/v1/subscription/sync", token);
    expect(r.status).toBe(200);
    expect(r.json.quota).toMatchObject({ hasAccess: true, plan: "personal", status: "active" });
    srv.rc.failNext = 1;
    expect((await api(srv.baseUrl, "POST", "/v1/subscription/sync", token)).status).toBe(502);
  });

  it("transferencia entre cuentas actualiza a ambos usuarios", async () => {
    const db = testDb();
    const a = await createUser(db);
    const b = await createUser(db);
    srv.rc.subscribers.set(a, rcSub());
    await hook({ event: { id: `evt-${a}-p`, type: "INITIAL_PURCHASE", app_user_id: a } });
    srv.rc.subscribers.set(a, { entitlements: {}, subscriptions: {} });
    srv.rc.subscribers.set(b, rcSub());
    const r = await hook({ event: { id: `evt-${a}-t`, type: "TRANSFER", transferred_from: [a], transferred_to: [b] } });
    expect(await r.json()).toMatchObject({ users: 2 });
    expect((await api(srv.baseUrl, "GET", "/v1/me", await tokenFor(a))).json.quota.hasAccess).toBe(false);
    expect((await api(srv.baseUrl, "GET", "/v1/me", await tokenFor(b))).json.quota.hasAccess).toBe(true);
  });
});

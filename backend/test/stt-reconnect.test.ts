import { afterAll, beforeAll, describe, expect, it } from "vitest";
import type { SttProvider, SttStreamHandlers } from "../src/providers/stt/types.js";
import { FakeSttProvider } from "../src/providers/stt/fake.js";
import { createUser, grant, LiveClient, startServer, testDb, tokenFor, type TestServer } from "./helpers.js";

/** STT simulado que se cae tras la 1ª conexión, para probar la reconexión. */
class FlakyStt implements SttProvider {
  readonly name = "flaky";
  opens = 0;
  failOpens = 0;
  inner = new FakeSttProvider(1);
  handlers: SttStreamHandlers | null = null;
  async open(o: Parameters<SttProvider["open"]>[0], h: SttStreamHandlers) {
    this.opens++;
    if (this.failOpens > 0) {
      this.failOpens--;
      throw new Error("connect failed");
    }
    this.handlers = h;
    return this.inner.open(o, h);
  }
}

describe("reconexión del proveedor de voz", () => {
  let srv: TestServer;
  const stt = new FlakyStt();
  beforeAll(async () => {
    srv = await startServer({ stt });
  });
  afterAll(async () => srv.close());

  it("reconecta con límite de reintentos y termina con stt_unavailable si no puede", async () => {
    const db = testDb();
    const u = await createUser(db);
    await grant(db, u);
    const c = new LiveClient(srv.wsUrl);
    await c.open();
    c.send({ type: "start", token: await tokenFor(u), protocol: 1, sourceLang: "en", targetLang: null });
    await c.waitFor("ready");
    // 1ª caída: reconecta bien.
    stt.handlers!.onError(new Error("socket hang up"));
    await c.waitFor("provider_status", (e) => e.status === "reconnecting");
    await new Promise((r) => setTimeout(r, 100));
    expect(stt.opens).toBe(2);
    // 2ª caída sin poder reconectar (2 reintentos fallan) → fin controlado.
    stt.failOpens = 5;
    stt.handlers!.onError(new Error("socket hang up"));
    const ended = await c.waitFor("ended", () => true, 3000);
    expect(ended.reason).toBe("stt_unavailable");
    expect(c.of("error").some((e) => e.code === "stt_unavailable")).toBe(true);
  });
});

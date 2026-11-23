import { randomUUID } from "node:crypto";
import { SignJWT } from "jose";
import type { AddressInfo } from "node:net";
import WebSocket from "ws";
import { buildApp, createFastify } from "../src/app.js";
import { createTokenVerifier } from "../src/auth.js";
import type { RcSubscriber } from "../src/billing/entitlements.js";
import type { RevenueCatClient } from "../src/billing/revenuecat.js";
import { loadConfig, type Config } from "../src/config.js";
import type { AppContext } from "../src/context.js";
import { createDb, type Db } from "../src/db.js";
import { ChurchRegistry } from "../src/church/registry.js";
import { SessionRegistry } from "../src/live/session.js";
import { OpsGuard } from "../src/ops/guard.js";
import { FakeSttProvider } from "../src/providers/stt/fake.js";
import type { SttProvider } from "../src/providers/stt/types.js";
import { FakeTranslator } from "../src/providers/translation/fake.js";
import type { Translator } from "../src/providers/translation/types.js";
import { QuotaService } from "../src/quota/quota.js";
import type { ServerEvent } from "../src/live/protocol.js";

export const JWT_SECRET = "test-secret-test-secret-test-secret";
export const WEBHOOK_AUTH = "whsec-test-0123456789abcdefghij";

export function testConfig(extra: Record<string, string> = {}): Config {
  return loadConfig({
    APP_ENV: "test",
    DATABASE_URL: process.env.TEST_DATABASE_URL!,
    SUPABASE_JWT_SECRET: JWT_SECRET,
    STT_PROVIDER: "fake",
    TRANSLATION_PROVIDER: "fake",
    REVENUECAT_WEBHOOK_AUTH: WEBHOOK_AUTH,
    LOG_LEVEL: "fatal",
    RESUME_GRACE_SECONDS: "2",
    LISTENER_TOKEN_SECRET: "listener-secret-listener-secret-0123",
    ...extra,
  });
}

let sharedDb: Db | null = null;
export function testDb(): Db {
  sharedDb ??= createDb(process.env.TEST_DATABASE_URL!);
  return sharedDb;
}

export async function tokenFor(userId: string): Promise<string> {
  return new SignJWT({ role: "authenticated" })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(userId)
    .setAudience("authenticated")
    .setIssuedAt()
    .setExpirationTime("1h")
    .sign(new TextEncoder().encode(JWT_SECRET));
}

export async function createUser(db: Db): Promise<string> {
  const id = randomUUID();
  await db.query("insert into auth.users (id, email) values ($1, $2)", [id, `${id.slice(0, 8)}@example.test`]);
  return id;
}

export async function grant(
  db: Db,
  userId: string,
  opts: { status?: string; plan?: string; periodStart?: Date; days?: number } = {},
): Promise<void> {
  const start = opts.periodStart ?? new Date(Date.now() - 60_000);
  const end = new Date(start.getTime() + (opts.days ?? 30) * 86400_000);
  await db.query(
    `insert into public.entitlements (user_id, plan, status, period_start, period_end, access_until, will_renew)
     values ($1,$2,$3,$4,$5,$5,true)
     on conflict (user_id) do update set plan=excluded.plan, status=excluded.status, period_start=excluded.period_start,
       period_end=excluded.period_end, access_until=excluded.access_until`,
    [userId, opts.plan ?? "personal", opts.status ?? "active", start, end],
  );
}

export class FakeRevenueCat implements RevenueCatClient {
  subscribers = new Map<string, RcSubscriber>();
  failNext = 0;
  calls = 0;
  deleted: string[] = [];
  async getSubscriber(id: string): Promise<RcSubscriber> {
    this.calls++;
    if (this.failNext > 0) {
      this.failNext--;
      throw new Error("revenuecat_http_503");
    }
    return this.subscribers.get(id) ?? { entitlements: {}, subscriptions: {} };
  }
  async deleteSubscriber(id: string): Promise<void> {
    this.deleted.push(id);
  }
}

export interface TestServer {
  ctx: AppContext;
  baseUrl: string;
  wsUrl: string;
  rc: FakeRevenueCat;
  close(): Promise<void>;
}

export async function startServer(opts: { stt?: SttProvider; translator?: Translator; cfg?: Record<string, string> } = {}): Promise<TestServer> {
  const cfg = testConfig(opts.cfg);
  const app = createFastify("fatal");
  const db = testDb();
  const rc = new FakeRevenueCat();
  const ctx: AppContext = {
    cfg,
    db,
    log: app.log,
    verifyToken: createTokenVerifier(cfg),
    stt: opts.stt ?? new FakeSttProvider(1),
    translator: opts.translator ?? new FakeTranslator(),
    revenuecat: rc,
    quota: new QuotaService(cfg),
    guard: new OpsGuard(db, cfg, app.log),
    registry: new SessionRegistry(),
    church: new ChurchRegistry(db, app.log),
    deleteAuthUser: async (id) => {
      await db.query("delete from auth.users where id = $1", [id]);
    },
    liveFlushIntervalMs: 200,
    sttRetryDelaysMs: [20, 20],
  };
  await buildApp(ctx, app);
  await app.listen({ port: 0, host: "127.0.0.1" });
  const port = (app.server.address() as AddressInfo).port;
  return {
    ctx,
    rc,
    baseUrl: `http://127.0.0.1:${port}`,
    wsUrl: `ws://127.0.0.1:${port}/v1/live`,
    close: async () => {
      await Promise.allSettled(ctx.registry.all().map((s) => s.end("server_shutdown")));
      await app.close();
    },
  };
}

/** Cliente WebSocket de prueba que acumula eventos. */
export class LiveClient {
  events: ServerEvent[] = [];
  ws: WebSocket;
  closed = false;
  closeCode: number | null = null;
  private waiters: Array<() => void> = [];

  constructor(url: string) {
    this.ws = new WebSocket(url);
    this.ws.on("message", (d) => {
      this.events.push(JSON.parse(d.toString()) as ServerEvent);
      this.waiters.splice(0).forEach((w) => w());
    });
    this.ws.on("close", (code) => {
      this.closed = true;
      this.closeCode = code;
      this.waiters.splice(0).forEach((w) => w());
    });
  }

  async open(): Promise<void> {
    if (this.ws.readyState === WebSocket.OPEN) return;
    await new Promise<void>((r, j) => {
      this.ws.once("open", () => r());
      this.ws.once("error", j);
    });
  }

  send(obj: unknown): void {
    this.ws.send(JSON.stringify(obj));
  }

  /** Envía N segundos de silencio PCM16 en tramas de 100 ms. */
  sendAudioSeconds(seconds: number): void {
    const frame = Buffer.alloc(3200);
    for (let i = 0; i < seconds * 10; i++) this.ws.send(frame);
  }

  async waitFor<T extends ServerEvent["type"]>(type: T, pred: (e: Extract<ServerEvent, { type: T }>) => boolean = () => true, timeoutMs = 5000): Promise<Extract<ServerEvent, { type: T }>> {
    const deadline = Date.now() + timeoutMs;
    for (;;) {
      const found = this.events.find((e) => e.type === type && pred(e as Extract<ServerEvent, { type: T }>));
      if (found) return found as Extract<ServerEvent, { type: T }>;
      if (this.closed && type !== "ended" && type !== "error") throw new Error(`socket closed waiting for ${type}`);
      const left = deadline - Date.now();
      if (left <= 0) throw new Error(`timeout waiting for ${type}; got ${this.events.map((e) => e.type).join(",")}`);
      await new Promise<void>((r) => {
        const t = setTimeout(r, left);
        this.waiters.push(() => {
          clearTimeout(t);
          r();
        });
      });
    }
  }

  of<T extends ServerEvent["type"]>(type: T): Array<Extract<ServerEvent, { type: T }>> {
    return this.events.filter((e) => e.type === type) as Array<Extract<ServerEvent, { type: T }>>;
  }
}

export async function api(base: string, method: string, path: string, token?: string, body?: unknown): Promise<{ status: number; json: any }> {
  const res = await fetch(base + path, {
    method,
    headers: { ...(token ? { authorization: `Bearer ${token}` } : {}), ...(body !== undefined ? { "content-type": "application/json" } : {}) },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  return { status: res.status, json: text ? JSON.parse(text) : null };
}

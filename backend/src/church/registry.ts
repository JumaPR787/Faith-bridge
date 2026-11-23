import type { FastifyBaseLogger } from "fastify";
import type { Db } from "../db.js";
import type { ServerEvent } from "../live/protocol.js";
import type { LiveSession, Sink } from "../live/session.js";

/** Eventos que un oyente puede recibir (nunca uso, cuota ni estado interno). */
const LISTENER_EVENTS = new Set<ServerEvent["type"]>(["interim", "segment", "translation", "provider_status", "ended", "joined", "waiting", "broadcast_interrupted", "error", "pong"]);

export interface ListenerConn {
  id: string;
  churchSessionId: string;
  rawSend: (data: string) => void;
  close: () => void;
  joinedAt: number;
  bytes: number;
  sink: Sink;
}

interface Broadcast {
  session: LiveSession;
  orgId: string;
  periodStart: string;
  peak: number;
}

/**
 * Transmisiones del modo iglesia en este proceso.
 * Una transcripción y una traducción por fuente se reparten a N oyentes:
 * las llamadas a la IA NO se multiplican por asistente.
 */
export class ChurchRegistry {
  private broadcasts = new Map<string, Broadcast>();
  private listeners = new Map<string, Set<ListenerConn>>();
  private periodByCsid = new Map<string, { orgId: string; periodStart: string }>();

  constructor(
    private readonly db: Db,
    private readonly log: FastifyBaseLogger,
  ) {}

  isBroadcasting(csid: string): boolean {
    return this.broadcasts.has(csid);
  }

  broadcastFor(csid: string): LiveSession | undefined {
    return this.broadcasts.get(csid)?.session;
  }

  listenerCount(csid: string): number {
    return this.listeners.get(csid)?.size ?? 0;
  }

  /** Crea la conexión de un oyente con un «sink» filtrado y medido. */
  makeConn(id: string, csid: string, rawSend: (d: string) => void, close: () => void): ListenerConn {
    const conn: ListenerConn = {
      id,
      churchSessionId: csid,
      rawSend,
      close,
      joinedAt: Date.now(),
      bytes: 0,
      sink: (e) => this.deliver(conn, e),
    };
    return conn;
  }

  private send(conn: ListenerConn, e: ServerEvent): void {
    const data = JSON.stringify(e);
    conn.bytes += Buffer.byteLength(data);
    conn.rawSend(data);
  }

  private deliver(conn: ListenerConn, e: ServerEvent): void {
    if (!LISTENER_EVENTS.has(e.type)) return;
    if (e.type === "ended" && e.reason !== "user_stopped") {
      // La transmisión se cortó (red, otro dispositivo…) pero la sesión de
      // iglesia sigue abierta: el oyente espera a que el organizador vuelva.
      this.send(conn, { type: "broadcast_interrupted" });
      return;
    }
    this.send(conn, e);
    if (e.type === "ended") setTimeout(() => conn.close(), 50).unref();
  }

  async addListener(conn: ListenerConn, lastSeq: number): Promise<void> {
    const set = this.listeners.get(conn.churchSessionId) ?? new Set<ListenerConn>();
    set.add(conn);
    this.listeners.set(conn.churchSessionId, set);
    await this.db
      .query("insert into public.church_session_listeners (church_session_id, listener_id) values ($1, $2)", [conn.churchSessionId, conn.id])
      .catch((e) => this.warn("listener_insert", e));
    const b = this.broadcasts.get(conn.churchSessionId);
    if (b) b.session.attach(conn.sink, lastSeq, "listener");
    else this.send(conn, { type: "waiting" });
  }

  async removeListener(conn: ListenerConn): Promise<void> {
    const set = this.listeners.get(conn.churchSessionId);
    if (!set?.delete(conn)) return;
    if (set.size === 0) this.listeners.delete(conn.churchSessionId);
    this.broadcasts.get(conn.churchSessionId)?.session.detach(conn.sink);
    const seconds = Math.round((Date.now() - conn.joinedAt) / 1000);
    await this.db
      .query(
        `update public.church_session_listeners set left_at = now(), bytes_sent = $3
         where church_session_id = $1 and listener_id = $2 and left_at is null`,
        [conn.churchSessionId, conn.id, conn.bytes],
      )
      .catch((e) => this.warn("listener_update", e));
    const period = this.periodByCsid.get(conn.churchSessionId);
    if (period) {
      await this.db
        .query(
          `insert into public.church_usage (org_id, period_start, listener_seconds, egress_bytes) values ($1,$2,$3,$4)
           on conflict (org_id, period_start) do update set
             listener_seconds = public.church_usage.listener_seconds + excluded.listener_seconds,
             egress_bytes = public.church_usage.egress_bytes + excluded.egress_bytes`,
          [period.orgId, period.periodStart, seconds, conn.bytes],
        )
        .catch((e) => this.warn("usage_listener", e));
    }
  }

  /** El organizador empezó (o reanudó) la transmisión. */
  async startBroadcast(csid: string, session: LiveSession, orgId: string, periodStart: string): Promise<void> {
    const b: Broadcast = { session, orgId, periodStart, peak: 0 };
    this.broadcasts.set(csid, b);
    this.periodByCsid.set(csid, { orgId, periodStart });
    session.onListenersChanged((count) => {
      if (count > b.peak) b.peak = count;
    });
    session.setOnEnded((s) => this.onBroadcastEnded(csid, s, b));
    await this.db.query("update public.church_sessions set status = 'live', live_session_id = $2 where id = $1", [csid, session.id]);
    for (const conn of this.listeners.get(csid) ?? []) session.attach(conn.sink, -1, "listener");
  }

  private async onBroadcastEnded(csid: string, s: LiveSession, b: Broadcast): Promise<void> {
    if (this.broadcasts.get(csid) === b) this.broadcasts.delete(csid);
    const finished = s.endReason === "user_stopped";
    try {
      await this.db.query(
        `insert into public.church_usage (org_id, period_start, broadcast_seconds, peak_listeners) values ($1,$2,$3,$4)
         on conflict (org_id, period_start) do update set
           broadcast_seconds = public.church_usage.broadcast_seconds + excluded.broadcast_seconds,
           peak_listeners = greatest(public.church_usage.peak_listeners, excluded.peak_listeners)`,
        [b.orgId, b.periodStart, s.sessionSeconds, b.peak],
      );
      if (finished) {
        await this.db.query("update public.church_sessions set status = 'ended', ended_at = now() where id = $1", [csid]);
      } else if (!this.broadcasts.has(csid)) {
        await this.db.query("update public.church_sessions set status = 'scheduled' where id = $1 and status = 'live'", [csid]);
      }
    } catch (e) {
      this.warn("broadcast_end", e);
    }
  }

  /** Cierre explícito de la sesión de iglesia sin transmisión activa. */
  endWithoutBroadcast(csid: string): void {
    for (const conn of this.listeners.get(csid) ?? []) {
      this.send(conn, { type: "ended", reason: "user_stopped", transcriptId: null, sessionSeconds: 0 });
      setTimeout(() => conn.close(), 50).unref();
    }
  }

  private warn(where: string, e: unknown): void {
    this.log.warn({ where, err: e instanceof Error ? e.message.slice(0, 120) : "unknown" }, "church registry error");
  }
}

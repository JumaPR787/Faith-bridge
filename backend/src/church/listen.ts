import type { WebSocket } from "ws";
import { z } from "zod";
import type { AppContext } from "../context.js";
import { getConfigValue } from "../db.js";
import type { ServerEvent } from "../live/protocol.js";
import type { ListenerConn } from "./registry.js";
import { verifyListenerToken } from "./tokens.js";

const ListenMessage = z.object({
  type: z.literal("listen"),
  token: z.string().min(10).max(4096),
  lastSeq: z.number().int().min(-1).optional(),
});

/**
 * WebSocket de SOLO LECTURA para asistentes del modo iglesia.
 * No acepta audio: los mensajes binarios se ignoran. El micrófono del
 * asistente nunca se usa.
 */
export function handleListenSocket(ctx: AppContext, socket: WebSocket): void {
  let conn: ListenerConn | null = null;
  let starting = false;
  const send = (e: ServerEvent) => {
    if (socket.readyState === socket.OPEN) socket.send(JSON.stringify(e));
  };
  const fail = (code: Extract<ServerEvent, { type: "error" }>["code"], closeCode = 4000) => {
    send({ type: "error", code, fatal: true });
    socket.close(closeCode, code);
  };
  const timer = setTimeout(() => {
    if (!conn) fail("bad_request", 4001);
  }, 10_000);

  socket.on("message", (data, isBinary) => {
    if (isBinary) return; // los oyentes no envían audio
    let json: unknown;
    try {
      json = JSON.parse(data.toString());
    } catch {
      return;
    }
    if (conn) {
      if ((json as { type?: string }).type === "ping") send({ type: "pong" });
      return;
    }
    if (starting) return;
    starting = true;
    void start(json).finally(() => (starting = false));
  });

  socket.on("close", () => {
    clearTimeout(timer);
    if (conn) void ctx.church.removeListener(conn);
  });

  async function start(json: unknown): Promise<void> {
    const m = ListenMessage.safeParse(json);
    if (!m.success) return fail("bad_request");
    if (!(await getConfigValue(ctx.db, "church_mode_enabled", false))) return fail("church_mode_disabled", 4503);
    const claims = ctx.cfg.LISTENER_TOKEN_SECRET ? await verifyListenerToken(ctx.cfg.LISTENER_TOKEN_SECRET, m.data.token) : null;
    if (!claims) return fail("unauthorized", 4401);
    clearTimeout(timer);
    const r = await ctx.db.query<{ status: string; max_listeners: number; source_lang: string; target_lang: string | null; name: string }>(
      `select cs.status, cs.max_listeners, cs.source_lang, cs.target_lang, o.name
       from public.church_sessions cs join public.organizations o on o.id = cs.org_id
       where cs.id = $1 and cs.join_expires_at > now()`,
      [claims.churchSessionId],
    );
    const s = r.rows[0];
    if (!s || s.status === "ended") return fail("session_ended", 4410);
    if (ctx.church.listenerCount(claims.churchSessionId) >= s.max_listeners) return fail("session_full", 4429);
    conn = ctx.church.makeConn(claims.listenerId, claims.churchSessionId, (d) => {
      if (socket.readyState === socket.OPEN) socket.send(d);
    }, () => socket.close(1000, "ended"));
    conn.sink({
      type: "joined",
      churchSessionId: claims.churchSessionId,
      orgName: s.name,
      sourceLang: s.source_lang,
      targetLang: s.target_lang,
      broadcasting: ctx.church.isBroadcasting(claims.churchSessionId),
    });
    await ctx.church.addListener(conn, m.data.lastSeq ?? -1);
  }
}

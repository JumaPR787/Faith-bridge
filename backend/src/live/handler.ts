import type { WebSocket } from "ws";
import type { AppContext } from "../context.js";
import { AuthError } from "../auth.js";
import { loadGlossary } from "../routes/glossary.js";
import { ControlMessage, StartMessage, type ErrorCode, type ServerEvent } from "./protocol.js";
import { LiveSession, type Sink } from "./session.js";

const START_TIMEOUT_MS = 10_000;

/**
 * Protocolo:
 *  1. El cliente abre el WebSocket y envía {type:"start", token, ...} como
 *     primer mensaje (el token NO va en la URL para que no quede en registros).
 *  2. El servidor responde "ready" o "error".
 *  3. El cliente envía audio PCM16 16 kHz mono como mensajes binarios y
 *     controles JSON (pause/resume/stop/ping).
 */
export function handleLiveSocket(ctx: AppContext, socket: WebSocket): void {
  let session: LiveSession | null = null;
  let sink: Sink | null = null;
  let starting = false;
  const isSimulated = () => ctx.stt.name === "fake" || ctx.translator.name === "fake";

  const send = (e: ServerEvent) => {
    if (socket.readyState === socket.OPEN) socket.send(JSON.stringify(e));
  };
  const fail = (code: ErrorCode, closeCode = 4000) => {
    send({ type: "error", code, fatal: true });
    socket.close(closeCode, code);
  };

  const startTimer = setTimeout(() => {
    if (!session) fail("bad_request", 4001);
  }, START_TIMEOUT_MS);

  socket.on("message", (data, isBinary) => {
    if (isBinary) {
      if (session && Buffer.isBuffer(data)) session.audio(data);
      return;
    }
    let json: unknown;
    try {
      json = JSON.parse(data.toString());
    } catch {
      return fail("bad_request");
    }
    if (!session) {
      if (starting) return;
      starting = true;
      void onStart(json)
        .catch((err) => {
          ctx.log.error({ err: err instanceof Error ? err.message.slice(0, 160) : "unknown" }, "live start failed");
          fail(err instanceof AuthError ? "unauthorized" : "internal", err instanceof AuthError ? 4401 : 4500);
        })
        .finally(() => {
          starting = false;
        });
      return;
    }
    const msg = ControlMessage.safeParse(json);
    if (!msg.success) return;
    switch (msg.data.type) {
      case "pause":
        session.pause();
        break;
      case "resume":
        void session.resume();
        break;
      case "stop":
        void session.end("user_stopped").then(() => socket.close(1000, "ended"));
        break;
      case "ping":
        send({ type: "pong" });
        break;
    }
  });

  socket.on("close", () => {
    clearTimeout(startTimer);
    if (session && sink) session.detach(sink);
  });

  async function onStart(json: unknown): Promise<void> {
    const parsed = StartMessage.safeParse(json);
    if (!parsed.success) return fail("bad_request");
    const m = parsed.data;
    const user = await ctx.verifyToken(m.token);
    clearTimeout(startTimer);

    // Reanudación de una sesión existente tras una caída de red.
    if (m.resumeSessionId) {
      const existing = ctx.registry.get(m.resumeSessionId);
      if (!existing || existing.userId !== user.id || existing.state === "ending" || existing.state === "ended") {
        return fail("session_not_found", 4404);
      }
      session = existing;
      sink = send;
      const q = await ctx.quota.getStatus(ctx.db, user.id);
      send({
        type: "ready",
        sessionId: existing.id,
        resumed: true,
        quota: { quotaSeconds: q.quotaSeconds, usedSeconds: q.usedSeconds, remainingSeconds: existing.remainingSeconds, periodEnd: q.periodEnd, isTrial: q.isTrial },
        maxSessionSeconds: ctx.cfg.MAX_SESSION_SECONDS,
        translation: existing.hasTranslation,
        simulated: isSimulated(),
      });
      existing.attach(sink, m.lastSeq ?? -1);
      return;
    }

    // Nueva sesión: controles operativos, beneficio y cuota (todo en servidor).
    const denial = await ctx.guard.checkLiveStart(user.id);
    if (denial) return fail(denial, 4429);
    const q = await ctx.quota.getStatus(ctx.db, user.id);
    if (!q.hasAccess) return fail("no_entitlement", 4402);
    if (q.trialAlreadyUsed) return fail("trial_already_used", 4402);
    if (q.remainingSeconds <= 0) return fail("quota_exhausted", 4402);

    // Una sola sesión personal activa: la anterior (otro dispositivo) se cierra.
    const previous = ctx.registry.activeForUser(user.id);
    if (previous) await previous.end("superseded");
    await ctx.db.query(
      "update public.live_sessions set status = 'ended', end_reason = 'superseded', ended_at = now() where user_id = $1 and status = 'active' and mode = 'personal'",
      [user.id],
    );

    const ins = await ctx.db.query<{ id: string }>(
      `insert into public.live_sessions (user_id, source_lang, target_lang, save_transcript)
       values ($1,$2,$3,$4) returning id`,
      [user.id, m.sourceLang, m.targetLang, m.saveTranscript],
    );
    const sessionId = ins.rows[0]!.id;
    let transcriptId: string | null = null;
    if (m.saveTranscript) {
      const t = await ctx.db.query<{ id: string }>(
        `insert into public.transcripts (user_id, session_id, title, source_lang, target_lang, expires_at)
         select $1, $2, to_char(now() at time zone 'utc', 'YYYY-MM-DD HH24:MI') || ' UTC', $3, $4,
                now() + make_interval(days => coalesce((select transcript_retention_days from public.profiles where user_id = $1), 365))
         returning id`,
        [user.id, sessionId, m.sourceLang, m.targetLang],
      );
      transcriptId = t.rows[0]!.id;
    }
    // El glosario sirve para traducir y, en el idioma hablado, como keyterms del STT.
    const glossary = await loadGlossary(ctx.db, user.id, m.sourceLang, m.targetLang ?? (m.sourceLang === "en" ? "es" : "en"));

    const s = new LiveSession(
      { db: ctx.db, cfg: ctx.cfg, stt: ctx.stt, translator: m.targetLang ? ctx.translator : null, quota: ctx.quota, guard: ctx.guard, log: ctx.log },
      {
        sessionId,
        userId: user.id,
        source: m.sourceLang,
        target: m.targetLang,
        transcriptId,
        glossary,
        periodStart: q.periodStart!,
        remainingSeconds: q.remainingSeconds,
        flushIntervalMs: ctx.liveFlushIntervalMs,
        sttRetryDelaysMs: ctx.sttRetryDelaysMs,
      },
    );
    try {
      await s.start();
    } catch (err) {
      await ctx.db.query("update public.live_sessions set status='ended', end_reason='stt_unavailable', ended_at=now() where id=$1", [sessionId]);
      if (transcriptId) await ctx.db.query("delete from public.transcripts where id=$1", [transcriptId]);
      ctx.log.warn({ err: err instanceof Error ? err.message.slice(0, 120) : "unknown" }, "stt open failed");
      return fail("stt_unavailable", 4503);
    }
    ctx.registry.add(s);
    session = s;
    sink = send;
    send({
      type: "ready",
      sessionId,
      resumed: false,
      quota: { quotaSeconds: q.quotaSeconds, usedSeconds: q.usedSeconds, remainingSeconds: q.remainingSeconds, periodEnd: q.periodEnd, isTrial: q.isTrial },
      maxSessionSeconds: ctx.cfg.MAX_SESSION_SECONDS,
      translation: s.hasTranslation,
      simulated: isSimulated(),
    });
    s.attach(sink, -1);
  }
}

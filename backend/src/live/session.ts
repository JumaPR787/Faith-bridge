import type { FastifyBaseLogger } from "fastify";
import type { Config } from "../config.js";
import type { Db } from "../db.js";
import type { OpsGuard } from "../ops/guard.js";
import type { QuotaService } from "../quota/quota.js";
import type { Lang, SttProvider, SttStream } from "../providers/stt/types.js";
import type { GlossaryTerm } from "../providers/translation/glossary.js";
import { keytermsFor } from "../providers/translation/glossary.js";
import type { ContextPair } from "../providers/translation/prompt.js";
import { TranslationFailed, type Translator } from "../providers/translation/types.js";
import { AUDIO_BYTES_PER_SECOND, AUDIO_SAMPLE_RATE, MAX_AUDIO_FRAME_BYTES, type EndReason, type ServerEvent } from "./protocol.js";
import { Segmenter, type SegmentEvent } from "./segmenter.js";

export type Sink = (e: ServerEvent) => void;

export interface LiveSessionDeps {
  db: Db;
  cfg: Config;
  stt: SttProvider;
  translator: Translator | null;
  quota: QuotaService;
  guard: OpsGuard;
  log: FastifyBaseLogger;
}

export interface LiveSessionParams {
  sessionId: string;
  userId: string;
  source: Lang;
  target: Lang | null;
  transcriptId: string | null;
  glossary: GlossaryTerm[];
  periodStart: string;
  remainingSeconds: number;
  /** Tiempos (ms) — inyectables en pruebas. */
  flushIntervalMs?: number;
  sttRetryDelaysMs?: number[];
}

interface StoredSegment {
  seg: SegmentEvent;
  translation: { status: "ok" | "failed"; text: string | null } | null;
}

const RING_SIZE = 500;
const TRANSLATION_CONCURRENCY = 2;
const END_TRANSLATION_WAIT_MS = 8000;

/**
 * Una sesión en vivo: recibe audio, lo envía al STT, segmenta, traduce cada
 * segmento confirmado UNA sola vez y distribuye los eventos a los suscriptores.
 *
 * Diseñada para el modo iglesia: hoy hay un suscriptor (el propio teléfono),
 * pero `subscribers` admite varios oyentes sin repetir llamadas a la IA.
 */
export class LiveSession {
  readonly id: string;
  readonly userId: string;
  state: "active" | "paused" | "ending" | "ended" = "active";

  private subscribers = new Set<Sink>();
  /** Transmisor(es): el teléfono que envía el audio. */
  private primaries = new Set<Sink>();
  /** Oyentes del modo iglesia: solo reciben texto. */
  private listeners = new Set<Sink>();
  endReason: EndReason | null = null;
  private stt: SttStream | null = null;
  private segmenter: Segmenter;
  private segments = new Map<number, StoredSegment>();
  private totalBytes = 0;
  private flushedSeconds = 0;
  private readonly allowedSeconds: number;
  private warned = false;
  private sttAttempts = 0;
  private reconnecting = false;
  private flushTimer: NodeJS.Timeout | null = null;
  private keepAliveTimer: NodeJS.Timeout | null = null;
  private pauseIdleTimer: NodeJS.Timeout | null = null;
  private graceTimer: NodeJS.Timeout | null = null;
  private activeTranslations = 0;
  private translationQueue: Array<() => void> = [];
  private pending = new Set<Promise<void>>();
  private abort = new AbortController();
  private endHooks: Array<(s: LiveSession) => void | Promise<void>> = [];
  private listenerHooks: Array<(count: number) => void> = [];
  private endPromise: Promise<void> | null = null;

  constructor(
    private readonly deps: LiveSessionDeps,
    private readonly p: LiveSessionParams,
  ) {
    this.id = p.sessionId;
    this.userId = p.userId;
    this.allowedSeconds = Math.min(p.remainingSeconds, deps.cfg.MAX_SESSION_SECONDS);
    this.segmenter = new Segmenter(
      (e) => this.broadcast({ type: "interim", seq: e.seq, text: e.text }),
      (e) => this.onSegment(e),
    );
  }

  get sessionSeconds(): number {
    return Math.floor(this.totalBytes / AUDIO_BYTES_PER_SECOND);
  }

  get remainingSeconds(): number {
    return Math.max(0, this.p.remainingSeconds - this.sessionSeconds);
  }

  get transcriptId(): string | null {
    return this.p.transcriptId;
  }

  get hasTranslation(): boolean {
    return this.p.target !== null && this.deps.translator !== null;
  }

  /** Registra una función que se ejecuta al terminar la sesión (admite varias). */
  setOnEnded(fn: (s: LiveSession) => void | Promise<void>): void {
    this.endHooks.push(fn);
  }

  onListenersChanged(fn: (count: number) => void): void {
    this.listenerHooks.push(fn);
  }

  get listenerCount(): number {
    return this.listeners.size;
  }

  private notifyListeners(): void {
    const count = this.listeners.size;
    for (const p of this.primaries) {
      try {
        p({ type: "listeners", count });
      } catch {
        /* ignorar */
      }
    }
    for (const h of this.listenerHooks) h(count);
  }

  async start(): Promise<void> {
    await this.openStt();
    this.flushTimer = setInterval(() => void this.flushUsage().catch((e) => this.logErr("flush", e)), this.p.flushIntervalMs ?? 10_000);
  }

  // ───────────── Suscriptores ─────────────

  attach(sink: Sink, lastSeq = -1, role: "primary" | "listener" = "primary"): void {
    if (role === "primary") {
      if (this.graceTimer) {
        clearTimeout(this.graceTimer);
        this.graceTimer = null;
      }
      this.primaries.add(sink);
    } else {
      this.listeners.add(sink);
    }
    this.subscribers.add(sink);
    // Reenvía lo que el cliente no recibió (reconexión). Orden por seq.
    const missed = [...this.segments.values()].filter((s) => s.seg.seq > lastSeq).sort((a, b) => a.seg.seq - b.seg.seq);
    for (const s of missed) {
      sink({ type: "segment", ...s.seg });
      if (s.translation) sink({ type: "translation", seq: s.seg.seq, ...s.translation });
    }
    if (role === "listener") this.notifyListeners();
    else sink({ type: "listeners", count: this.listeners.size });
  }

  detach(sink: Sink): void {
    this.subscribers.delete(sink);
    if (this.listeners.delete(sink)) {
      if (!this.closing()) this.notifyListeners();
      return;
    }
    this.primaries.delete(sink);
    // Sin transmisor (aunque haya oyentes): periodo de gracia y luego fin.
    if (this.primaries.size === 0 && !this.closing()) {
      this.graceTimer = setTimeout(() => void this.end("client_gone"), this.deps.cfg.RESUME_GRACE_SECONDS * 1000);
      this.graceTimer.unref();
    }
  }

  private broadcast(e: ServerEvent): void {
    for (const s of this.subscribers) {
      try {
        s(e);
      } catch {
        /* un suscriptor roto no debe afectar a los demás */
      }
    }
  }

  // ───────────── Audio ─────────────

  audio(chunk: Buffer): void {
    if (this.state !== "active") return;
    if (chunk.length === 0 || chunk.length > MAX_AUDIO_FRAME_BYTES) return;
    this.totalBytes += chunk.length;
    if (this.sessionSeconds >= this.allowedSeconds) {
      const reason: EndReason = this.allowedSeconds < this.p.remainingSeconds ? "max_duration" : "quota_exhausted";
      void this.end(reason);
      return;
    }
    if (!this.warned && this.remainingSeconds <= 300 && this.p.remainingSeconds > 300) {
      this.warned = true;
      this.broadcast({ type: "quota_warning", remainingSeconds: this.remainingSeconds });
    }
    // Durante una reconexión del proveedor el audio se descarta (no se acumula).
    if (this.stt && !this.reconnecting) this.stt.sendAudio(chunk);
  }

  pause(): void {
    if (this.state !== "active") return;
    this.state = "paused";
    this.broadcast({ type: "provider_status", status: "paused" });
    this.keepAliveTimer = setInterval(() => this.stt?.keepAlive(), 5000);
    this.keepAliveTimer.unref();
    this.pauseIdleTimer = setTimeout(() => {
      // Pausa larga: cerrar la conexión del proveedor para no mantener recursos.
      this.clearPauseTimers();
      const s = this.stt;
      this.stt = null;
      void s?.finish();
    }, this.deps.cfg.PAUSE_IDLE_CLOSE_SECONDS * 1000);
    this.pauseIdleTimer.unref();
  }

  async resume(): Promise<void> {
    if (this.state !== "paused") return;
    this.clearPauseTimers();
    this.state = "active";
    if (!this.stt) await this.openStt();
    else this.broadcast({ type: "provider_status", status: "connected" });
  }

  private clearPauseTimers(): void {
    if (this.keepAliveTimer) clearInterval(this.keepAliveTimer);
    if (this.pauseIdleTimer) clearTimeout(this.pauseIdleTimer);
    this.keepAliveTimer = null;
    this.pauseIdleTimer = null;
  }

  // ───────────── STT ─────────────

  private async openStt(): Promise<void> {
    this.segmenter.setTimeOffset(Math.round((this.totalBytes / AUDIO_BYTES_PER_SECOND) * 1000));
    let stream: SttStream | null = null;
    stream = await this.deps.stt.open(
      {
        language: this.p.source,
        sampleRate: AUDIO_SAMPLE_RATE,
        keyterms: keytermsFor(this.p.source, this.p.glossary),
      },
      {
        onResult: (r) => {
          this.sttAttempts = 0;
          this.segmenter.onResult(r);
        },
        onUtteranceEnd: () => this.segmenter.onUtteranceEnd(),
        onError: (err) => {
          this.logErr("stt", err);
          if (this.stt === stream) void this.reconnectStt();
        },
        onClose: () => {
          if (this.stt === stream && (this.state === "active" || this.state === "paused")) void this.reconnectStt();
        },
      },
    );
    this.stt = stream;
    this.broadcast({ type: "provider_status", status: "connected" });
  }

  private async reconnectStt(): Promise<void> {
    if (this.reconnecting || this.closing()) return;
    this.reconnecting = true;
    this.segmenter.flush();
    this.stt = null;
    this.broadcast({ type: "provider_status", status: "reconnecting" });
    const delays = this.p.sttRetryDelaysMs ?? [500, 1500, 4000];
    while (this.sttAttempts < delays.length) {
      const delay = delays[this.sttAttempts++] ?? 1000;
      await new Promise((r) => setTimeout(r, delay));
      if (this.closing()) break;
      try {
        await this.openStt();
        this.reconnecting = false;
        return;
      } catch (e) {
        this.logErr("stt_reconnect", e);
      }
    }
    this.reconnecting = false;
    if (!this.closing()) {
      this.broadcast({ type: "error", code: "stt_unavailable", fatal: true });
      await this.end("stt_unavailable");
    }
  }

  private closing(): boolean {
    return this.state === "ending" || this.state === "ended";
  }

  // ───────────── Segmentos y traducción ─────────────

  private onSegment(seg: SegmentEvent): void {
    this.segments.set(seg.seq, { seg, translation: null });
    if (this.segments.size > RING_SIZE) {
      const oldest = Math.min(...this.segments.keys());
      this.segments.delete(oldest);
    }
    this.broadcast({ type: "segment", ...seg });
    this.track(this.persistSegment(seg));
    if (this.hasTranslation) this.track(this.enqueueTranslation(seg));
  }

  private track(p: Promise<void>): void {
    this.pending.add(p);
    void p.finally(() => this.pending.delete(p));
  }

  private async enqueueTranslation(seg: SegmentEvent): Promise<void> {
    if (this.activeTranslations >= TRANSLATION_CONCURRENCY) {
      await new Promise<void>((r) => this.translationQueue.push(r));
    }
    this.activeTranslations++;
    try {
      await this.translate(seg);
    } finally {
      this.activeTranslations--;
      this.translationQueue.shift()?.();
    }
  }

  private recentContext(beforeSeq: number): ContextPair[] {
    const n = this.deps.cfg.TRANSLATION_CONTEXT_SEGMENTS;
    const out: ContextPair[] = [];
    for (let s = beforeSeq - 1; s >= 0 && out.length < n; s--) {
      const st = this.segments.get(s);
      if (!st) break;
      if (st.translation?.status === "ok" && st.translation.text) out.unshift({ source: st.seg.text, target: st.translation.text });
    }
    return out;
  }

  private async translate(seg: SegmentEvent): Promise<void> {
    const translator = this.deps.translator!;
    const target = this.p.target!;
    let result: { status: "ok" | "failed"; text: string | null };
    if (seg.text.replace(/\[\?\]/g, "").trim() === "") {
      result = { status: "ok", text: seg.text };
    } else {
      result = { status: "failed", text: null };
      for (let attempt = 0; attempt < 2; attempt++) {
        if (this.abort.signal.aborted) break;
        try {
          const r = await translator.translate({
            text: seg.text,
            source: this.p.source,
            target,
            context: this.recentContext(seg.seq),
            glossary: this.p.glossary,
            signal: this.abort.signal,
          });
          result = { status: "ok", text: r.text };
          await this.deps.guard
            .addSpend("translation", r.inputTokens + r.outputTokens, this.deps.guard.translationCostUsd(r.inputTokens, r.outputTokens))
            .catch((e) => this.logErr("spend", e));
          break;
        } catch (e) {
          const reason = e instanceof TranslationFailed ? e.reason : "provider_error";
          // Un rechazo o una salida inválida no se reintenta: se marca como no disponible.
          if (reason === "refused" || reason === "invalid_output" || reason === "cancelled") break;
        }
      }
    }
    const st = this.segments.get(seg.seq);
    if (st) st.translation = result;
    this.broadcast({ type: "translation", seq: seg.seq, ...result });
    await this.persistTranslation(seg.seq, result);
  }

  private async persistSegment(seg: SegmentEvent): Promise<void> {
    if (!this.p.transcriptId) return;
    await this.deps.db
      .query(
        `insert into public.transcript_segments (transcript_id, seq, start_ms, end_ms, source_text)
         values ($1,$2,$3,$4,$5) on conflict (transcript_id, seq) do nothing`,
        [this.p.transcriptId, seg.seq, seg.startMs, seg.endMs, seg.text],
      )
      .catch((e) => this.logErr("persist_segment", e));
  }

  private async persistTranslation(seq: number, r: { status: "ok" | "failed"; text: string | null }): Promise<void> {
    if (!this.p.transcriptId) return;
    await this.deps.db
      .query(
        "update public.transcript_segments set translated_text = $3, translation_status = $4 where transcript_id = $1 and seq = $2",
        [this.p.transcriptId, seq, r.text, r.status],
      )
      .catch((e) => this.logErr("persist_translation", e));
  }

  // ───────────── Medición ─────────────

  private async flushUsage(): Promise<void> {
    const total = this.sessionSeconds;
    const delta = total - this.flushedSeconds;
    this.flushedSeconds = total;
    if (delta > 0) {
      await this.deps.quota.record(this.deps.db, this.userId, this.p.periodStart, delta, "live_audio", this.id);
      await this.deps.guard.addSpend("stt", delta, this.deps.guard.sttCostUsd(delta));
    }
    await this.deps.db.query(
      "update public.live_sessions set last_heartbeat = now(), audio_seconds = $2 where id = $1",
      [this.id, total],
    );
    if (this.state !== "ended") {
      this.broadcast({ type: "usage", sessionSeconds: total, remainingSeconds: this.remainingSeconds });
    }
  }

  // ───────────── Fin ─────────────

  end(reason: EndReason): Promise<void> {
    if (this.endPromise) return this.endPromise;
    this.endPromise = this.doEnd(reason);
    return this.endPromise;
  }

  private async doEnd(reason: EndReason): Promise<void> {
    this.state = "ending";
    this.endReason = reason;
    if (this.flushTimer) clearInterval(this.flushTimer);
    if (this.graceTimer) clearTimeout(this.graceTimer);
    this.clearPauseTimers();
    const s = this.stt;
    this.stt = null;
    await s?.finish().catch(() => undefined);
    this.segmenter.flush();
    // Espera traducciones pendientes un tiempo acotado; luego las cancela.
    const waitAll = Promise.allSettled([...this.pending]);
    const timeout = new Promise((r) => setTimeout(r, END_TRANSLATION_WAIT_MS).unref());
    await Promise.race([waitAll, timeout]);
    this.abort.abort();
    await Promise.allSettled([...this.pending]);
    try {
      await this.flushUsage();
      await this.deps.db.query(
        "update public.live_sessions set status = 'ended', end_reason = $2, ended_at = now(), audio_seconds = $3 where id = $1",
        [this.id, reason, this.sessionSeconds],
      );
      if (this.p.transcriptId) {
        await this.deps.db.query(
          `delete from public.transcripts t where t.id = $1
           and not exists (select 1 from public.transcript_segments s where s.transcript_id = t.id)`,
          [this.p.transcriptId],
        );
      }
    } catch (e) {
      this.logErr("end", e);
    }
    const stillExists = this.p.transcriptId
      ? ((await this.deps.db.query("select 1 from public.transcripts where id = $1", [this.p.transcriptId]).catch(() => ({ rowCount: 0 }))).rowCount ?? 0) > 0
      : false;
    // Los ajustes de cierre (registro, estado de la sesión de iglesia, uso)
    // terminan ANTES de avisar a los clientes, para que no haya estados intermedios.
    for (const h of this.endHooks) {
      try {
        await h(this);
      } catch (e) {
        this.logErr("end_hook", e);
      }
    }
    this.state = "ended";
    this.broadcast({ type: "ended", reason, transcriptId: stillExists ? this.p.transcriptId : null, sessionSeconds: this.sessionSeconds });
    this.subscribers.clear();
    this.primaries.clear();
    this.listeners.clear();
    this.segments.clear(); // no se conserva texto en memoria al terminar

  }

  private logErr(where: string, e: unknown): void {
    // Nunca registrar audio ni texto transcrito: solo el tipo de error.
    const msg = e instanceof Error ? e.message.slice(0, 120) : "unknown";
    this.deps.log.warn({ sessionId: this.id, where, err: msg }, "live session error");
  }
}

/** Registro en memoria de sesiones activas en este proceso. */
export class SessionRegistry {
  private byId = new Map<string, LiveSession>();
  private byUser = new Map<string, string>();

  /** trackUser=false para transmisiones de iglesia (no reemplazan la sesión personal). */
  add(s: LiveSession, opts: { trackUser?: boolean } = {}): void {
    this.byId.set(s.id, s);
    if (opts.trackUser !== false) this.byUser.set(s.userId, s.id);
    s.setOnEnded((x) => this.remove(x));
  }

  get(id: string): LiveSession | undefined {
    return this.byId.get(id);
  }

  activeForUser(userId: string): LiveSession | undefined {
    const id = this.byUser.get(userId);
    return id ? this.byId.get(id) : undefined;
  }

  remove(s: LiveSession): void {
    this.byId.delete(s.id);
    if (this.byUser.get(s.userId) === s.id) this.byUser.delete(s.userId);
  }

  all(): LiveSession[] {
    return [...this.byId.values()];
  }
}

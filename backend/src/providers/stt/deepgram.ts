import WebSocket from "ws";
import type { SttProvider, SttStream, SttStreamHandlers, SttStreamOptions, SttResult } from "./types.js";

/**
 * Adaptador de Deepgram (streaming por WebSocket).
 * Documentación: https://developers.deepgram.com/docs/live-streaming-audio
 *
 * - El audio llega del teléfono al backend y el backend lo reenvía: la clave
 *   de Deepgram nunca sale del servidor.
 * - mip_opt_out=true: excluye las solicitudes del programa de mejora de
 *   modelos de Deepgram (no retención para entrenamiento). Verificar en el
 *   contrato vigente antes de publicar (ver docs/privacidad-proveedores.md).
 */
export class DeepgramProvider implements SttProvider {
  readonly name = "deepgram";
  constructor(
    private readonly apiKey: string,
    private readonly model: string,
    private readonly keytermsEnabled: boolean,
    private readonly baseUrl = "wss://api.deepgram.com/v1/listen",
  ) {}

  buildUrl(opts: SttStreamOptions): string {
    const p = new URLSearchParams({
      model: this.model,
      language: opts.language,
      encoding: "linear16",
      sample_rate: String(opts.sampleRate),
      channels: "1",
      interim_results: "true",
      smart_format: "true",
      punctuate: "true",
      endpointing: "400",
      utterance_end_ms: "1200",
      vad_events: "false",
      mip_opt_out: "true",
    });
    if (this.keytermsEnabled) {
      for (const k of opts.keyterms.slice(0, 50)) p.append("keyterm", k);
    }
    return `${this.baseUrl}?${p.toString()}`;
  }

  open(opts: SttStreamOptions, h: SttStreamHandlers): Promise<SttStream> {
    return new Promise((resolve, reject) => {
      const ws = new WebSocket(this.buildUrl(opts), {
        headers: { Authorization: `Token ${this.apiKey}` },
        handshakeTimeout: 10_000,
      });
      let opened = false;
      let finishResolve: (() => void) | null = null;

      ws.on("open", () => {
        opened = true;
        resolve({
          sendAudio: (chunk) => {
            if (ws.readyState === WebSocket.OPEN) ws.send(chunk);
          },
          keepAlive: () => {
            if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify({ type: "KeepAlive" }));
          },
          finish: () =>
            new Promise<void>((res) => {
              if (ws.readyState !== WebSocket.OPEN) return res();
              finishResolve = res;
              ws.send(JSON.stringify({ type: "CloseStream" }));
              setTimeout(() => {
                ws.terminate();
                res();
              }, 5000).unref();
            }),
          abort: () => ws.terminate(),
        });
      });

      ws.on("message", (data, isBinary) => {
        if (isBinary) return;
        let msg: DeepgramMessage;
        try {
          msg = JSON.parse(data.toString()) as DeepgramMessage;
        } catch {
          return;
        }
        if (msg.type === "Results") {
          const r = parseDeepgramResult(msg);
          if (r) h.onResult(r);
        } else if (msg.type === "UtteranceEnd") {
          h.onUtteranceEnd();
        }
      });

      ws.on("error", (err) => {
        if (!opened) reject(err);
        else h.onError(err);
      });
      ws.on("unexpected-response", (_req, res) => {
        const err = new Error(`deepgram_http_${res.statusCode}`);
        if (!opened) reject(err);
        else h.onError(err);
      });
      ws.on("close", () => {
        finishResolve?.();
        if (opened) h.onClose();
      });
    });
  }
}

interface DeepgramWord {
  word: string;
  punctuated_word?: string;
  start: number;
  end: number;
  confidence: number;
}
interface DeepgramMessage {
  type: string;
  is_final?: boolean;
  speech_final?: boolean;
  start?: number;
  duration?: number;
  channel?: { alternatives?: Array<{ transcript: string; confidence: number; words?: DeepgramWord[] }> };
}

export function parseDeepgramResult(msg: DeepgramMessage): SttResult | null {
  const alt = msg.channel?.alternatives?.[0];
  if (!alt) return null;
  const start = msg.start ?? 0;
  const dur = msg.duration ?? 0;
  return {
    isFinal: msg.is_final === true,
    endOfUtterance: msg.speech_final === true,
    text: alt.transcript ?? "",
    startMs: Math.round(start * 1000),
    endMs: Math.round((start + dur) * 1000),
    words: (alt.words ?? []).map((w) => ({
      word: w.punctuated_word ?? w.word,
      startMs: Math.round(w.start * 1000),
      endMs: Math.round(w.end * 1000),
      confidence: w.confidence,
    })),
  };
}

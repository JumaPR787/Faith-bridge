import type { SttResult } from "../providers/stt/types.js";
import { UNCLEAR_MARK } from "../providers/translation/prompt.js";

export interface InterimEvent {
  seq: number;
  text: string;
}

export interface SegmentEvent {
  seq: number;
  startMs: number;
  endMs: number;
  text: string;
  /** Cantidad de palabras marcadas como no entendidas. */
  unclearCount: number;
}

export interface SegmenterOptions {
  /** Corta un segmento si supera esta duración aunque no haya pausa. */
  maxSegmentMs: number;
  /** Corta en fin de oración si el segmento ya tiene al menos estas palabras. */
  minWordsForSentenceCut: number;
  /** Palabras con confianza menor se reemplazan por [?] (no se inventan). */
  unclearConfidence: number;
  /** Desplazamiento de tiempo (ms) para reconexiones del proveedor. */
  timeOffsetMs?: number;
}

export const DEFAULT_SEGMENTER_OPTIONS: SegmenterOptions = {
  maxSegmentMs: 12_000,
  minWordsForSentenceCut: 6,
  unclearConfidence: 0.35,
};

/**
 * Convierte resultados del STT en:
 *  - eventos PROVISIONALES (interim) que siempre llevan el seq del próximo segmento;
 *  - SEGMENTOS CONFIRMADOS con seq creciente, inicio/fin y texto estable.
 * Un seq confirmado nunca se vuelve a emitir, lo que evita duplicados.
 */
export class Segmenter {
  private nextSeq: number;
  private pieces: string[] = [];
  private wordCount = 0;
  private unclear = 0;
  private startMs: number | null = null;
  private endMs = 0;
  private offsetMs: number;

  constructor(
    private readonly emitInterim: (e: InterimEvent) => void,
    private readonly emitSegment: (e: SegmentEvent) => void,
    private readonly opts: SegmenterOptions = DEFAULT_SEGMENTER_OPTIONS,
    firstSeq = 0,
  ) {
    this.nextSeq = firstSeq;
    this.offsetMs = opts.timeOffsetMs ?? 0;
  }

  get currentSeq(): number {
    return this.nextSeq;
  }

  /** Tras reconectar el proveedor, sus tiempos reinician en 0. */
  setTimeOffset(ms: number): void {
    this.offsetMs = ms;
  }

  get lastEndMs(): number {
    return this.endMs;
  }

  onResult(r: SttResult): void {
    if (!r.isFinal) {
      const interim = r.text.trim();
      const text = [...this.pieces, interim].filter(Boolean).join(" ");
      if (text) this.emitInterim({ seq: this.nextSeq, text });
      return;
    }
    const { text, unclear, words } = this.renderFinal(r);
    if (text) {
      if (this.startMs === null) this.startMs = r.startMs + this.offsetMs;
      this.endMs = r.endMs + this.offsetMs;
      this.pieces.push(text);
      this.wordCount += words;
      this.unclear += unclear;
    }
    const duration = this.startMs === null ? 0 : this.endMs - this.startMs;
    const sentenceDone = /[.?!¿¡…]["”']?$/.test(text) && this.wordCount >= this.opts.minWordsForSentenceCut;
    if (r.endOfUtterance || duration >= this.opts.maxSegmentMs || sentenceDone) this.flush();
  }

  onUtteranceEnd(): void {
    this.flush();
  }

  flush(): void {
    if (this.pieces.length === 0) return;
    const seg: SegmentEvent = {
      seq: this.nextSeq++,
      startMs: this.startMs ?? this.endMs,
      endMs: this.endMs,
      text: this.pieces.join(" ").replace(/\s+/g, " ").trim(),
      unclearCount: this.unclear,
    };
    this.pieces = [];
    this.wordCount = 0;
    this.unclear = 0;
    this.startMs = null;
    this.emitSegment(seg);
  }

  private renderFinal(r: SttResult): { text: string; unclear: number; words: number } {
    if (r.words.length === 0) {
      const t = r.text.trim();
      return { text: t, unclear: 0, words: t ? t.split(/\s+/).length : 0 };
    }
    let unclear = 0;
    const out: string[] = [];
    for (const w of r.words) {
      if (w.confidence < this.opts.unclearConfidence) {
        unclear++;
        // Conserva puntuación final para no romper la oración.
        const punct = /[.,;:?!]$/.exec(w.word)?.[0] ?? "";
        if (out[out.length - 1] !== UNCLEAR_MARK) out.push(UNCLEAR_MARK + punct);
      } else {
        out.push(w.word);
      }
    }
    return { text: out.join(" ").trim(), unclear, words: r.words.length };
  }
}

import type { SttProvider, SttStream, SttStreamHandlers, SttStreamOptions } from "./types.js";

/**
 * ⚠️ PROVEEDOR SIMULADO — SOLO DESARROLLO Y PRUEBAS AUTOMÁTICAS.
 * No reconoce voz. Emite frases predefinidas en función de la cantidad de
 * audio recibido, para probar el recorrido completo sin gastar en APIs.
 * El arranque en staging/producción con este proveedor está bloqueado en config.ts.
 */
export const FAKE_SCRIPT: Record<"en" | "es", string[]> = {
  en: [
    "[SIMULATED] Good morning church.",
    "[SIMULATED] Today we read John 3:16.",
    "[SIMULATED] Grace is a gift of God.",
    "[SIMULATED] Let us pray together.",
  ],
  es: [
    "[SIMULADO] Buenos días, iglesia.",
    "[SIMULADO] Hoy leemos Juan 3:16.",
    "[SIMULADO] La gracia es un regalo de Dios.",
    "[SIMULADO] Oremos juntos.",
  ],
};

export class FakeSttProvider implements SttProvider {
  readonly name = "fake";
  /** Segundos de audio por frase simulada. */
  constructor(private readonly secondsPerPhrase = 2) {}

  async open(opts: SttStreamOptions, h: SttStreamHandlers): Promise<SttStream> {
    const bytesPerSecond = opts.sampleRate * 2;
    const phraseBytes = this.secondsPerPhrase * bytesPerSecond;
    let received = 0;
    let emitted = 0;
    let closed = false;
    const script = FAKE_SCRIPT[opts.language];

    const emitUpTo = () => {
      while (received >= (emitted + 1) * phraseBytes) {
        const text = script[emitted % script.length] ?? "";
        const startMs = emitted * this.secondsPerPhrase * 1000;
        const endMs = startMs + this.secondsPerPhrase * 1000;
        const words = text.split(" ");
        h.onResult({ isFinal: false, endOfUtterance: false, text: words.slice(0, 2).join(" "), startMs, endMs, words: [] });
        h.onResult({
          isFinal: true,
          endOfUtterance: true,
          text,
          startMs,
          endMs,
          words: words.map((w, i) => ({ word: w, startMs, endMs, confidence: i === 0 ? 0.99 : 0.95 })),
        });
        emitted++;
      }
    };

    return {
      sendAudio: (chunk) => {
        if (closed) return;
        received += chunk.length;
        emitUpTo();
      },
      keepAlive: () => undefined,
      finish: async () => {
        if (closed) return;
        closed = true;
        h.onClose();
      },
      abort: () => {
        closed = true;
      },
    };
  }
}

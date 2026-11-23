export type Lang = "en" | "es";

export interface SttWord {
  word: string;
  startMs: number;
  endMs: number;
  confidence: number;
}

/** Resultado normalizado, independiente del proveedor. */
export interface SttResult {
  /** true = texto definitivo para este tramo de audio; false = provisional. */
  isFinal: boolean;
  /** true = el proveedor detectó fin de enunciado (pausa). */
  endOfUtterance: boolean;
  text: string;
  startMs: number;
  endMs: number;
  words: SttWord[];
}

export interface SttStreamOptions {
  language: Lang;
  sampleRate: number;
  keyterms: string[];
}

export interface SttStreamHandlers {
  onResult(r: SttResult): void;
  /** Fin de enunciado sin texto nuevo (p. ej. UtteranceEnd de Deepgram). */
  onUtteranceEnd(): void;
  onError(err: Error): void;
  onClose(): void;
}

export interface SttStream {
  sendAudio(chunk: Buffer): void;
  keepAlive(): void;
  /** Solicita al proveedor vaciar resultados pendientes y cerrar. */
  finish(): Promise<void>;
  abort(): void;
}

export interface SttProvider {
  readonly name: string;
  open(opts: SttStreamOptions, handlers: SttStreamHandlers): Promise<SttStream>;
}

import type { Lang } from "../stt/types.js";
import type { ContextPair } from "./prompt.js";
import type { GlossaryTerm } from "./glossary.js";

export interface TranslateRequest {
  text: string;
  source: Lang;
  target: Lang;
  context: ContextPair[];
  glossary: GlossaryTerm[];
  signal?: AbortSignal;
}

export interface TranslateResult {
  text: string;
  inputTokens: number;
  outputTokens: number;
  cachedInputTokens: number;
}

export class TranslationFailed extends Error {
  constructor(public readonly reason: "refused" | "invalid_output" | "provider_error" | "timeout" | "cancelled") {
    super(`translation_failed:${reason}`);
  }
}

export interface Translator {
  readonly name: string;
  translate(req: TranslateRequest): Promise<TranslateResult>;
}

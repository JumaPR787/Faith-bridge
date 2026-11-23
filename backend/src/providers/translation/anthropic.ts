import Anthropic from "@anthropic-ai/sdk";
import { buildSystemPrompt, buildUserMessage, sanitizeTranslation } from "./prompt.js";
import { TranslationFailed, type TranslateRequest, type TranslateResult, type Translator } from "./types.js";

/** Modelos que admiten el parámetro de servidor `fallbacks` (beta). */
const SERVER_FALLBACK_MODELS = new Set(["claude-opus-5-5", "claude-sonnet-5-5", "claude-fable-5-2", "claude-fable-5-1", "claude-opus-5"]);
/** Modelos en los que se puede desactivar el razonamiento (esfuerzo ≤ high). */
const THINKING_DISABLE_OK = new Set(["claude-haiku-5-5"]);

/**
 * Traducción con Claude (API de Anthropic) vía el SDK oficial.
 * - Prompt de sistema estable con cache_control para abaratar entradas repetidas.
 * - Esfuerzo bajo: la tarea es una traducción corta, no razonamiento largo.
 * - Se verifica stop_reason antes de leer contenido (rechazos → marcado como fallido).
 */
export class AnthropicTranslator implements Translator {
  readonly name = "anthropic";
  private readonly client: Anthropic;

  constructor(
    apiKey: string,
    private readonly model: string,
    private readonly timeoutMs: number,
  ) {
    this.client = new Anthropic({ apiKey, maxRetries: 1, timeout: timeoutMs });
  }

  async translate(req: TranslateRequest): Promise<TranslateResult> {
    const system = buildSystemPrompt(req.source, req.target, req.glossary);
    const user = buildUserMessage(req.text, req.context);
    const base = {
      model: this.model,
      max_tokens: 2048,
      system: [{ type: "text" as const, text: system, cache_control: { type: "ephemeral" as const } }],
      messages: [{ role: "user" as const, content: user }],
      output_config: { effort: "low" as const },
      ...(THINKING_DISABLE_OK.has(this.model) ? { thinking: { type: "disabled" as const } } : {}),
    };

    let stopReason: string | null;
    let blocks: Array<{ type: string; text?: string }>;
    let usage: { input_tokens: number; output_tokens: number; cache_read_input_tokens?: number | null };
    try {
      if (SERVER_FALLBACK_MODELS.has(this.model)) {
        const r = await this.client.beta.messages.create(
          { ...base, betas: ["server-side-fallback-2026-07-01"], fallbacks: "default" },
          { signal: req.signal, timeout: this.timeoutMs },
        );
        stopReason = r.stop_reason;
        blocks = r.content as Array<{ type: string; text?: string }>;
        usage = r.usage;
      } else {
        const r = await this.client.messages.create(base, { signal: req.signal, timeout: this.timeoutMs });
        stopReason = r.stop_reason;
        blocks = r.content as Array<{ type: string; text?: string }>;
        usage = r.usage;
      }
    } catch (err) {
      if (req.signal?.aborted) throw new TranslationFailed("cancelled");
      if (err instanceof Anthropic.APIConnectionTimeoutError) throw new TranslationFailed("timeout");
      throw new TranslationFailed("provider_error");
    }

    if (stopReason === "refusal") throw new TranslationFailed("refused");
    const text = blocks
      .filter((b) => b.type === "text" && typeof b.text === "string")
      .map((b) => b.text)
      .join("");
    const clean = sanitizeTranslation(text, req.text);
    if (clean === null) throw new TranslationFailed("invalid_output");
    return {
      text: clean,
      inputTokens: usage.input_tokens,
      outputTokens: usage.output_tokens,
      cachedInputTokens: usage.cache_read_input_tokens ?? 0,
    };
  }
}

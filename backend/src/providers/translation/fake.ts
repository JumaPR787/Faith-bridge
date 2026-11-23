import { TranslationFailed, type TranslateRequest, type TranslateResult, type Translator } from "./types.js";

/**
 * ⚠️ TRADUCTOR SIMULADO — SOLO DESARROLLO Y PRUEBAS.
 * No traduce: devuelve el texto con un prefijo visible "[SIM→xx]".
 * Permite inyectar demora y fallos para probar orden y reintentos.
 */
export class FakeTranslator implements Translator {
  readonly name = "fake";
  calls = 0;
  constructor(
    private readonly opts: { delayMs?: (text: string) => number; failWhen?: (text: string) => boolean } = {},
  ) {}

  async translate(req: TranslateRequest): Promise<TranslateResult> {
    this.calls++;
    const delay = this.opts.delayMs?.(req.text) ?? 0;
    if (delay > 0) {
      await new Promise<void>((resolve, reject) => {
        const t = setTimeout(resolve, delay);
        req.signal?.addEventListener("abort", () => {
          clearTimeout(t);
          reject(new TranslationFailed("cancelled"));
        });
      });
    }
    if (this.opts.failWhen?.(req.text)) throw new TranslationFailed("provider_error");
    return { text: `[SIM→${req.target}] ${req.text}`, inputTokens: 100, outputTokens: 20, cachedInputTokens: 0 };
  }
}

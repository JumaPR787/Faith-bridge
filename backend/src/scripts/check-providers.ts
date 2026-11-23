/**
 * Verifica con llamadas REALES que las claves de los proveedores funcionan.
 * Uso (en tu computadora, desde backend/):
 *   npm run check:providers -- .env.production
 *
 * - Deepgram: abre un streaming con la configuración de producción (keyterms
 *   incluidos), envía 1 s de silencio y cierra. Costo: ~1 s de audio.
 * - Anthropic: traduce una frase de prueba con el prompt real y muestra el
 *   resultado, los tokens y el costo estimado (fracciones de centavo).
 * - RevenueCat: consulta un cliente técnico de prueba y lo borra después.
 * Nunca imprime las claves.
 */
import { existsSync } from "node:fs";
import { HttpRevenueCatClient } from "../billing/revenuecat.js";
import { DeepgramProvider } from "../providers/stt/deepgram.js";
import { keytermsFor, defaultGlossary } from "../providers/translation/glossary.js";
import { AnthropicTranslator } from "../providers/translation/anthropic.js";

type Result = { name: string; ok: boolean; detail: string };

const envFile = process.argv[2];
if (envFile) {
  if (!existsSync(envFile)) {
    console.error(`No existe ${envFile}`);
    process.exit(2);
  }
  process.loadEnvFile(envFile);
}
const env = process.env;

function errMsg(e: unknown): string {
  const m = e instanceof Error ? e.message : String(e);
  return m.replace(/(sk-ant-|Token |Bearer )[\w-]+/g, "$1***").slice(0, 160);
}

async function checkDeepgram(): Promise<Result> {
  const name = "Deepgram (voz → texto)";
  if (!env.DEEPGRAM_API_KEY) return { name, ok: false, detail: "falta DEEPGRAM_API_KEY" };
  const warnings: string[] = [];
  const keyterms = (env.DEEPGRAM_KEYTERMS_ENABLED ?? "true") === "true";
  const p = new DeepgramProvider(env.DEEPGRAM_API_KEY, env.DEEPGRAM_MODEL ?? "nova-3", keyterms, undefined, (m) => warnings.push(m));
  try {
    const noop = () => undefined;
    const t0 = Date.now();
    const s = await p.open({ language: "es", sampleRate: 16000, keyterms: keytermsFor("es") }, { onResult: noop, onUtteranceEnd: noop, onError: noop, onClose: noop });
    const ms = Date.now() - t0;
    s.sendAudio(Buffer.alloc(32000));
    await s.finish();
    const kt = !keyterms ? "keyterms desactivados" : warnings.length ? "⚠️ rechazó los keyterms (se usará sin ellos)" : "keyterms aceptados";
    return { name, ok: true, detail: `conexión en ${ms} ms; ${kt}` };
  } catch (e) {
    const m = errMsg(e);
    const hint = m.includes("401") || m.includes("403") ? " (clave inválida o sin permisos)" : m.includes("402") ? " (sin saldo o crédito)" : "";
    return { name, ok: false, detail: m + hint };
  }
}

async function checkAnthropic(): Promise<Result> {
  const name = "Anthropic (traducción)";
  if (!env.ANTHROPIC_API_KEY) return { name, ok: false, detail: "falta ANTHROPIC_API_KEY" };
  const model = env.TRANSLATION_MODEL ?? "claude-haiku-5-5";
  const t = new AnthropicTranslator(env.ANTHROPIC_API_KEY, model, 30_000);
  const text = "Good morning, church. Today we will read John 3:16 and talk about God's grace.";
  try {
    const t0 = Date.now();
    const r = await t.translate({ text, source: "en", target: "es", context: [], glossary: defaultGlossary("en", "es") });
    const ms = Date.now() - t0;
    const pin = Number(env.COST_TRANSLATION_INPUT_USD_PER_MTOK ?? 0.1);
    const pout = Number(env.COST_TRANSLATION_OUTPUT_USD_PER_MTOK ?? 0.5);
    const usd = (r.inputTokens * pin + r.outputTokens * pout) / 1e6;
    return {
      name,
      ok: true,
      detail: `${model} en ${ms} ms · «${r.text}» · tokens: ${r.inputTokens} entrada (${r.cachedInputTokens} de caché) / ${r.outputTokens} salida · ~USD ${usd.toFixed(6)}`,
    };
  } catch (e) {
    return { name, ok: false, detail: `${errMsg(e)} (revisa la clave, el saldo y que el modelo ${model} esté disponible en tu cuenta)` };
  }
}

async function checkRevenueCat(): Promise<Result> {
  const name = "RevenueCat (suscripciones)";
  if (!env.REVENUECAT_SECRET_API_KEY) return { name, ok: false, detail: "falta REVENUECAT_SECRET_API_KEY" };
  const rc = new HttpRevenueCatClient(env.REVENUECAT_SECRET_API_KEY);
  const probe = "faithbridge-healthcheck";
  try {
    await rc.getSubscriber(probe);
    await rc.deleteSubscriber(probe).catch(() => undefined);
    const hook = env.REVENUECAT_WEBHOOK_AUTH && env.REVENUECAT_WEBHOOK_AUTH.length >= 24 ? "secreto del webhook OK" : "⚠️ REVENUECAT_WEBHOOK_AUTH vacío o corto (se genera en fly-setup.sh)";
    return { name, ok: true, detail: `clave secreta válida; ${hook}` };
  } catch (e) {
    const m = errMsg(e);
    return { name, ok: false, detail: m + (m.includes("401") || m.includes("403") ? " (usa la Secret API key v1, no la pública del SDK)" : "") };
  }
}

const results = await Promise.all([checkDeepgram(), checkAnthropic(), checkRevenueCat()]);
for (const r of results) console.log(`${r.ok ? "✅" : "❌"} ${r.name}: ${r.detail}`);
process.exit(results.every((r) => r.ok) ? 0 : 1);

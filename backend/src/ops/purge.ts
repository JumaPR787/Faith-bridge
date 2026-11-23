import type { Queryable } from "../db.js";

/**
 * Retención de datos: borra transcripciones vencidas, webhooks antiguos y el
 * registro de gasto de más de 400 días. Es idempotente: se puede ejecutar
 * en cualquier momento y en varias instancias a la vez.
 */
export async function runPurge(db: Queryable): Promise<{ transcripts: number }> {
  const r = await db.query<{ n: number }>("select public.purge_expired_transcripts() as n");
  await db.query("delete from public.webhook_events where received_at < now() - interval '90 days'");
  await db.query("delete from public.spend_ledger where day < (now() - interval '400 days')::date");
  return { transcripts: r.rows[0]?.n ?? 0 };
}

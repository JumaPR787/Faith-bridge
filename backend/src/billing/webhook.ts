import { timingSafeEqual } from "node:crypto";
import type { FastifyBaseLogger } from "fastify";
import type { Config } from "../config.js";
import type { Db } from "../db.js";
import type { RevenueCatClient } from "./revenuecat.js";
import { syncEntitlement, userExists } from "./sync.js";

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export interface RcWebhookBody {
  api_version?: string;
  event?: {
    id?: string;
    type?: string;
    app_user_id?: string;
    original_app_user_id?: string;
    aliases?: string[];
    transferred_from?: string[];
    transferred_to?: string[];
    environment?: string;
  };
}

export function webhookAuthorized(header: string | undefined, expected: string | undefined): boolean {
  if (!expected || !header) return false;
  const a = Buffer.from(header);
  const b = Buffer.from(expected);
  const b2 = Buffer.from(`Bearer ${expected}`);
  if (a.length === b.length && timingSafeEqual(a, b)) return true;
  return a.length === b2.length && timingSafeEqual(a, b2);
}

/** Ids de usuario de la app (UUID de Supabase) afectados por el evento. */
export function affectedUserIds(body: RcWebhookBody): string[] {
  const e = body.event ?? {};
  const ids = new Set<string>();
  for (const id of [e.app_user_id, e.original_app_user_id, ...(e.aliases ?? []), ...(e.transferred_from ?? []), ...(e.transferred_to ?? [])]) {
    if (id && UUID_RE.test(id)) ids.add(id.toLowerCase());
  }
  return [...ids];
}

export type WebhookOutcome =
  | { status: 200; body: { ok: true; duplicate?: boolean; users?: number } }
  | { status: 400 | 401 | 500; body: { ok: false; error: string } };

/**
 * Procesa un webhook de RevenueCat:
 * 1) Autenticación con secreto compartido (cabecera Authorization).
 * 2) Idempotencia por event.id: un evento ya procesado no se repite.
 * 3) Recalcula el beneficio desde el API de RevenueCat (estado autoritativo),
 *    así el orden de llegada de los eventos no importa.
 * Si falla, responde 500 para que RevenueCat reintente.
 */
export async function handleRevenueCatWebhook(
  db: Db,
  rc: RevenueCatClient,
  cfg: Config,
  log: FastifyBaseLogger,
  authHeader: string | undefined,
  body: RcWebhookBody,
): Promise<WebhookOutcome> {
  if (!webhookAuthorized(authHeader, cfg.REVENUECAT_WEBHOOK_AUTH)) {
    return { status: 401, body: { ok: false, error: "unauthorized" } };
  }
  const eventId = body.event?.id;
  const type = body.event?.type;
  if (!eventId || !type) return { status: 400, body: { ok: false, error: "invalid_event" } };

  const ins = await db.query<{ processed_at: Date | null }>(
    `insert into public.webhook_events (provider, event_id, event_type, app_user_id)
     values ('revenuecat', $1, $2, $3)
     on conflict (provider, event_id) do update set event_type = excluded.event_type
     returning processed_at`,
    [eventId, type, body.event?.app_user_id ?? null],
  );
  if (ins.rows[0]?.processed_at) return { status: 200, body: { ok: true, duplicate: true } };

  try {
    let synced = 0;
    if (type !== "TEST") {
      for (const userId of affectedUserIds(body)) {
        if (!(await userExists(db, userId))) continue;
        await syncEntitlement(db, rc, cfg, userId);
        synced++;
      }
    }
    await db.query(
      "update public.webhook_events set processed_at = now(), error = null where provider = 'revenuecat' and event_id = $1",
      [eventId],
    );
    log.info({ eventType: type, users: synced }, "revenuecat webhook processed");
    return { status: 200, body: { ok: true, users: synced } };
  } catch (err) {
    const msg = err instanceof Error ? err.message.slice(0, 200) : "unknown";
    await db.query("update public.webhook_events set error = $2 where provider = 'revenuecat' and event_id = $1", [eventId, msg]);
    log.error({ eventType: type, err: msg }, "revenuecat webhook failed");
    return { status: 500, body: { ok: false, error: "processing_failed" } };
  }
}

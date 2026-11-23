import type { Config } from "../config.js";
import type { Queryable } from "../db.js";
import { computeEntitlement, type ComputedEntitlement } from "./entitlements.js";
import type { RevenueCatClient } from "./revenuecat.js";

/**
 * Consulta el estado autoritativo en RevenueCat y lo guarda en `entitlements`.
 * Se usa desde el webhook y desde POST /v1/subscription/sync (tras compra o
 * restauración en el teléfono).
 */
export async function syncEntitlement(
  db: Queryable,
  rc: RevenueCatClient,
  cfg: Config,
  userId: string,
  now = new Date(),
): Promise<ComputedEntitlement> {
  const subscriber = await rc.getSubscriber(userId);
  const c = computeEntitlement(
    subscriber,
    now,
    { personal: cfg.REVENUECAT_ENTITLEMENT_PERSONAL, church: cfg.REVENUECAT_ENTITLEMENT_CHURCH },
    cfg.SANDBOX_PURCHASES,
  );
  await db.query(
    `insert into public.entitlements
       (user_id, plan, status, product_id, store, is_sandbox, period_start, period_end,
        access_until, will_renew, trial_granted_at, updated_at)
     values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10, case when $11 then now() end, now())
     on conflict (user_id) do update set
       plan = excluded.plan, status = excluded.status, product_id = excluded.product_id,
       store = excluded.store, is_sandbox = excluded.is_sandbox,
       period_start = excluded.period_start, period_end = excluded.period_end,
       access_until = excluded.access_until, will_renew = excluded.will_renew,
       trial_granted_at = coalesce(public.entitlements.trial_granted_at, excluded.trial_granted_at),
       updated_at = now()`,
    [
      userId,
      c.hasAccess ? c.plan : "none",
      c.status,
      c.productId,
      c.store,
      c.isSandbox,
      c.periodStart,
      c.periodEnd,
      c.accessUntil,
      c.willRenew,
      c.isTrial && c.hasAccess,
    ],
  );
  return c;
}

export async function userExists(db: Queryable, userId: string): Promise<boolean> {
  const r = await db.query("select 1 from auth.users where id = $1", [userId]);
  return (r.rowCount ?? 0) > 0;
}

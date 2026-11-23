/**
 * Cálculo del estado de suscripción a partir de la respuesta del API REST de
 * RevenueCat (GET /v1/subscribers/{app_user_id}). RevenueCat valida los recibos
 * con Apple/Google; el backend NUNCA confía en lo que reporta el teléfono.
 *
 * Al recalcular siempre desde el estado completo del suscriptor, el resultado
 * no depende del orden en que lleguen los webhooks.
 */

export type Plan = "none" | "personal" | "church";
export type EntStatus =
  | "none"
  | "trial"
  | "active"
  | "grace"
  | "billing_issue"
  | "cancelled_active"
  | "expired"
  | "refunded";

export interface RcSubscription {
  expires_date: string | null;
  purchase_date: string;
  original_purchase_date?: string;
  period_type: "normal" | "trial" | "intro" | "prepaid" | string;
  store: string;
  is_sandbox: boolean;
  unsubscribe_detected_at: string | null;
  billing_issues_detected_at: string | null;
  grace_period_expires_date?: string | null;
  refunded_at?: string | null;
}

export interface RcEntitlement {
  expires_date: string | null;
  grace_period_expires_date?: string | null;
  product_identifier: string;
  purchase_date: string;
}

export interface RcSubscriber {
  entitlements: Record<string, RcEntitlement>;
  subscriptions: Record<string, RcSubscription>;
}

export interface ComputedEntitlement {
  plan: Plan;
  status: EntStatus;
  productId: string | null;
  store: string | null;
  isSandbox: boolean;
  isTrial: boolean;
  periodStart: Date | null;
  periodEnd: Date | null;
  accessUntil: Date | null;
  willRenew: boolean;
  hasAccess: boolean;
}

export const NO_ENTITLEMENT: ComputedEntitlement = {
  plan: "none",
  status: "none",
  productId: null,
  store: null,
  isSandbox: false,
  isTrial: false,
  periodStart: null,
  periodEnd: null,
  accessUntil: null,
  willRenew: false,
  hasAccess: false,
};

const d = (s: string | null | undefined): Date | null => (s ? new Date(s) : null);
const maxDate = (a: Date | null, b: Date | null): Date | null => (!a ? b : !b ? a : a > b ? a : b);

export function computeEntitlement(
  sub: RcSubscriber,
  now: Date,
  ids: { personal: string; church: string },
  sandboxPolicy: "allow" | "deny",
): ComputedEntitlement {
  // El plan Iglesia tiene prioridad si existe (incluye uso personal).
  const candidates: Array<[Plan, string]> = [
    ["church", ids.church],
    ["personal", ids.personal],
  ];
  let best: ComputedEntitlement = NO_ENTITLEMENT;
  for (const [plan, id] of candidates) {
    const ent = sub.entitlements[id];
    if (!ent) continue;
    const s = sub.subscriptions[ent.product_identifier];
    const c = computeOne(plan, ent, s, now, sandboxPolicy);
    if (c.hasAccess) return c;
    if (best.status === "none") best = c;
  }
  return best;
}

function computeOne(
  plan: Plan,
  ent: RcEntitlement,
  s: RcSubscription | undefined,
  now: Date,
  sandboxPolicy: "allow" | "deny",
): ComputedEntitlement {
  const expires = d(s?.expires_date ?? ent.expires_date);
  const grace = maxDate(d(s?.grace_period_expires_date), d(ent.grace_period_expires_date));
  const accessUntil = maxDate(expires, grace);
  const periodStart = d(s?.purchase_date ?? ent.purchase_date);
  const isSandbox = s?.is_sandbox ?? false;
  const isTrial = s?.period_type === "trial";
  const base = {
    plan,
    productId: ent.product_identifier,
    store: s?.store ?? null,
    isSandbox,
    isTrial,
    periodStart,
    periodEnd: expires,
    accessUntil,
  };

  if (isSandbox && sandboxPolicy === "deny") {
    return { ...base, status: "none", willRenew: false, hasAccess: false };
  }
  const refundedAt = d(s?.refunded_at);
  if (refundedAt && periodStart && refundedAt >= periodStart) {
    return { ...base, status: "refunded", willRenew: false, hasAccess: false };
  }
  if (!accessUntil || accessUntil <= now) {
    return { ...base, status: "expired", willRenew: false, hasAccess: false };
  }
  const willRenew = !s?.unsubscribe_detected_at && !s?.billing_issues_detected_at;
  let status: EntStatus;
  if (expires && expires <= now) status = "grace";
  else if (s?.billing_issues_detected_at) status = "billing_issue";
  else if (isTrial) status = "trial";
  else if (s?.unsubscribe_detected_at) status = "cancelled_active";
  else status = "active";
  return { ...base, status, willRenew, hasAccess: true };
}

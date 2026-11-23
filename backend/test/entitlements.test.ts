import { describe, expect, it } from "vitest";
import { computeEntitlement, type RcSubscriber, type RcSubscription } from "../src/billing/entitlements.js";

const NOW = new Date("2026-11-23T12:00:00Z");
const ids = { personal: "personal", church: "church" };
const iso = (offsetDays: number) => new Date(NOW.getTime() + offsetDays * 86400_000).toISOString();

function sub(over: Partial<RcSubscription> = {}, ent = "personal"): RcSubscriber {
  const s: RcSubscription = {
    expires_date: iso(20), purchase_date: iso(-10), period_type: "normal", store: "app_store", is_sandbox: false,
    unsubscribe_detected_at: null, billing_issues_detected_at: null, grace_period_expires_date: null, refunded_at: null, ...over,
  };
  return {
    entitlements: { [ent]: { expires_date: s.expires_date, product_identifier: "fb_personal_monthly", purchase_date: s.purchase_date, grace_period_expires_date: s.grace_period_expires_date } },
    subscriptions: { fb_personal_monthly: s },
  };
}

describe("computeEntitlement", () => {
  it("sin beneficio → sin acceso", () => {
    const c = computeEntitlement({ entitlements: {}, subscriptions: {} }, NOW, ids, "allow");
    expect(c.hasAccess).toBe(false);
    expect(c.status).toBe("none");
  });
  it("prueba gratuita", () => {
    const c = computeEntitlement(sub({ period_type: "trial", expires_date: iso(7), purchase_date: iso(0) }), NOW, ids, "allow");
    expect(c).toMatchObject({ status: "trial", isTrial: true, hasAccess: true, plan: "personal" });
  });
  it("activa", () => {
    expect(computeEntitlement(sub(), NOW, ids, "allow")).toMatchObject({ status: "active", willRenew: true });
  });
  it("cancelada pero vigente hasta fin de periodo", () => {
    expect(computeEntitlement(sub({ unsubscribe_detected_at: iso(-1) }), NOW, ids, "allow")).toMatchObject({ status: "cancelled_active", hasAccess: true, willRenew: false });
  });
  it("problema de cobro dentro del periodo", () => {
    expect(computeEntitlement(sub({ billing_issues_detected_at: iso(-1) }), NOW, ids, "allow")).toMatchObject({ status: "billing_issue", hasAccess: true });
  });
  it("periodo de gracia tras vencer", () => {
    expect(computeEntitlement(sub({ expires_date: iso(-1), grace_period_expires_date: iso(5), billing_issues_detected_at: iso(-1) }), NOW, ids, "allow"))
      .toMatchObject({ status: "grace", hasAccess: true });
  });
  it("vencida", () => {
    expect(computeEntitlement(sub({ expires_date: iso(-1) }), NOW, ids, "allow")).toMatchObject({ status: "expired", hasAccess: false });
  });
  it("reembolsada → sin acceso inmediato", () => {
    expect(computeEntitlement(sub({ refunded_at: iso(-1) }), NOW, ids, "allow")).toMatchObject({ status: "refunded", hasAccess: false });
  });
  it("sandbox rechazado si la política es deny", () => {
    expect(computeEntitlement(sub({ is_sandbox: true }), NOW, ids, "deny").hasAccess).toBe(false);
    expect(computeEntitlement(sub({ is_sandbox: true }), NOW, ids, "allow").hasAccess).toBe(true);
  });
  it("plan iglesia", () => {
    expect(computeEntitlement(sub({}, "church"), NOW, ids, "allow").plan).toBe("church");
  });
});

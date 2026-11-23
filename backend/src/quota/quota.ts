import type { Config } from "../config.js";
import type { Queryable } from "../db.js";

export interface QuotaStatus {
  plan: "none" | "personal" | "church";
  status: string;
  hasAccess: boolean;
  isTrial: boolean;
  periodStart: string | null;
  periodEnd: string | null;
  accessUntil: string | null;
  willRenew: boolean;
  quotaSeconds: number;
  usedSeconds: number;
  remainingSeconds: number;
  /** true si es una segunda prueba para el mismo usuario (no recibe minutos). */
  trialAlreadyUsed: boolean;
}

interface EntRow {
  plan: "none" | "personal" | "church";
  status: string;
  period_start: Date | null;
  period_end: Date | null;
  access_until: Date | null;
  will_renew: boolean;
}

const NO_ACCESS: QuotaStatus = {
  plan: "none",
  status: "none",
  hasAccess: false,
  isTrial: false,
  periodStart: null,
  periodEnd: null,
  accessUntil: null,
  willRenew: false,
  quotaSeconds: 0,
  usedSeconds: 0,
  remainingSeconds: 0,
  trialAlreadyUsed: false,
};

/**
 * Cuotas medidas en servidor. Un minuto de audio cuenta UNA vez, aunque se
 * muestren transcripción y traducción a la vez. Sin consumo ilimitado y sin
 * cobros por excedente: al agotar la cuota simplemente se detiene el servicio.
 */
export class QuotaService {
  constructor(private readonly cfg: Config) {}

  async getStatus(db: Queryable, userId: string, now = new Date()): Promise<QuotaStatus> {
    const r = await db.query<EntRow>(
      "select plan, status, period_start, period_end, access_until, will_renew from public.entitlements where user_id = $1",
      [userId],
    );
    const e = r.rows[0];
    if (!e || e.plan === "none" || !e.access_until || e.access_until <= now || !e.period_start || !e.period_end) {
      return { ...NO_ACCESS, status: e?.status ?? "none" };
    }
    const isTrial = e.status === "trial";
    const kind = isTrial ? "trial" : "paid";
    // En periodo de gracia la tienda aún no renovó: se sigue usando el último periodo.
    let periodStart = e.period_start;
    let periodEnd = e.period_end;
    if (periodEnd <= periodStart) periodEnd = new Date(periodStart.getTime() + 1000);

    let trialAlreadyUsed = false;
    let quota = this.quotaFor(e.plan, isTrial);
    if (isTrial) {
      const prior = await db.query(
        "select 1 from public.usage_periods where user_id = $1 and kind = 'trial' and period_start <> $2 limit 1",
        [userId, periodStart],
      );
      if ((prior.rowCount ?? 0) > 0) {
        trialAlreadyUsed = true;
        quota = 0;
      }
    }
    await db.query(
      `insert into public.usage_periods (user_id, period_start, period_end, kind, quota_seconds)
       values ($1, $2, $3, $4, $5) on conflict (user_id, period_start) do nothing`,
      [userId, periodStart, periodEnd, kind, quota],
    );
    const u = await db.query<{ quota_seconds: number; used_seconds: number; period_end: Date }>(
      "select quota_seconds, used_seconds, period_end from public.usage_periods where user_id = $1 and period_start = $2",
      [userId, periodStart],
    );
    const row = u.rows[0]!;
    periodEnd = row.period_end;
    const remaining = Math.max(0, row.quota_seconds - row.used_seconds);
    return {
      plan: e.plan,
      status: e.status,
      hasAccess: true,
      isTrial,
      periodStart: periodStart.toISOString(),
      periodEnd: periodEnd.toISOString(),
      accessUntil: e.access_until.toISOString(),
      willRenew: e.will_renew,
      quotaSeconds: row.quota_seconds,
      usedSeconds: row.used_seconds,
      remainingSeconds: remaining,
      trialAlreadyUsed,
    };
  }

  quotaFor(plan: "personal" | "church" | "none", isTrial: boolean): number {
    if (plan === "none") return 0;
    if (isTrial) return this.cfg.QUOTA_TRIAL_SECONDS;
    return plan === "church" ? this.cfg.QUOTA_CHURCH_SECONDS : this.cfg.QUOTA_PERSONAL_SECONDS;
  }

  async record(
    db: Queryable,
    userId: string,
    periodStart: string,
    seconds: number,
    kind: "live_audio" | "text_translation",
    sessionId: string | null,
  ): Promise<void> {
    if (seconds <= 0) return;
    await db.query(
      "update public.usage_periods set used_seconds = used_seconds + $3 where user_id = $1 and period_start = $2",
      [userId, periodStart, seconds],
    );
    await db.query(
      "insert into public.usage_events (user_id, period_start, session_id, kind, seconds) values ($1,$2,$3,$4,$5)",
      [userId, periodStart, sessionId, kind, seconds],
    );
  }

  /** Costo en "segundos de cuota" para traducir texto (redondeo hacia arriba por minuto). */
  textCostSeconds(chars: number): number {
    if (chars <= 0) return 0;
    return Math.ceil(chars / this.cfg.TEXT_CHARS_PER_QUOTA_MINUTE) * 60;
  }
}

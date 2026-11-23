import type { FastifyBaseLogger } from "fastify";
import type { Config } from "../config.js";
import { getConfigValue, type Db } from "../db.js";

export type GuardDenial =
  | "service_paused"
  | "capacity"
  | "daily_budget_reached"
  | "rate_limited";

/**
 * Controles operativos de costo y abuso:
 *  - Interruptor (app_config.live_sessions_enabled): bloquea NUEVAS sesiones
 *    costosas sin tocar las transcripciones guardadas.
 *  - Límite diario de gasto estimado (app_config.daily_cost_limit_usd).
 *  - Capacidad máxima de sesiones simultáneas.
 *  - Límite de inicios de sesión por usuario y hora.
 *  - Alertas de presupuesto al 50 %, 80 % y 100 %.
 */
export class OpsGuard {
  private alerted = new Set<string>();

  constructor(
    private readonly db: Db,
    private readonly cfg: Config,
    private readonly log: FastifyBaseLogger,
    private readonly fetchImpl: typeof fetch = fetch,
  ) {}

  async checkLiveStart(userId: string): Promise<GuardDenial | null> {
    if (!(await getConfigValue(this.db, "live_sessions_enabled", true))) return "service_paused";
    await this.reapStaleSessions();
    const maxConcurrent = await getConfigValue(this.db, "max_concurrent_live_sessions", 200);
    const active = await this.db.query<{ n: string }>("select count(*) as n from public.live_sessions where status = 'active'");
    if (Number(active.rows[0]?.n ?? 0) >= maxConcurrent) return "capacity";
    if (await this.budgetReached()) return "daily_budget_reached";
    const recent = await this.db.query<{ n: string }>(
      "select count(*) as n from public.live_sessions where user_id = $1 and started_at > now() - interval '1 hour'",
      [userId],
    );
    if (Number(recent.rows[0]?.n ?? 0) >= this.cfg.SESSION_STARTS_PER_HOUR) return "rate_limited";
    return null;
  }

  async checkTextTranslation(): Promise<GuardDenial | null> {
    if (!(await getConfigValue(this.db, "text_translation_enabled", true))) return "service_paused";
    if (await this.budgetReached()) return "daily_budget_reached";
    return null;
  }

  /** Cierra sesiones sin latido (p. ej. tras una caída del servidor). */
  async reapStaleSessions(): Promise<void> {
    await this.db.query(
      `update public.live_sessions set status = 'ended', end_reason = 'stale', ended_at = now()
       where status = 'active' and last_heartbeat < now() - interval '3 minutes'`,
    );
  }

  async budgetReached(): Promise<boolean> {
    const limit = await getConfigValue(this.db, "daily_cost_limit_usd", 25);
    const spent = await this.todaySpend();
    return spent >= limit;
  }

  async todaySpend(): Promise<number> {
    const r = await this.db.query<{ s: string | null }>(
      "select sum(est_usd) as s from public.spend_ledger where day = (now() at time zone 'utc')::date",
    );
    return Number(r.rows[0]?.s ?? 0);
  }

  async addSpend(provider: string, units: number, usd: number): Promise<void> {
    if (usd <= 0 && units <= 0) return;
    await this.db.query(
      `insert into public.spend_ledger (day, provider, units, est_usd)
       values ((now() at time zone 'utc')::date, $1, $2, $3)
       on conflict (day, provider) do update set units = public.spend_ledger.units + excluded.units,
         est_usd = public.spend_ledger.est_usd + excluded.est_usd`,
      [provider, units, usd],
    );
    await this.maybeAlert();
  }

  private async maybeAlert(): Promise<void> {
    const limit = await getConfigValue(this.db, "daily_cost_limit_usd", 25);
    if (limit <= 0) return;
    const spent = await this.todaySpend();
    const day = new Date().toISOString().slice(0, 10);
    for (const pct of [50, 80, 100]) {
      const key = `${day}:${pct}`;
      if (spent >= (limit * pct) / 100 && !this.alerted.has(key)) {
        this.alerted.add(key);
        this.log.warn({ spentUsd: spent, limitUsd: limit, pct }, "budget threshold reached");
        if (this.cfg.ALERT_WEBHOOK_URL) {
          await this.fetchImpl(this.cfg.ALERT_WEBHOOK_URL, {
            method: "POST",
            headers: { "content-type": "application/json" },
            body: JSON.stringify({ text: `FaithBridge: gasto estimado ${spent.toFixed(2)} USD (${pct}% del límite diario ${limit} USD)` }),
            signal: AbortSignal.timeout(5000),
          }).catch(() => undefined);
        }
      }
    }
  }

  sttCostUsd(seconds: number): number {
    return (seconds / 60) * this.cfg.COST_STT_USD_PER_MIN;
  }

  translationCostUsd(input: number, output: number): number {
    return (input * this.cfg.COST_TRANSLATION_INPUT_USD_PER_MTOK + output * this.cfg.COST_TRANSLATION_OUTPUT_USD_PER_MTOK) / 1_000_000;
  }
}

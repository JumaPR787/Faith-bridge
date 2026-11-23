import type { RcSubscriber } from "./entitlements.js";

export interface RevenueCatClient {
  getSubscriber(appUserId: string): Promise<RcSubscriber>;
  deleteSubscriber(appUserId: string): Promise<void>;
}

/**
 * Cliente mínimo del API REST v1 de RevenueCat (clave SECRETA, solo servidor).
 * https://www.revenuecat.com/docs/api-v1
 */
export class HttpRevenueCatClient implements RevenueCatClient {
  constructor(
    private readonly secretKey: string,
    private readonly baseUrl = "https://api.revenuecat.com/v1",
    private readonly fetchImpl: typeof fetch = fetch,
  ) {}

  async getSubscriber(appUserId: string): Promise<RcSubscriber> {
    const res = await this.fetchImpl(`${this.baseUrl}/subscribers/${encodeURIComponent(appUserId)}`, {
      headers: { Authorization: `Bearer ${this.secretKey}`, Accept: "application/json" },
      signal: AbortSignal.timeout(10_000),
    });
    if (!res.ok) throw new Error(`revenuecat_http_${res.status}`);
    const body = (await res.json()) as { subscriber?: Partial<RcSubscriber> };
    return {
      entitlements: body.subscriber?.entitlements ?? {},
      subscriptions: body.subscriber?.subscriptions ?? {},
    };
  }

  async deleteSubscriber(appUserId: string): Promise<void> {
    const res = await this.fetchImpl(`${this.baseUrl}/subscribers/${encodeURIComponent(appUserId)}`, {
      method: "DELETE",
      headers: { Authorization: `Bearer ${this.secretKey}` },
      signal: AbortSignal.timeout(10_000),
    });
    if (!res.ok && res.status !== 404) throw new Error(`revenuecat_http_${res.status}`);
  }
}

import type { FastifyBaseLogger } from "fastify";
import type { TokenVerifier } from "./auth.js";
import type { RevenueCatClient } from "./billing/revenuecat.js";
import type { Config } from "./config.js";
import type { Db } from "./db.js";
import type { SessionRegistry } from "./live/session.js";
import type { OpsGuard } from "./ops/guard.js";
import type { SttProvider } from "./providers/stt/types.js";
import type { Translator } from "./providers/translation/types.js";
import type { QuotaService } from "./quota/quota.js";

/** Dependencias compartidas (inyectables en pruebas). */
export interface AppContext {
  cfg: Config;
  db: Db;
  log: FastifyBaseLogger;
  verifyToken: TokenVerifier;
  stt: SttProvider;
  translator: Translator;
  revenuecat: RevenueCatClient;
  quota: QuotaService;
  guard: OpsGuard;
  registry: SessionRegistry;
  /** Eliminación de la cuenta en el proveedor de autenticación. */
  deleteAuthUser: (userId: string) => Promise<void>;
  liveFlushIntervalMs?: number;
  sttRetryDelaysMs?: number[];
}

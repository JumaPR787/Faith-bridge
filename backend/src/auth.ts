import { createRemoteJWKSet, jwtVerify, type JWTPayload } from "jose";
import type { Config } from "./config.js";

export interface AuthUser {
  id: string;
  email?: string;
}

export class AuthError extends Error {
  constructor(message = "unauthorized") {
    super(message);
  }
}

export type TokenVerifier = (token: string) => Promise<AuthUser>;

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Verifica JWT emitidos por Supabase Auth.
 * - Producción: claves públicas (JWKS) del proyecto Supabase.
 * - Desarrollo/pruebas: secreto HS256 compartido.
 */
export function createTokenVerifier(cfg: Config): TokenVerifier {
  const audience = cfg.SUPABASE_JWT_AUDIENCE;
  let verify: (token: string) => Promise<JWTPayload>;
  if (cfg.SUPABASE_JWKS_URL) {
    const jwks = createRemoteJWKSet(new URL(cfg.SUPABASE_JWKS_URL));
    verify = async (t) => (await jwtVerify(t, jwks, { audience })).payload;
  } else if (cfg.SUPABASE_JWT_SECRET) {
    const key = new TextEncoder().encode(cfg.SUPABASE_JWT_SECRET);
    verify = async (t) => (await jwtVerify(t, key, { audience, algorithms: ["HS256"] })).payload;
  } else {
    throw new Error("No JWT verification method configured");
  }
  return async (token: string) => {
    let payload: JWTPayload;
    try {
      payload = await verify(token);
    } catch {
      throw new AuthError("invalid_token");
    }
    if (!payload.sub || !UUID_RE.test(payload.sub)) throw new AuthError("invalid_subject");
    const email = typeof payload.email === "string" ? payload.email : undefined;
    return { id: payload.sub, email };
  };
}

export function bearerToken(header: string | undefined): string | null {
  if (!header) return null;
  const m = /^Bearer\s+(.+)$/i.exec(header);
  return m?.[1] ?? null;
}

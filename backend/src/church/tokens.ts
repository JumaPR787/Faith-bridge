import { jwtVerify, SignJWT } from "jose";

const AUDIENCE = "faithbridge-listener";

export interface ListenerClaims {
  listenerId: string;
  churchSessionId: string;
}

/**
 * Acceso temporal y anónimo de un oyente a UNA sesión de iglesia.
 * No da acceso a ninguna otra parte del API.
 */
export async function signListenerToken(secret: string, claims: ListenerClaims, expiresAt: Date): Promise<string> {
  return new SignJWT({ csid: claims.churchSessionId })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(claims.listenerId)
    .setAudience(AUDIENCE)
    .setIssuedAt()
    .setExpirationTime(Math.floor(expiresAt.getTime() / 1000))
    .sign(new TextEncoder().encode(secret));
}

export async function verifyListenerToken(secret: string, token: string): Promise<ListenerClaims | null> {
  try {
    const { payload } = await jwtVerify(token, new TextEncoder().encode(secret), { audience: AUDIENCE, algorithms: ["HS256"] });
    if (typeof payload.sub !== "string" || typeof payload.csid !== "string") return null;
    return { listenerId: payload.sub, churchSessionId: payload.csid };
  } catch {
    return null;
  }
}

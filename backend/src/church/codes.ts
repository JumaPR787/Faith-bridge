import { createHash, randomInt } from "node:crypto";

/** Alfabeto sin caracteres ambiguos (sin 0/O, 1/I/L). 31^8 ≈ 8.5·10^11 combinaciones. */
const ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
export const CODE_LENGTH = 8;

/** Código para unirse, mostrado como XXXX-XXXX. Se genera con un CSPRNG. */
export function generateJoinCode(): string {
  let c = "";
  for (let i = 0; i < CODE_LENGTH; i++) c += ALPHABET[randomInt(ALPHABET.length)];
  return `${c.slice(0, 4)}-${c.slice(4)}`;
}

/** Acepta minúsculas, espacios, guiones y el prefijo del QR («FAITHBRIDGE:»). */
export function normalizeJoinCode(input: string): string | null {
  const raw = input.trim().toUpperCase().replace(/^FAITHBRIDGE:/, "").replace(/[\s-]/g, "");
  if (raw.length !== CODE_LENGTH) return null;
  for (const ch of raw) if (!ALPHABET.includes(ch)) return null;
  return raw;
}

/** Solo se guarda el hash del código; el código en claro se muestra una vez. */
export function hashJoinCode(normalized: string): string {
  return createHash("sha256").update(`faithbridge-join:${normalized}`).digest("hex");
}

/** Contenido del QR que muestra el organizador. */
export function qrPayload(code: string): string {
  return `FAITHBRIDGE:${code}`;
}

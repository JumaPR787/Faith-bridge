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

/**
 * Acepta minúsculas, espacios, guiones, el prefijo «FAITHBRIDGE:» y enlaces
 * universales (https://dominio/j/ABCD2345 o …?code=ABCD-2345).
 */
export function normalizeJoinCode(input: string): string | null {
  let text = input.trim();
  const fromLink = /\/j\/([A-Za-z0-9-]{8,9})\/?(?:[?#].*)?$/.exec(text) ?? /[?&]code=([A-Za-z0-9-]{8,9})/.exec(text);
  if (fromLink?.[1]) text = fromLink[1];
  const raw = text.toUpperCase().replace(/^FAITHBRIDGE:/, "").replace(/[\s-]/g, "");
  if (raw.length !== CODE_LENGTH) return null;
  for (const ch of raw) if (!ALPHABET.includes(ch)) return null;
  return raw;
}

/** Solo se guarda el hash del código; el código en claro se muestra una vez. */
export function hashJoinCode(normalized: string): string {
  return createHash("sha256").update(`faithbridge-join:${normalized}`).digest("hex");
}

/**
 * Contenido del QR. Con dominio configurado es un enlace universal: la cámara
 * del teléfono abre la app (o la página web si no está instalada).
 */
export function qrPayload(code: string, linkBase?: string): string {
  if (linkBase) return `${linkBase.replace(/\/+$/, "")}/${code.replace("-", "")}`;
  return `FAITHBRIDGE:${code}`;
}

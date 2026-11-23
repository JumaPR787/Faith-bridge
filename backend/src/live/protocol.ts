import { z } from "zod";

/** Protocolo WebSocket entre la app y el backend (versión 1). */
export const PROTOCOL_VERSION = 1;

export const AUDIO_SAMPLE_RATE = 16_000; // PCM 16 bits, mono, little-endian
export const AUDIO_BYTES_PER_SECOND = AUDIO_SAMPLE_RATE * 2;
export const MAX_AUDIO_FRAME_BYTES = 64 * 1024;

export const StartMessage = z.object({
  type: z.literal("start"),
  token: z.string().min(10).max(4096),
  protocol: z.literal(PROTOCOL_VERSION),
  sourceLang: z.enum(["en", "es"]),
  targetLang: z.enum(["en", "es"]).nullable(),
  saveTranscript: z.boolean().default(false),
  resumeSessionId: z.string().uuid().optional(),
  lastSeq: z.number().int().min(-1).optional(),
}).refine((m) => m.targetLang === null || m.targetLang !== m.sourceLang, { message: "same_language" });
export type StartMessage = z.infer<typeof StartMessage>;

export const ControlMessage = z.discriminatedUnion("type", [
  z.object({ type: z.literal("pause") }),
  z.object({ type: z.literal("resume") }),
  z.object({ type: z.literal("stop") }),
  z.object({ type: z.literal("ping") }),
]);
export type ControlMessage = z.infer<typeof ControlMessage>;

export type EndReason =
  | "user_stopped"
  | "quota_exhausted"
  | "max_duration"
  | "client_gone"
  | "superseded"
  | "stt_unavailable"
  | "service_paused"
  | "server_shutdown";

export type ErrorCode =
  | "bad_request"
  | "unauthorized"
  | "no_entitlement"
  | "quota_exhausted"
  | "trial_already_used"
  | "service_paused"
  | "capacity"
  | "daily_budget_reached"
  | "rate_limited"
  | "session_not_found"
  | "stt_unavailable"
  | "internal";

export interface QuotaInfo {
  quotaSeconds: number;
  usedSeconds: number;
  remainingSeconds: number;
  periodEnd: string | null;
  isTrial: boolean;
}

export type ServerEvent =
  | {
      type: "ready";
      sessionId: string;
      resumed: boolean;
      quota: QuotaInfo;
      maxSessionSeconds: number;
      translation: boolean;
      /** true si el servidor usa proveedores SIMULADOS (solo desarrollo). */
      simulated: boolean;
    }
  | { type: "interim"; seq: number; text: string }
  | { type: "segment"; seq: number; startMs: number; endMs: number; text: string; unclearCount: number }
  | { type: "translation"; seq: number; status: "ok" | "failed"; text: string | null }
  | { type: "usage"; sessionSeconds: number; remainingSeconds: number }
  | { type: "quota_warning"; remainingSeconds: number }
  | { type: "provider_status"; status: "connected" | "reconnecting" | "paused" }
  | { type: "ended"; reason: EndReason; transcriptId: string | null; sessionSeconds: number }
  | { type: "error"; code: ErrorCode; fatal: boolean }
  | { type: "pong" };

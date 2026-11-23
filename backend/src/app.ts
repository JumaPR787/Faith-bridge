import websocket from "@fastify/websocket";
import Fastify, { type FastifyInstance } from "fastify";
import { AuthError } from "./auth.js";
import { handleRevenueCatWebhook, type RcWebhookBody } from "./billing/webhook.js";
import type { AppContext } from "./context.js";
import { handleLiveSocket } from "./live/handler.js";
import { registerAccountRoutes } from "./routes/account.js";
import { registerGlossaryRoutes } from "./routes/glossary.js";
import { registerMeRoutes } from "./routes/me.js";
import { registerTranscriptRoutes } from "./routes/transcripts.js";
import { registerTranslateRoutes } from "./routes/translate.js";

export async function buildApp(ctx: AppContext, app: FastifyInstance): Promise<FastifyInstance> {
  await app.register(websocket, { options: { maxPayload: 128 * 1024 } });

  app.setErrorHandler((err, req, reply) => {
    if (err instanceof AuthError) return reply.code(401).send({ error: "unauthorized" });
    const status = (err as { statusCode?: number }).statusCode ?? 500;
    if (status >= 500) req.log.error({ err: err instanceof Error ? err.message.slice(0, 200) : "unknown" }, "request failed");
    return reply.code(status).send({ error: status >= 500 ? "internal" : "bad_request" });
  });

  app.get("/healthz", async () => ({ ok: true, env: ctx.cfg.APP_ENV, stt: ctx.stt.name, translation: ctx.translator.name }));

  registerMeRoutes(app, ctx);
  registerTranscriptRoutes(app, ctx);
  registerTranslateRoutes(app, ctx);
  registerGlossaryRoutes(app, ctx);
  registerAccountRoutes(app, ctx);

  app.post("/webhooks/revenuecat", async (req, reply) => {
    const out = await handleRevenueCatWebhook(ctx.db, ctx.revenuecat, ctx.cfg, req.log, req.headers.authorization, req.body as RcWebhookBody);
    return reply.code(out.status).send(out.body);
  });

  app.get("/v1/live", { websocket: true }, (socket) => handleLiveSocket(ctx, socket));
  return app;
}

/** Logger de Fastify sin cuerpos de solicitud ni cabeceras sensibles. */
export function createFastify(level: string): FastifyInstance {
  return Fastify({
    logger: {
      level,
      redact: { paths: ["req.headers.authorization", "req.headers.cookie", "*.token", "*.text"], remove: true },
    },
    bodyLimit: 256 * 1024,
    trustProxy: true,
  });
}

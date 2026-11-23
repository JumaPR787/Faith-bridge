import type { FastifyRequest } from "fastify";
import { AuthError, bearerToken, type AuthUser } from "../auth.js";
import type { AppContext } from "../context.js";

export async function requireUser(ctx: AppContext, req: FastifyRequest): Promise<AuthUser> {
  const token = bearerToken(req.headers.authorization);
  if (!token) throw new AuthError("missing_token");
  const user = await ctx.verifyToken(token);
  // Crea el perfil la primera vez que el usuario llama al backend.
  await ctx.db.query("insert into public.profiles (user_id) values ($1) on conflict do nothing", [user.id]);
  return user;
}

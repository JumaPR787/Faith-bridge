import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import pg from "pg";
import { pgConfig } from "../db.js";

/**
 * Aplica db/migrations/*.sql en orden y registra cuáles se aplicaron.
 * Uso: DATABASE_URL=... npm run db:migrate   (añadir --dev-shim solo en local)
 */
const here = path.dirname(fileURLToPath(import.meta.url));
// DB_DIR: carpeta con migrations/ (en la imagen Docker: /app/db). Por defecto, db/ del repositorio.
const root = process.env.DB_DIR ?? path.resolve(here, "../../../db");

export async function migrate(databaseUrl: string, opts: { devShim?: boolean } = {}): Promise<string[]> {
  const client = new pg.Client(pgConfig(databaseUrl));
  await client.connect();
  const applied: string[] = [];
  try {
    if (opts.devShim) await client.query(await readFile(path.join(root, "dev/0000_supabase_shim.sql"), "utf8"));
    await client.query("create table if not exists public.schema_migrations (name text primary key, applied_at timestamptz not null default now())");
    await client.query("alter table public.schema_migrations enable row level security");
    const files = (await readdir(path.join(root, "migrations"))).filter((f) => f.endsWith(".sql")).sort();
    for (const f of files) {
      const done = await client.query("select 1 from public.schema_migrations where name = $1", [f]);
      if (done.rowCount) continue;
      await client.query(await readFile(path.join(root, "migrations", f), "utf8"));
      await client.query("insert into public.schema_migrations (name) values ($1)", [f]);
      applied.push(f);
    }
  } finally {
    await client.end();
  }
  return applied;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const url = process.env.DATABASE_URL;
  if (!url) throw new Error("DATABASE_URL is required");
  const applied = await migrate(url, { devShim: process.argv.includes("--dev-shim") });
  console.log(applied.length ? `Applied: ${applied.join(", ")}` : "Database up to date");
}

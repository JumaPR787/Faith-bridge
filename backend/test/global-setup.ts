import pg from "pg";
import { migrate } from "../src/scripts/migrate.js";

/**
 * Crea una base de datos de prueba nueva y aplica las migraciones reales
 * (más el shim local de Supabase). Requiere PostgreSQL accesible en
 * TEST_DATABASE_ADMIN_URL (por defecto postgres://postgres@localhost:54329/postgres).
 */
export default async function setup(): Promise<() => Promise<void>> {
  const admin = process.env.TEST_DATABASE_ADMIN_URL ?? "postgres://postgres@localhost:54329/postgres";
  const name = `fb_test_${Date.now()}`;
  const c = new pg.Client({ connectionString: admin });
  await c.connect();
  await c.query(`create database ${name}`);
  await c.end();
  const url = new URL(admin);
  url.pathname = `/${name}`;
  process.env.TEST_DATABASE_URL = url.toString();
  await migrate(url.toString(), { devShim: true });
  return async () => {
    const d = new pg.Client({ connectionString: admin });
    await d.connect();
    await d.query(`drop database if exists ${name} with (force)`);
    await d.end();
  };
}

import pg from "pg";

export type Db = pg.Pool;
export type Queryable = pg.Pool | pg.PoolClient | pg.Client;

/**
 * Configuración de conexión. Si existe DATABASE_CA_CERT (certificado raíz en
 * PEM, p. ej. el de Supabase), se usa TLS con verificación estricta del
 * servidor. Nunca se desactiva la verificación del certificado.
 */
export function pgConfig(databaseUrl: string, caCert = process.env.DATABASE_CA_CERT): pg.ClientConfig {
  if (!caCert) return { connectionString: databaseUrl };
  const u = new URL(databaseUrl);
  for (const k of ["sslmode", "sslrootcert", "sslcert", "sslkey", "ssl"]) u.searchParams.delete(k);
  return { connectionString: u.toString(), ssl: { ca: caCert, rejectUnauthorized: true } };
}

export function createDb(databaseUrl: string): Db {
  return new pg.Pool({ ...pgConfig(databaseUrl), max: 10, idleTimeoutMillis: 30_000 });
}

export async function withTx<T>(db: Db, fn: (c: pg.PoolClient) => Promise<T>): Promise<T> {
  const client = await db.connect();
  try {
    await client.query("begin");
    const out = await fn(client);
    await client.query("commit");
    return out;
  } catch (err) {
    await client.query("rollback").catch(() => undefined);
    throw err;
  } finally {
    client.release();
  }
}

export async function getConfigValue<T>(db: Queryable, key: string, fallback: T): Promise<T> {
  const r = await db.query<{ value: T }>("select value from public.app_config where key = $1", [key]);
  return r.rows[0]?.value ?? fallback;
}

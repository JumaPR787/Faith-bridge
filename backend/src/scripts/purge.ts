import pg from "pg";

/** Tarea programada (diaria): borra transcripciones vencidas según su plazo de retención. */
const url = process.env.DATABASE_URL;
if (!url) throw new Error("DATABASE_URL is required");
const client = new pg.Client({ connectionString: url });
await client.connect();
const r = await client.query<{ n: number }>("select public.purge_expired_transcripts() as n");
await client.query("delete from public.webhook_events where received_at < now() - interval '90 days'");
await client.query("delete from public.spend_ledger where day < (now() - interval '400 days')::date");
console.log(`Purged transcripts: ${r.rows[0]?.n ?? 0}`);
await client.end();

import pg from "pg";
import { pgConfig } from "../db.js";
import { runPurge } from "../ops/purge.js";

/** Ejecución manual de la purga de retención (el servidor ya la programa sola). */
const url = process.env.DATABASE_URL;
if (!url) throw new Error("DATABASE_URL is required");
const client = new pg.Client(pgConfig(url));
await client.connect();
const r = await runPurge(client);
console.log(`Purged transcripts: ${r.transcripts}`);
await client.end();

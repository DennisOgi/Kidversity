import postgres, {type Sql} from "npm:postgres@3.4.7";

export async function withDatabase<T>(
  operation: (sql: Sql) => Promise<T>,
): Promise<T> {
  const databaseUrl = Deno.env.get("SUPABASE_DB_URL");
  if (!databaseUrl) throw new Error("SUPABASE_DB_URL_MISSING");

  const sql = postgres(databaseUrl, {
    max: 1,
    prepare: false,
    idle_timeout: 5,
    connect_timeout: 10,
  });
  try {
    return await operation(sql);
  } finally {
    await sql.end();
  }
}

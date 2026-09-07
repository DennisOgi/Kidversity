import {createClient, SupabaseClient, User} from "npm:@supabase/supabase-js@2";

function namedKey(envName: string, legacyName: string): string {
  const keys = Deno.env.get(envName);
  if (keys) {
    const parsed = JSON.parse(keys) as Record<string, string>;
    if (parsed.default) return parsed.default;
  }
  const legacy = Deno.env.get(legacyName);
  if (!legacy) throw new Error(`${envName}_MISSING`);
  return legacy;
}

export function adminClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  if (!url) throw new Error("SUPABASE_URL_MISSING");
  return createClient(
    url,
    namedKey("SUPABASE_SECRET_KEYS", "SUPABASE_SERVICE_ROLE_KEY"),
    {auth: {persistSession: false, autoRefreshToken: false}},
  );
}

export async function authenticatedUser(req: Request): Promise<User> {
  const authorization = req.headers.get("Authorization");
  const url = Deno.env.get("SUPABASE_URL");
  if (!authorization || !url) throw new Error("NOT_AUTHENTICATED");

  const client = createClient(
    url,
    namedKey("SUPABASE_PUBLISHABLE_KEYS", "SUPABASE_ANON_KEY"),
    {
      global: {headers: {Authorization: authorization}},
      auth: {persistSession: false, autoRefreshToken: false},
    },
  );
  const {data, error} = await client.auth.getUser();
  if (error || !data.user) throw new Error("NOT_AUTHENTICATED");
  return data.user;
}

import {withDatabase} from "../_shared/database.ts";
import {corsHeaders, errorResponse, jsonResponse} from "../_shared/http.ts";

interface ProvisionRequest {
  email: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {headers: corsHeaders});
  }
  if (req.method !== "POST") {
    return jsonResponse({error: "METHOD_NOT_ALLOWED"}, 405);
  }

  try {
    const configuredSecret = Deno.env.get("REVIEWER_PROVISIONING_SECRET");
    const suppliedSecret = req.headers.get("x-provisioning-secret");
    if (
      !configuredSecret ||
      !suppliedSecret ||
      suppliedSecret.length !== configuredSecret.length ||
      suppliedSecret !== configuredSecret
    ) {
      throw new Error("NOT_AUTHORIZED");
    }

    const body = await req.json() as ProvisionRequest;
    const email = body.email?.trim().toLowerCase();
    if (!email || !email.includes("@")) {
      return jsonResponse({error: "INVALID_EMAIL"}, 400);
    }

    const result = await withDatabase(async (sql) =>
      await sql`
        SELECT id
        FROM auth.users
        WHERE lower(email) = ${email}
        LIMIT 1
      `
    );
    const userId = result[0]?.id as string | undefined;
    if (!userId) throw new Error("USER_NOT_FOUND");

    await withDatabase(async (sql) => {
      await sql`SELECT private.provision_reviewer(${userId}::uuid)`;
    });

    return jsonResponse({ok: true, userId});
  } catch (error) {
    return errorResponse(error);
  }
});

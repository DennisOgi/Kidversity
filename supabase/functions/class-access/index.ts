import {authenticatedUser} from "../_shared/auth.ts";
import {withDatabase} from "../_shared/database.ts";
import {corsHeaders, errorResponse, jsonResponse} from "../_shared/http.ts";

interface ClassAccessRequest {
  action: "join" | "regenerate";
  code?: string;
  classId?: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {headers: corsHeaders});
  }
  if (req.method !== "POST") {
    return jsonResponse({error: "METHOD_NOT_ALLOWED"}, 405);
  }

  try {
    const user = await authenticatedUser(req);
    const body = await req.json() as ClassAccessRequest;
    if (body.action === "join") {
      const code = body.code?.trim().toUpperCase();
      if (!code || !/^[A-HJ-NP-Z2-9]{6}$/.test(code)) {
        return jsonResponse({error: "INVALID_CODE"}, 400);
      }
      const result = await withDatabase(async (sql) =>
        await sql`
          SELECT * FROM private.join_class_with_code(
            ${user.id}::uuid,
            ${code}
          )
        `
      );
      return jsonResponse({
        classId: result[0]?.class_id,
        className: result[0]?.class_name,
      });
    }

    if (body.action === "regenerate" && body.classId) {
      const classId = body.classId;
      const result = await withDatabase(async (sql) =>
        await sql`
          SELECT private.regenerate_class_code(
            ${user.id}::uuid,
            ${classId}::uuid
          ) AS code
        `
      );
      return jsonResponse({code: result[0]?.code});
    }

    return jsonResponse({error: "INVALID_ACTION"}, 400);
  } catch (error) {
    return errorResponse(error);
  }
});

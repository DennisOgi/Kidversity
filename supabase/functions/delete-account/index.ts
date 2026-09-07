import {adminClient, authenticatedUser} from "../_shared/auth.ts";
import {corsHeaders, errorResponse, jsonResponse} from "../_shared/http.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {headers: corsHeaders});
  }
  if (req.method !== "POST") {
    return jsonResponse({error: "METHOD_NOT_ALLOWED"}, 405);
  }

  try {
    const user = await authenticatedUser(req);
    const {confirmation} = await req.json() as {confirmation?: string};
    if (confirmation !== "DELETE") {
      return jsonResponse({error: "CONFIRMATION_REQUIRED"}, 400);
    }

    const {error} = await adminClient().auth.admin.deleteUser(user.id);
    if (error) throw new Error("ACCOUNT_DELETION_FAILED");
    return jsonResponse({ok: true});
  } catch (error) {
    return errorResponse(error);
  }
});

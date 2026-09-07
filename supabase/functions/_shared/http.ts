export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-provisioning-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {...corsHeaders, "Content-Type": "application/json"},
  });
}

export function errorResponse(error: unknown): Response {
  const message = error instanceof Error ? error.message : "UNKNOWN_ERROR";
  const status =
    message === "NOT_AUTHENTICATED" ? 401 :
    message === "NOT_AUTHORIZED" ? 403 :
    message.endsWith("_REQUIRED") || message.endsWith("_INCOMPLETE") ? 409 :
    400;
  console.error("[foundation-function]", {message});
  return jsonResponse({error: message}, status);
}

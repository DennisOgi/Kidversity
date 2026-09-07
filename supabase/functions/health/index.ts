import {adminClient} from "../_shared/auth.ts";
import {corsHeaders, jsonResponse} from "../_shared/http.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {headers: corsHeaders});
  }
  if (req.method !== "GET") {
    return jsonResponse({status: "method_not_allowed"}, 405);
  }

  const started = Date.now();
  try {
    const {error} = await adminClient()
      .from("courses")
      .select("id")
      .eq("id", "mandarin_foundation_v1")
      .limit(1);
    if (error) throw error;
    return jsonResponse({
      status: "ok",
      database: "reachable",
      elapsedMs: Date.now() - started,
    });
  } catch (error) {
    console.error("[health]", error);
    return jsonResponse({
      status: "degraded",
      database: "unreachable",
      elapsedMs: Date.now() - started,
    }, 503);
  }
});

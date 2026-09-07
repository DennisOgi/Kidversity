import {authenticatedUser} from "../_shared/auth.ts";
import {withDatabase} from "../_shared/database.ts";
import {corsHeaders, errorResponse, jsonResponse} from "../_shared/http.ts";

interface CompletionRequest {
  lessonId: string;
  score: number;
  answers: unknown[];
  minutes?: number;
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
    const body = await req.json() as CompletionRequest;
    if (
      !/^mfv1_l\d{2}$/.test(body.lessonId) ||
      !Number.isFinite(body.score) ||
      !Array.isArray(body.answers)
    ) {
      return jsonResponse({error: "INVALID_REQUEST"}, 400);
    }

    const score = Math.max(0, Math.min(100, Math.round(body.score)));
    const minutes = Math.max(1, Math.min(120, Math.round(body.minutes ?? 10)));
    const answers = JSON.stringify(body.answers);
    const result = await withDatabase(async (sql) =>
      await sql`
        SELECT private.complete_foundation_lesson(
          ${user.id}::uuid,
          ${body.lessonId},
          ${score},
          ${answers}::jsonb,
          ${minutes}
        ) AS first_completion
      `
    );

    return jsonResponse({
      firstCompletion: result[0]?.first_completion === true,
    });
  } catch (error) {
    return errorResponse(error);
  }
});

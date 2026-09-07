import {authenticatedUser} from "../_shared/auth.ts";
import {withDatabase} from "../_shared/database.ts";
import {corsHeaders, errorResponse, jsonResponse} from "../_shared/http.ts";

type ReviewAction = "review" | "submit" | "publish";
type Verdict = "approved" | "corrected" | "rejected";

interface ReviewRequest {
  action: ReviewAction;
  lessonId?: string;
  itemType?: string;
  itemId?: string;
  verdict?: Verdict;
  notes?: string;
  corrections?: Record<string, unknown>;
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
    const body = await req.json() as ReviewRequest;
    if (!["review", "submit", "publish"].includes(body.action)) {
      return jsonResponse({error: "INVALID_ACTION"}, 400);
    }

    await withDatabase(async (sql) => {
      if (body.action === "review") {
        if (
          !body.itemType ||
          !body.itemId ||
          !body.verdict ||
          !["approved", "corrected", "rejected"].includes(body.verdict)
        ) {
          throw new Error("INVALID_REVIEW");
        }
        await sql`
          SELECT private.review_foundation_item(
            ${user.id}::uuid,
            ${body.itemType},
            ${body.itemId},
            ${body.verdict},
            ${body.notes ?? ""},
            ${JSON.stringify(body.corrections ?? {})}::jsonb
          )
        `;
        return;
      }

      if (!body.lessonId || !/^mfv1_l\d{2}$/.test(body.lessonId)) {
        throw new Error("INVALID_LESSON");
      }
      if (body.action === "submit") {
        await sql`
          SELECT private.submit_foundation_lesson(
            ${user.id}::uuid,
            ${body.lessonId}
          )
        `;
      } else {
        await sql`
          SELECT private.publish_foundation_lesson(
            ${user.id}::uuid,
            ${body.lessonId}
          )
        `;
      }
    });

    return jsonResponse({ok: true});
  } catch (error) {
    return errorResponse(error);
  }
});

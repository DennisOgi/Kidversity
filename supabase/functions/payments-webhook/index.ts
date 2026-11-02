import {createHmac, timingSafeEqual} from "node:crypto";
import {withDatabase} from "../_shared/database.ts";
import {corsHeaders, errorResponse, jsonResponse} from "../_shared/http.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {headers: corsHeaders});
  }
  if (req.method !== "POST") {
    return jsonResponse({error: "METHOD_NOT_ALLOWED"}, 405);
  }

  try {
    const secret = Deno.env.get("PAYSTACK_SECRET_KEY");
    if (!secret) throw new Error("PAYSTACK_SECRET_KEY_MISSING");

    const rawBody = await req.text();
    const signature = req.headers.get("x-paystack-signature") || "";
    const digest = createHmac("sha512", secret).update(rawBody).digest("hex");
    const valid = signature.length === digest.length &&
      timingSafeEqual(
        new TextEncoder().encode(signature),
        new TextEncoder().encode(digest),
      );
    if (!valid) {
      return jsonResponse({error: "INVALID_SIGNATURE"}, 401);
    }

    const event = JSON.parse(rawBody) as {
      event?: string;
      data?: {reference?: string; status?: string};
    };

    if (
      event.event === "charge.success" &&
      event.data?.status === "success" &&
      event.data.reference
    ) {
      const reference = event.data.reference;
      const result = await withDatabase(async (sql) =>
        await sql`
          SELECT private.fulfill_paid_purchase(${reference}) AS data
        `
      );
      return jsonResponse({ok: true, result: result[0]?.data ?? null});
    }

    return jsonResponse({ok: true, ignored: true});
  } catch (error) {
    return errorResponse(error);
  }
});

import {authenticatedUser} from "../_shared/auth.ts";
import {withDatabase} from "../_shared/database.ts";
import {corsHeaders, errorResponse, jsonResponse} from "../_shared/http.ts";

interface VerifyRequest {
  reference: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {headers: corsHeaders});
  }
  if (req.method !== "POST") {
    return jsonResponse({error: "METHOD_NOT_ALLOWED"}, 405);
  }

  try {
    await authenticatedUser(req);
    const body = await req.json() as VerifyRequest;
    const reference = body.reference?.trim();
    if (!reference) return jsonResponse({error: "REFERENCE_REQUIRED"}, 400);

    const secret = Deno.env.get("PAYSTACK_SECRET_KEY");
    if (!secret) throw new Error("PAYSTACK_SECRET_KEY_MISSING");

    const verifyRes = await fetch(
      `https://api.paystack.co/transaction/verify/${encodeURIComponent(reference)}`,
      {headers: {Authorization: `Bearer ${secret}`}},
    );
    const verifyJson = await verifyRes.json() as {
      status?: boolean;
      message?: string;
      data?: {status?: string; reference?: string};
    };
    if (!verifyRes.ok || !verifyJson.status) {
      throw new Error(verifyJson.message || "PAYSTACK_VERIFY_FAILED");
    }
    if (verifyJson.data?.status !== "success") {
      return jsonResponse({
        ok: false,
        status: verifyJson.data?.status ?? "failed",
      });
    }

    const result = await withDatabase(async (sql) =>
      await sql`
        SELECT private.fulfill_paid_purchase(${reference}) AS data
      `
    );

    return jsonResponse({ok: true, result: result[0]?.data ?? null});
  } catch (error) {
    return errorResponse(error);
  }
});

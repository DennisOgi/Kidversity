import {authenticatedUser, adminClient} from "../_shared/auth.ts";
import {withDatabase} from "../_shared/database.ts";
import {corsHeaders, errorResponse, jsonResponse} from "../_shared/http.ts";

/// Only send Paystack back to our own app. Allowed origins come from
/// PAYSTACK_CALLBACK_URL plus the optional comma-separated APP_ORIGINS secret.
function safeCallbackUrl(requested?: string): string | undefined {
  const fallback = Deno.env.get("PAYSTACK_CALLBACK_URL") || undefined;
  if (!requested) return fallback;
  const allowed = new Set(
    (Deno.env.get("APP_ORIGINS") ?? "")
      .split(",")
      .map((item) => item.trim())
      .filter(Boolean),
  );
  if (fallback) {
    try {
      allowed.add(new URL(fallback).origin);
    } catch {
      // Ignore a malformed secret; the fallback below still applies.
    }
  }
  try {
    const url = new URL(requested.trim());
    if (url.protocol === "https:" && allowed.has(url.origin)) return url.toString();
    if (url.hostname === "localhost" || url.hostname === "127.0.0.1") {
      return url.toString();
    }
  } catch {
    // Not a URL.
  }
  return fallback;
}

interface CheckoutRequest {
  productType: "subject_pack" | "bundle_3";
  packId?: string;
  learnerUserId?: string;
  email?: string;
  callbackUrl?: string;
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
    const body = await req.json() as CheckoutRequest;
    if (
      body.productType !== "subject_pack" &&
      body.productType !== "bundle_3"
    ) {
      return jsonResponse({error: "INVALID_PRODUCT"}, 400);
    }
    if (body.productType === "subject_pack" && !body.packId) {
      return jsonResponse({error: "PACK_REQUIRED"}, 400);
    }

    const secret = Deno.env.get("PAYSTACK_SECRET_KEY");
    if (!secret) throw new Error("PAYSTACK_SECRET_KEY_MISSING");

    const checkout = await withDatabase(async (sql) => {
      const rows = await sql`
        SELECT private.payment_create_checkout(
          ${user.id}::uuid,
          ${body.productType},
          ${body.packId ?? null},
          ${body.learnerUserId ?? null}
        ) AS data
      `;
      return rows[0]?.data as Record<string, unknown>;
    });

    const reference = String(checkout.reference);
    const amount = Number(checkout.amount_kobo);
    const email = (body.email || user.email || "").trim().toLowerCase();
    if (!email.includes("@")) {
      return jsonResponse({error: "EMAIL_REQUIRED"}, 400);
    }

    const callbackUrl = safeCallbackUrl(body.callbackUrl);

    const initRes = await fetch(
      "https://api.paystack.co/transaction/initialize",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${secret}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          email,
          amount,
          currency: "NGN",
          reference,
          callback_url: callbackUrl,
          metadata: {
            purchase_id: checkout.purchase_id,
            product_type: body.productType,
            pack_id: body.packId ?? null,
            learner_user_id: checkout.learner_user_id,
            family_id: checkout.family_id,
          },
        }),
      },
    );
    const initJson = await initRes.json() as {
      status?: boolean;
      message?: string;
      data?: {
        authorization_url?: string;
        access_code?: string;
        reference?: string;
      };
    };
    if (!initRes.ok || !initJson.status || !initJson.data?.authorization_url) {
      throw new Error(initJson.message || "PAYSTACK_INIT_FAILED");
    }

    const accessCode = initJson.data.access_code ?? null;
    const admin = adminClient();
    await admin.from("payment_purchases").update({
      paystack_access_code: accessCode,
    }).eq("paystack_reference", reference);

    return jsonResponse({
      purchaseId: checkout.purchase_id,
      reference,
      amountKobo: amount,
      currency: "NGN",
      authorizationUrl: initJson.data.authorization_url,
      accessCode,
      productType: body.productType,
      packId: checkout.pack_id ?? null,
      subjectId: checkout.subject_id ?? null,
    });
  } catch (error) {
    return errorResponse(error);
  }
});

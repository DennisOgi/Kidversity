import {adminClient, authenticatedUser} from "../_shared/auth.ts";
import {googleAccessToken} from "../_shared/google_auth.ts";
import {corsHeaders, errorResponse, jsonResponse} from "../_shared/http.ts";

interface GenerateRequest {
  clipId: string;
  voice?: string;
}

function safeSegment(value: string): string {
  return value.replace(/[^a-zA-Z0-9_-]/g, "_");
}

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
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
    const admin = adminClient();
    const {data: reviewer} = await admin
      .from("reviewer_accounts")
      .select("active")
      .eq("user_id", user.id)
      .eq("active", true)
      .maybeSingle();
    if (!reviewer) throw new Error("NOT_AUTHORIZED");

    const body = await req.json() as GenerateRequest;
    if (!body.clipId) return jsonResponse({error: "INVALID_CLIP"}, 400);

    const {data: clip, error: clipError} = await admin
      .from("audio_clips")
      .select("id,lesson_id,item_type,item_id,audio_text")
      .eq("id", body.clipId)
      .single();
    if (clipError || !clip) throw new Error("CLIP_NOT_FOUND");

    const source = {
      vocab: ["vocab_items", "simplified_chinese"],
      dialogue: ["dialogues", "chinese"],
      example: ["examples", "chinese"],
      activity: ["activities", "answer"],
      assessment: ["assessment_items", "correct_answer"],
    }[clip.item_type] as [string, string] | undefined;
    if (!source) throw new Error("AUDIO_ITEM_TYPE_UNSUPPORTED");
    const [sourceTable, sourceColumn] = source;
    const {data: sourceItem, error: sourceError} = await admin
      .from(sourceTable)
      .select(`review_status,${sourceColumn}`)
      .eq("id", clip.item_id)
      .single();
    if (
      sourceError ||
      !sourceItem ||
      !["approved", "corrected"].includes(sourceItem.review_status) ||
      sourceItem[sourceColumn] !== clip.audio_text
    ) {
      throw new Error("AUDIO_SOURCE_NOT_APPROVED");
    }

    const voice = body.voice?.trim() ||
      Deno.env.get("GOOGLE_TTS_VOICE") ||
      "cmn-CN-Standard-A";
    const requestHash = await sha256(
      JSON.stringify({text: clip.audio_text, voice, rate: 0.88}),
    );
    const storagePath = [
      "mandarin_foundation_v1",
      safeSegment(clip.lesson_id),
      safeSegment(clip.item_type),
      `${safeSegment(clip.item_id)}-${requestHash.substring(0, 16)}.mp3`,
    ].join("/");

    const token = await googleAccessToken();
    const synthesis = await fetch(
      "https://texttospeech.googleapis.com/v1/text:synthesize",
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          input: {text: clip.audio_text},
          voice: {languageCode: "cmn-CN", name: voice},
          audioConfig: {
            audioEncoding: "MP3",
            speakingRate: 0.88,
            pitch: 0,
          },
        }),
      },
    );
    if (!synthesis.ok) {
      console.error("[google-tts]", {
        status: synthesis.status,
        body: await synthesis.text(),
      });
      throw new Error("GOOGLE_TTS_GENERATION_FAILED");
    }
    const payload = await synthesis.json() as {audioContent?: string};
    if (!payload.audioContent) throw new Error("GOOGLE_TTS_EMPTY_AUDIO");

    const binary = Uint8Array.from(
      atob(payload.audioContent),
      (character) => character.charCodeAt(0),
    );
    const {error: uploadError} = await admin.storage
      .from("mandarin-audio")
      .upload(storagePath, binary, {
        contentType: "audio/mpeg",
        cacheControl: "31536000",
        upsert: false,
      });
    if (uploadError && !uploadError.message.toLowerCase().includes("exists")) {
      throw new Error("AUDIO_UPLOAD_FAILED");
    }

    const {error: updateError} = await admin
      .from("audio_clips")
      .update({
        storage_path: storagePath,
        audio_url: null,
        text_hash: requestHash,
        provider: "google",
        voice,
        speech_lang: "cmn-CN",
        generated_at: new Date().toISOString(),
        review_status: "pending",
      })
      .eq("id", clip.id);
    if (updateError) throw new Error("AUDIO_METADATA_UPDATE_FAILED");

    return jsonResponse({ok: true, clipId: clip.id});
  } catch (error) {
    return errorResponse(error);
  }
});

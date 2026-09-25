import {createClient, SupabaseClient, User} from "npm:@supabase/supabase-js@2";
import {corsHeaders, errorResponse, jsonResponse} from "../_shared/http.ts";

function namedKey(envName: string, legacyName: string): string {
  const keys = Deno.env.get(envName);
  if (keys) {
    const parsed = JSON.parse(keys) as Record<string, string>;
    if (parsed.default) return parsed.default;
  }
  const legacy = Deno.env.get(legacyName);
  if (!legacy) throw new Error(`${envName}_MISSING`);
  return legacy;
}

function adminClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  if (!url) throw new Error("SUPABASE_URL_MISSING");
  return createClient(
    url,
    namedKey("SUPABASE_SECRET_KEYS", "SUPABASE_SERVICE_ROLE_KEY"),
    {auth: {persistSession: false, autoRefreshToken: false}},
  );
}

async function authenticatedUser(req: Request): Promise<User> {
  const authorization = req.headers.get("Authorization");
  const url = Deno.env.get("SUPABASE_URL");
  if (!authorization || !url) throw new Error("NOT_AUTHENTICATED");
  const client = createClient(
    url,
    namedKey("SUPABASE_PUBLISHABLE_KEYS", "SUPABASE_ANON_KEY"),
    {
      global: {headers: {Authorization: authorization}},
      auth: {persistSession: false, autoRefreshToken: false},
    },
  );
  const {data, error} = await client.auth.getUser();
  if (error || !data.user) throw new Error("NOT_AUTHENTICATED");
  return data.user;
}

interface HarvestKey {
  exam_slug: string;
  subject_slug: string;
  exam_year: number;
}

function sdashBase(): string {
  return (Deno.env.get("SDASH_API_BASE_URL") ?? "https://www.sdashapi.com/api")
    .replace(/\/+$/, "");
}

function sdashToken(): string {
  const token = Deno.env.get("SDASH_ACCESS_TOKEN")?.trim() ?? "";
  if (!token) throw new Error("SDASH_TOKEN_MISSING");
  return token;
}

async function sdashGet(
  path: string,
  query: Record<string, string> = {},
): Promise<Record<string, unknown>> {
  const url = new URL(`${sdashBase()}${path}`);
  for (const [key, value] of Object.entries(query)) {
    if (value) url.searchParams.set(key, value);
  }
  const response = await fetch(url, {
    headers: {
      AccessToken: sdashToken(),
      Accept: "application/json",
    },
  });
  const body = await response.json() as Record<string, unknown>;
  const status = typeof body.status === "number" ? body.status : response.status;
  if (status === 404) return {status: 404, data: []};
  if (status >= 400) {
    throw new Error(String(body.message ?? `SDASH_${status}`));
  }
  return body;
}

function asList(data: unknown): Record<string, unknown>[] {
  if (Array.isArray(data)) {
    return data.filter((item): item is Record<string, unknown> =>
      !!item && typeof item === "object"
    );
  }
  if (data && typeof data === "object") {
    return [data as Record<string, unknown>];
  }
  return [];
}

async function requireTeacher(admin: SupabaseClient, userId: string) {
  const {data, error} = await admin
    .from("user_profiles")
    .select("role")
    .eq("user_id", userId)
    .maybeSingle();
  if (error || !data) throw new Error("NOT_AUTHORIZED");
  if (data.role !== "teacher" && data.role !== "reviewer") {
    throw new Error("NOT_AUTHORIZED");
  }
}

async function refreshCatalog(admin: SupabaseClient) {
  const [examsBody, subjectsBody, yearsBody] = await Promise.all([
    sdashGet("/v1/exams"),
    sdashGet("/v1/subjects"),
    sdashGet("/v1/years"),
  ]);
  const exams = asList(examsBody.data);
  const subjects = asList(subjectsBody.data);
  const years = Array.isArray(yearsBody.data) ? yearsBody.data : [];

  if (exams.length > 0) {
    await admin.from("exam_bank_exams").upsert(
      exams.map((item) => ({
        slug: String(item.slug ?? ""),
        name: String(item.name ?? item.slug ?? "Exam"),
        sdash_id: typeof item.id === "number" ? item.id : null,
      })).filter((item) => /^[a-z0-9-]{1,40}$/.test(item.slug)),
      {onConflict: "slug"},
    );
  }
  if (subjects.length > 0) {
    await admin.from("exam_bank_subjects").upsert(
      subjects.map((item) => ({
        slug: String(item.slug ?? ""),
        name: String(item.name ?? item.slug ?? "Subject"),
        sdash_id: typeof item.id === "number" ? item.id : null,
      })).filter((item) => /^[a-z0-9-]{1,40}$/.test(item.slug)),
      {onConflict: "slug"},
    );
  }
  const yearRows = years
    .map((item) => typeof item === "number" ? item : Number(item))
    .filter((year) => year >= 1980 && year <= 2100)
    .map((year) => ({year}));
  if (yearRows.length > 0) {
    await admin.from("exam_bank_years").upsert(yearRows, {onConflict: "year"});
  }
}

async function nextCombo(
  admin: SupabaseClient,
): Promise<HarvestKey | null> {
  const [{data: exams}, {data: subjects}, {data: years}] = await Promise.all([
    admin.from("exam_bank_exams").select("slug").order("slug"),
    admin.from("exam_bank_subjects").select("slug").order("slug"),
    admin.from("exam_bank_years").select("year").order("year", {ascending: false}),
  ]);
  const {data: papers} = await admin
    .from("exam_bank_papers")
    .select("exam_slug, subject_slug, exam_year, exhausted");
  const exhausted = new Set(
    (papers ?? [])
      .filter((row) => row.exhausted)
      .map((row) => `${row.exam_slug}|${row.subject_slug}|${row.exam_year}`),
  );
  for (const exam of exams ?? []) {
    for (const subject of subjects ?? []) {
      for (const yearRow of years ?? []) {
        const key = `${exam.slug}|${subject.slug}|${yearRow.year}`;
        if (exhausted.has(key)) continue;
        return {
          exam_slug: exam.slug,
          subject_slug: subject.slug,
          exam_year: yearRow.year,
        };
      }
    }
  }
  return null;
}

async function harvestCombo(
  admin: SupabaseClient,
  combo: HarvestKey,
): Promise<number> {
  const body = await sdashGet("/v1/q", {
    type: combo.exam_slug,
    subject: combo.subject_slug,
    year: String(combo.exam_year),
    limit: "50",
  });
  const rows = asList(body.data).map((item) => ({
    ...item,
    exam_slug: combo.exam_slug,
    subject_slug: combo.subject_slug,
  }));
  const upserts = rows
    .map((item) => {
      const id = Number(item.id);
      const examYear = String(item.examyear ?? combo.exam_year);
      if (!id || examYear !== String(combo.exam_year)) return null;
      return {
        id,
        exam_slug: combo.exam_slug,
        exam_label: String(item.examtype ?? combo.exam_slug),
        subject_slug: combo.subject_slug,
        exam_year: examYear,
        university: item.university ? String(item.university) : null,
        payload: item,
      };
    })
    .filter((item): item is NonNullable<typeof item> => item !== null);

  let added = 0;
  if (upserts.length > 0) {
    const {data: existing} = await admin
      .from("exam_bank_questions")
      .select("id")
      .in("id", upserts.map((item) => item.id));
    const known = new Set((existing ?? []).map((row) => row.id));
    added = upserts.filter((item) => !known.has(item.id)).length;
    const {error} = await admin.from("exam_bank_questions").upsert(upserts, {
      onConflict: "id",
    });
    if (error) throw new Error(error.message);
  }

  const matching = upserts.filter((item) =>
    String(item.exam_year) === String(combo.exam_year)
  );
  const {count} = await admin
    .from("exam_bank_questions")
    .select("id", {count: "exact", head: true})
    .eq("exam_slug", combo.exam_slug)
    .eq("subject_slug", combo.subject_slug)
    .eq("exam_year", String(combo.exam_year));

  const {data: previous} = await admin
    .from("exam_bank_papers")
    .select("id, empty_streak")
    .eq("exam_slug", combo.exam_slug)
    .eq("subject_slug", combo.subject_slug)
    .eq("exam_year", combo.exam_year)
    .eq("university", "")
    .maybeSingle();
  const emptyStreak = added === 0
    ? (previous?.empty_streak ?? 0) + 1
    : 0;
  await admin.from("exam_bank_papers").upsert({
    exam_slug: combo.exam_slug,
    subject_slug: combo.subject_slug,
    exam_year: combo.exam_year,
    university: "",
    question_count: count ?? matching.length,
    empty_streak: emptyStreak,
    exhausted: added === 0 || emptyStreak >= 2,
    last_harvested_at: new Date().toISOString(),
  }, {onConflict: "exam_slug,subject_slug,exam_year,university"});
  return added;
}

async function questionCount(admin: SupabaseClient): Promise<number> {
  const {count} = await admin
    .from("exam_bank_questions")
    .select("id", {count: "exact", head: true});
  return count ?? 0;
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
    const body = await req.json() as {action?: string; rounds?: number};
    const action = body.action ?? "status";

    if (action === "status") {
      const questions = await questionCount(admin);
      return jsonResponse({questions});
    }

    if (action === "catalog") {
      await requireTeacher(admin, user.id);
      await refreshCatalog(admin);
      return jsonResponse({ok: true});
    }

    if (action === "harvest") {
      await requireTeacher(admin, user.id);
      try {
        sdashToken();
      } catch {
        return jsonResponse({
          added: 0,
          questions: await questionCount(admin),
          done: true,
          message:
            "Add SDASH_ACCESS_TOKEN as a Supabase function secret, then try again.",
        });
      }
      await refreshCatalog(admin);
      const rounds = Math.max(1, Math.min(Number(body.rounds ?? 8), 12));
      let added = 0;
      let finished = false;
      for (let index = 0; index < rounds; index += 1) {
        const combo = await nextCombo(admin);
        if (!combo) {
          finished = true;
          break;
        }
        added += await harvestCombo(admin, combo);
        if (index + 1 < rounds) {
          await new Promise((resolve) => setTimeout(resolve, 500));
        }
      }
      return jsonResponse({
        added,
        questions: await questionCount(admin),
        done: finished,
        message: finished
          ? "Every exam, subject, and year has been copied."
          : undefined,
      });
    }

    return jsonResponse({error: "INVALID_ACTION"}, 400);
  } catch (error) {
    const message = error instanceof Error ? error.message : "UNKNOWN_ERROR";
    if (message === "SDASH_TOKEN_MISSING") {
      return jsonResponse({
        added: 0,
        questions: 0,
        done: true,
        message:
          "Add SDASH_ACCESS_TOKEN as a Supabase function secret, then try again.",
      });
    }
    return errorResponse(error);
  }
});

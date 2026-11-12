# Kidversity

A browser-first learning platform for Nigerian learners, built with **Flutter**
and **Supabase**. Students work through Mandarin and maths pathways, practise
past exam questions, explore labs, and play **Rope Pull** against classmates.
Teachers run classes and live quizzes. Parents follow their children and unlock
lesson packs.

## Who uses it

| Role | Lands on | What they do |
| --- | --- | --- |
| Student | `/student/path` | Mandarin & maths pathways, past questions, labs, Rope Pull, link to a parent (Me → Family) |
| Teacher | `/teacher/class` | Class + join code, assignments, progress, live quizzes, projected Rope Pull |
| Parent | `/parent/family` | Family code, each child's pathway, lesson-8 reminders, buy packs / use credits |
| Reviewer | `/reviewer/queue` | Approve Mandarin lessons before learners see them (invite only) |
| Platform admin | `/admin` | Schools, users, performance, payments analytics (invite only) |

Onboarding asks for the role first, then name, companion, and a role-specific
setup step (class/family codes for students, class name for teachers, pricing
for parents).

## Lesson packs (Paystack, NGN)

* Lessons 1–2 of every subject are free.
* ₦2,500 unlocks the next 10 lessons in one subject. Packs end at a milestone.
* ₦6,500 bundle = 3 pack credits, usable in any subject, for any child in the family.
* No subscription. Purchases never expire. Lessons open one at a time.
* At lesson 8 of a paid pack the learner sees a nudge and the parent's Family
  page shows the next pack as due.

The database enforces access (`private.user_has_lesson_access`) for Mandarin
lesson completion and maths results. Families, purchases, credits,
entitlements, and every payment event live in `payment_*` tables.
`admin_payment_analytics()` reports purchases, pack completion, repeat
purchases, and cross-subject purchases per family.

## Rope Pull

Real-time tug-of-war between two teams (Indigo vs Teal).

* **Quick match** pairs two classmates from the same school who chose the same
  game; the pull starts as soon as the second player arrives.
* **Codes** (4 letters) for any group, plus school challenges and a projected
  class board for teachers.
* **Fair play:** the server builds every deck (`create_rope_pull_match`), so
  no device, the host's included, gets the answers. Answer keys live in
  `private.rope_pull_keys`; answers after the round's time do not count. A player only
  sees a round's answer after answering or when the round closes, and other
  players' picks stay hidden mid-round.
* **Weekly ladder** of wins per school (`rope_pull_ladder`).
* Art: a Blender-rendered school field and four rigged kids rendered to sprite
  sheets (idle, pull, slip, win, lose), with per-frame hand and foot points so
  the rope (drawn in code) runs through their fists. Dust puffs come from
  `assets/rope_pull/ui/dust-sheet.png`. Pipeline: `tool/rope_pull_blender/`.

## Architecture

```
lib/
  config/      Env (Supabase URL + publishable key, Sentry)
  data/        Riverpod providers, auth controller
  features/    student/ teacher/ parent/ admin/ reviewer/ onboarding/ …
  models/      Plain Dart models (payments, families, rope pull, …)
  router/      go_router routes and per-role shells
  services/    Supabase RPC / Edge Function clients
  widgets/     Shared UI, Rope Pull arena painter
supabase/
  migrations/  Source of truth for the database
  functions/   Edge Functions (Deno)
```

### Edge Functions

| Function | JWT | Purpose |
| --- | --- | --- |
| `payments-checkout` | yes | Create a purchase and a Paystack checkout (parents can buy for a linked child) |
| `payments-verify` | yes | Confirm a Paystack reference and grant the pack/credits |
| `payments-webhook` | **no** | Paystack `charge.success` (HMAC-SHA512 signature checked) |
| `exam-bank` | yes | Fill the past-questions bank from SdashAPI (token stays server-side) |
| `delete-account` | yes | Self-service account deletion |
| `class-access`, `foundation-*`, `generate-mandarin-tts`, `provision-reviewer`, `health` | mixed | See each function |

Function secrets: `PAYSTACK_SECRET_KEY`, `PAYSTACK_CALLBACK_URL`,
`APP_ORIGINS` (comma-separated allowed callback origins), `SDASH_ACCESS_TOKEN`,
`GOOGLE_SERVICE_ACCOUNT_JSON`, `REVIEWER_PROVISIONING_SECRET`.

**Never** put third-party tokens in `.env`, Vercel env vars, or `--dart-define`:
everything in the web build is public.

## Run it

```bash
cp .env.example .env        # Supabase URL + publishable key only
flutter pub get
flutter run -d chrome
```

Checks (also run in CI):

```bash
dart format lib test
flutter analyze
flutter test
deno check supabase/functions/*/index.ts
```

## Deploy

* Web: Vercel runs `scripts/vercel-build.sh` (needs `SUPABASE_URL`,
  `SUPABASE_PUBLISHABLE_KEY`, optional `SENTRY_DSN`).
* Database: `supabase db push` with the migrations in `supabase/migrations`.
* Functions: `supabase functions deploy <name>`.
* Paystack dashboard → webhook URL:
  `https://<project-ref>.supabase.co/functions/v1/payments-webhook`.

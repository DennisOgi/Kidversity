# ACE — production build plan

ACE (Advance. Conquer. Excel.) is the academic learning platform. Kidversity
stays the skills and languages brand. ACE launches with Cambridge AS and A2
Mathematics (9709) and Physics (9702) for Oxbridge, and is built for more
subjects and schools.

This plan turns `ACE_A_Level_Integration_Starter` (v0.6.0) into a working,
production-grade product. Status markers: **[built]**, **[next]**, **[later]**.

## 1. Architecture decisions

| Decision | Choice | Why |
|---|---|---|
| Backend | Its own Supabase project, **ACE** (`nzcmezjhgcdhfxqbnhgv`, eu-west-1) | Separate brand, separate tenants and data; nothing from Kidversity leaks in either direction. |
| Environments | The ACE project is staging until the first reviewed batch is approved. Production is either this project (after a security review) or a second project created at go-live. | Starter content is all `draft`; nothing is learner-published yet. |
| App | A separate Flutter web app in `ace/`, built with `--base-href /ace/` and served at `kidversity.app/ace`. | Own Supabase config, own branding and title, no shared singletons. Moving to a dedicated domain later is a rebuild with a different base href. |
| Hosting | Same Vercel project. The build script builds Kidversity into `build/web` and ACE into `build/web/ace`; `/ace/*` rewrites to `/ace/index.html`. | One deployment; no hosting change needed. |
| Content store | Postgres tables mirroring the starter JSON, imported by a repeatable script. | Matches the guide's step 3; stable IDs, versions and review states are preserved. |
| Answer protection | Answers, worked solutions, rubrics and numeric keys live in the `private` schema with no client access. Learners only reach them through server functions after submission (practice) or release (assessment). | "Never expose the private question file or unreleased answers." |
| Marking | Numeric final-answer check runs **in Postgres** (port of `numeric_check.py`). It never awards method marks. Written work goes to a teacher queue. | Deterministic, auditable, no extra service for milestone 1. |
| Maths | `flutter_math_fork` renders `$…$` LaTeX in lessons, questions and solutions; learners type workings with a live LaTeX preview. | KaTeX-equivalent rendering inside Flutter. |
| Uploads | Private Storage bucket `ace-workings`, path `<school>/<user>/<attempt>/…`, RLS by owner and the learner's teachers. | Handwritten photo/PDF workings, original preserved. |

## 2. Data model

Content (shared ACE bank; `school_id` null) and school-private content (`school_id` set) share tables:

- `sources`, `syllabus_profiles`, `topics`, `routes`, `channels`, `resources` — reference data from `sources.json`, `curriculum.json`, `channels.json`, `resource_catalogue.json`.
- `lessons` — explanation, worked example, objectives, common errors, exit check; `content_version`, `review_status`, provenance.
- `questions` — prompt, kind, marks, response format, **parts** (added; the starter has single-part items), order within lesson.
- `private.question_keys` — answer, worked solution, rubric, numeric answer, grading mode, per version.
- `private.content_versions` — immutable snapshot of every lesson/question version. Attempts reference the version answered.
- `import_runs` — who imported what, when, with counts.

Tenancy and people:

- `schools` (with `content_mode`: `staging` shows draft content to that school's users; `production` shows only `published`), `school_members` (student/teacher/admin), `school_channels` (what the school pays for), `cohorts` + `cohort_members` (a class in one channel).
- `profiles` (display name, platform role: learner, teacher, reviewer, platform admin).

Learning records:

- `attempts` — learner, school, question, **question version**, mode (practice/assessment), response (final answer, unit, workings text/LaTeX, part answers), attachments, `final_answer_status`, `marking_state` (`submitted`, `final_answer_checked`, `needs_review`, `teacher_marked`), awarded marks (null until a teacher marks), assisted flag.
- `attempt_reviews` — rubric marks per criterion, comments, reviewer, time.
- Topic progress is derived from attempts (no separate mutable score).
- School exam results stay separate from practice (later: reuse the Kidversity results/targets design).

Review workflow states: `draft → technical_check → subject_review → approved → published → archived`, with who/when on each step. A technical pass is never shown as human approval.

## 3. Phases and status

| Phase | Scope | Status |
|---|---|---|
| 0 | Plan; ACE Supabase project; `ace/` app shell at `/ace` with ACE branding | **[built]** this batch |
| 1 | Schema, private answer keys, versions, idempotent importer; starter content imported (4 channels, 8 lessons, 32 questions, 65 topics, 7 routes) | **[built]** this batch |
| 2 | Learner flow: sign in, join school with a code, channel → lessons → lesson (LaTeX) → question; submit final answer + unit + workings; server numeric check; worked solution in practice; retry; saved attempts | **[built]** core this batch; uploads **[next]** |
| 3 | Teacher review queue: rubric marking, comments, answer-release settings for assessments; approval workflow with audit | **[next]** |
| 4 | School content studio: author with preview, CSV/JSON import with preview, school-private by default; quiz builder (manual + automatic from approved, explicit shortfall); assessment mode | **[next]** |
| 5 | Acceptance: tenant isolation tests, answer-leak tests (no keys in responses or bundles), demo script for the six-step guide | **[next]** |
| 6 | AI explanations grounded in the approved solution (OpenAI Responses or Claude, server-side), SymPy worker for algebraic answers, DOCX/PDF import, handwriting transcription, AI draft generation | **[later]** |

Rough engineering effort to the first milestone (phases 0–5): 3–4 weeks.
Content authoring and subject review run in parallel and are not included.

## 4. Acceptance checks (from the developer brief)

1. AS/A2 channels and the Mathematics route filter select the right content; A2 keeps AS prerequisite links.
2. Learners submit equations, prose, diagrams and handwritten workings; multipart responses keep part mapping.
3. A correct final answer never earns method marks automatically; unsupported cases reach a teacher.
4. Worked solutions show at the right time; conflicts and unreadable work are not presented as certain.
5. School content imports through preview/review; selecting approved items is separate from creating new drafts.
6. Other schools cannot see private questions, uploads or results; unreleased keys never reach the browser.
7. Attempts, corrections, progress and reviewed marks are versioned and auditable.

## 5. Needed from LeadGame / Oxbridge

- Exam session and the Mathematics paper route (the route filter stays "pending" until then).
- De-duplicated learner roster and campus coverage (48 is subject enrolments).
- Named Mathematics and Physics reviewers to approve versions.
- AI provider decision and API key (phase 6 only).
- Rights confirmation before any third-party question bank (including Kidversity's existing WAEC/UTME source) is used in ACE.

## 6. Gaps in the starter data

- No multipart structure (the brief requires part mapping): the schema adds `parts`; importer maps each starter question to one part.
- No multiple-choice items (Physics Paper 1 is MCQ): `kind = 'multiple_choice'` is supported in the schema.
- No diagrams, no learning-outcome layer, rubrics mostly restate worked steps.
- Everything is `draft`; the official paper inventory is intentionally empty.

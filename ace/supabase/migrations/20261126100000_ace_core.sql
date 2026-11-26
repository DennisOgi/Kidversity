-- ACE core schema: reference data, content bank, private answer keys,
-- immutable content versions, schools/tenancy and learner attempts.
--
-- Access model
-- * Reference data (channels, profiles, topics, routes, sources, resources)
--   is readable by signed-in users.
-- * Lessons and questions are read only through ace_* functions, which apply
--   school entitlement, publication state and school-private rules.
-- * Answer keys and version snapshots live in the private schema. No client
--   role can read them; functions release them after an attempt (practice) or
--   after the teacher's release time (assessment).

CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;

-- Reference data ---------------------------------------------------------------

CREATE TABLE public.sources (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  url TEXT,
  checked_on DATE,
  access TEXT,
  bundled_content BOOLEAN NOT NULL DEFAULT FALSE,
  raw JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.syllabus_profiles (
  id TEXT PRIMARY KEY,
  board TEXT NOT NULL,
  qualification TEXT NOT NULL,
  subject TEXT NOT NULL,
  syllabus_code TEXT NOT NULL,
  exam_years INT[] NOT NULL DEFAULT '{}',
  status TEXT NOT NULL,
  syllabus_document_version INT,
  revision_published TEXT,
  source_ids TEXT[] NOT NULL DEFAULT '{}',
  raw JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.topics (
  id TEXT PRIMARY KEY,
  profile_id TEXT NOT NULL REFERENCES public.syllabus_profiles(id),
  syllabus_ref TEXT,
  title TEXT NOT NULL,
  paper_components TEXT[] NOT NULL DEFAULT '{}',
  stages TEXT[] NOT NULL DEFAULT '{}',
  scope TEXT,
  lesson_status TEXT,
  source_id TEXT REFERENCES public.sources(id),
  sort_order INT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX topics_profile_idx ON public.topics (profile_id, sort_order);
CREATE INDEX topics_source_idx ON public.topics (source_id);

CREATE TABLE public.routes (
  id TEXT PRIMARY KEY,
  profile_id TEXT NOT NULL REFERENCES public.syllabus_profiles(id),
  award TEXT NOT NULL,
  papers TEXT[] NOT NULL DEFAULT '{}',
  progresses_by_as_carry_forward BOOLEAN,
  raw JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX routes_profile_idx ON public.routes (profile_id);

CREATE TABLE public.channels (
  id TEXT PRIMARY KEY,
  group_label TEXT NOT NULL,
  stage TEXT NOT NULL CHECK (stage IN ('AS', 'A2')),
  subject TEXT NOT NULL,
  profile_id TEXT NOT NULL REFERENCES public.syllabus_profiles(id),
  sections TEXT[] NOT NULL DEFAULT '{}',
  publication_status TEXT NOT NULL DEFAULT 'staging',
  mathematics_route_filter_required BOOLEAN NOT NULL DEFAULT FALSE,
  as_prerequisite_links BOOLEAN NOT NULL DEFAULT FALSE,
  sort_order INT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX channels_profile_idx ON public.channels (profile_id);

CREATE TABLE public.resources (
  id TEXT PRIMARY KEY,
  source_id TEXT REFERENCES public.sources(id),
  profile_id TEXT REFERENCES public.syllabus_profiles(id),
  resource_type TEXT NOT NULL,
  delivery TEXT NOT NULL DEFAULT 'external_link',
  is_exam_paper BOOLEAN NOT NULL DEFAULT FALSE,
  rights_status TEXT NOT NULL,
  raw JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX resources_source_idx ON public.resources (source_id);
CREATE INDEX resources_profile_idx ON public.resources (profile_id);

-- Schools and people ------------------------------------------------------------

CREATE TABLE public.schools (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL CHECK (char_length(btrim(name)) BETWEEN 2 AND 120),
  slug TEXT UNIQUE,
  join_code TEXT NOT NULL UNIQUE,
  -- staging: this school's users also see draft content (pilot review).
  -- production: only published content.
  content_mode TEXT NOT NULL DEFAULT 'production'
    CHECK (content_mode IN ('staging', 'production')),
  mathematics_route_id TEXT REFERENCES public.routes(id),
  exam_session TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX schools_route_idx ON public.schools (mathematics_route_id);

CREATE TABLE public.profiles (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL DEFAULT '',
  platform_role TEXT NOT NULL DEFAULT 'member'
    CHECK (platform_role IN ('member', 'reviewer', 'platform_admin')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.school_members (
  school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('student', 'teacher', 'admin')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (school_id, user_id)
);
CREATE INDEX school_members_user_idx ON public.school_members (user_id);

-- Channels a school has bought.
CREATE TABLE public.school_channels (
  school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  channel_id TEXT NOT NULL REFERENCES public.channels(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (school_id, channel_id)
);
CREATE INDEX school_channels_channel_idx ON public.school_channels (channel_id);

-- A class/cohort studies one channel.
CREATE TABLE public.cohorts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  channel_id TEXT NOT NULL REFERENCES public.channels(id),
  name TEXT NOT NULL,
  teacher_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX cohorts_school_idx ON public.cohorts (school_id);
CREATE INDEX cohorts_channel_idx ON public.cohorts (channel_id);
CREATE INDEX cohorts_teacher_idx ON public.cohorts (teacher_id);

CREATE TABLE public.cohort_members (
  cohort_id UUID NOT NULL REFERENCES public.cohorts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (cohort_id, user_id)
);
CREATE INDEX cohort_members_user_idx ON public.cohort_members (user_id);

-- Content -------------------------------------------------------------------------

CREATE TABLE public.lessons (
  id TEXT PRIMARY KEY,
  school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE, -- null = shared ACE bank
  channel_id TEXT NOT NULL REFERENCES public.channels(id),
  profile_id TEXT NOT NULL REFERENCES public.syllabus_profiles(id),
  topic_id TEXT REFERENCES public.topics(id),
  stage TEXT NOT NULL CHECK (stage IN ('AS', 'A2')),
  title TEXT NOT NULL,
  minutes INT,
  objectives TEXT[] NOT NULL DEFAULT '{}',
  prerequisites TEXT[] NOT NULL DEFAULT '{}',
  explanation_markdown TEXT NOT NULL DEFAULT '',
  worked_example JSONB,
  common_errors TEXT[] NOT NULL DEFAULT '{}',
  exit_check TEXT,
  provenance TEXT NOT NULL,
  official_endorsement BOOLEAN NOT NULL DEFAULT FALSE,
  alignment_status TEXT,
  content_version INT NOT NULL CHECK (content_version >= 1),
  review_status TEXT NOT NULL DEFAULT 'draft' CHECK (review_status IN
    ('draft', 'technical_check', 'subject_review', 'approved', 'published', 'archived')),
  reviewer TEXT,
  reviewed_on DATE,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX lessons_channel_idx ON public.lessons (channel_id, sort_order);
CREATE INDEX lessons_school_idx ON public.lessons (school_id);
CREATE INDEX lessons_profile_idx ON public.lessons (profile_id);
CREATE INDEX lessons_topic_idx ON public.lessons (topic_id);

CREATE TABLE public.questions (
  id TEXT PRIMARY KEY,
  school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
  lesson_id TEXT REFERENCES public.lessons(id) ON DELETE SET NULL,
  channel_id TEXT NOT NULL REFERENCES public.channels(id),
  profile_id TEXT NOT NULL REFERENCES public.syllabus_profiles(id),
  topic_id TEXT REFERENCES public.topics(id),
  stage TEXT NOT NULL CHECK (stage IN ('AS', 'A2')),
  kind TEXT NOT NULL CHECK (kind IN ('numeric', 'constructed_response', 'multiple_choice')),
  prompt_markdown TEXT NOT NULL,
  -- Numbered parts, e.g. [{"label":"a","prompt_markdown":"...","marks":2}].
  -- Starter questions are single-part.
  parts JSONB NOT NULL DEFAULT '[]'::jsonb,
  -- Multiple choice options shown to learners (no key here).
  options JSONB,
  max_marks INT NOT NULL CHECK (max_marks >= 0),
  answer_unit TEXT, -- the unit learners answer in (shown); not a secret
  difficulty TEXT,
  provenance TEXT NOT NULL,
  is_past_paper BOOLEAN NOT NULL DEFAULT FALSE,
  exam_mode_response TEXT,
  workings_required_for_exam_mode BOOLEAN NOT NULL DEFAULT FALSE,
  content_version INT NOT NULL CHECK (content_version >= 1),
  review_status TEXT NOT NULL DEFAULT 'draft' CHECK (review_status IN
    ('draft', 'technical_check', 'subject_review', 'approved', 'published', 'archived')),
  reviewer TEXT,
  reviewed_on DATE,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX questions_lesson_idx ON public.questions (lesson_id, sort_order);
CREATE INDEX questions_channel_idx ON public.questions (channel_id);
CREATE INDEX questions_school_idx ON public.questions (school_id);
CREATE INDEX questions_profile_idx ON public.questions (profile_id);
CREATE INDEX questions_topic_idx ON public.questions (topic_id);

-- Server-only answer keys, per question version.
CREATE TABLE private.question_keys (
  question_id TEXT NOT NULL REFERENCES public.questions(id) ON DELETE CASCADE,
  content_version INT NOT NULL,
  answer_markdown TEXT,
  worked_solution JSONB NOT NULL DEFAULT '[]'::jsonb,
  rubric JSONB NOT NULL DEFAULT '[]'::jsonb,
  numeric_answer JSONB,
  correct_option TEXT,
  grading TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (question_id, content_version)
);

-- Immutable snapshot of every imported/edited version.
CREATE TABLE private.content_versions (
  kind TEXT NOT NULL CHECK (kind IN ('lesson', 'question')),
  id TEXT NOT NULL,
  content_version INT NOT NULL,
  snapshot JSONB NOT NULL,
  snapshot_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (kind, id, content_version)
);

CREATE TABLE private.import_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  package TEXT NOT NULL,
  package_version TEXT NOT NULL,
  counts JSONB NOT NULL DEFAULT '{}'::jsonb,
  imported_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Learner attempts ---------------------------------------------------------------

CREATE TABLE public.attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  school_id UUID REFERENCES public.schools(id) ON DELETE SET NULL,
  question_id TEXT NOT NULL REFERENCES public.questions(id),
  question_version INT NOT NULL,
  attempt_no INT NOT NULL,
  mode TEXT NOT NULL CHECK (mode IN ('practice', 'assessment')),
  -- {"final_answer": 12, "unit": null, "working_text": "...", "parts": {...}}
  response JSONB NOT NULL,
  attachment_paths TEXT[] NOT NULL DEFAULT '{}',
  final_answer_status TEXT NOT NULL CHECK (final_answer_status IN
    ('final_answer_match', 'try_again', 'unit_mismatch', 'invalid_numeric_input',
     'option_match', 'option_wrong', 'not_auto_checked')),
  marking_state TEXT NOT NULL CHECK (marking_state IN
    ('submitted', 'final_answer_checked', 'needs_review', 'teacher_marked')),
  awarded_marks NUMERIC(6, 2), -- only ever set by a teacher review
  assisted BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX attempts_user_idx ON public.attempts (user_id, question_id, created_at);
CREATE INDEX attempts_question_idx ON public.attempts (question_id);
CREATE INDEX attempts_school_idx ON public.attempts (school_id, marking_state);

CREATE TABLE public.attempt_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  attempt_id UUID NOT NULL REFERENCES public.attempts(id) ON DELETE CASCADE,
  reviewer_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  criterion_marks JSONB NOT NULL DEFAULT '[]'::jsonb,
  awarded_marks NUMERIC(6, 2) NOT NULL,
  comment TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX attempt_reviews_attempt_idx ON public.attempt_reviews (attempt_id);
CREATE INDEX attempt_reviews_reviewer_idx ON public.attempt_reviews (reviewer_id);

-- RLS -----------------------------------------------------------------------------

ALTER TABLE public.sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.syllabus_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.topics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.resources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.schools ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cohorts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cohort_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attempt_reviews ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL TABLES IN SCHEMA private FROM PUBLIC, anon, authenticated;

GRANT SELECT ON public.sources, public.syllabus_profiles, public.topics,
  public.routes, public.channels, public.resources TO authenticated;
CREATE POLICY "Signed-in users read sources" ON public.sources FOR SELECT TO authenticated USING (true);
CREATE POLICY "Signed-in users read profiles" ON public.syllabus_profiles FOR SELECT TO authenticated USING (true);
CREATE POLICY "Signed-in users read topics" ON public.topics FOR SELECT TO authenticated USING (true);
CREATE POLICY "Signed-in users read routes" ON public.routes FOR SELECT TO authenticated USING (true);
CREATE POLICY "Signed-in users read channels" ON public.channels FOR SELECT TO authenticated USING (true);
CREATE POLICY "Signed-in users read resources" ON public.resources FOR SELECT TO authenticated USING (true);

GRANT SELECT ON public.profiles TO authenticated;
GRANT UPDATE (display_name) ON public.profiles TO authenticated;
CREATE POLICY "Users read own profile" ON public.profiles FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));
CREATE POLICY "Users rename themselves" ON public.profiles FOR UPDATE TO authenticated
  USING (user_id = (SELECT auth.uid())) WITH CHECK (user_id = (SELECT auth.uid()));

-- Everything else goes through the functions below.

-- New users get a profile.
CREATE OR REPLACE FUNCTION private.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, private
AS $$
BEGIN
  INSERT INTO public.profiles (user_id, display_name)
  VALUES (
    NEW.id,
    left(btrim(COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1), '')), 80)
  )
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.handle_new_user() FROM PUBLIC, anon, authenticated;

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION private.handle_new_user();

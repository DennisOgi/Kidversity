-- Kidversity Plan B production baseline 1/5.
-- Core auth profiles, classes, and live Mandarin quizzes.
-- Safe to re-run against the empty-project baseline.

CREATE SCHEMA IF NOT EXISTS private;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;

CREATE TABLE IF NOT EXISTS public.user_profiles (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL,
  avatar_emoji TEXT NOT NULL DEFAULT '🦊',
  role TEXT CHECK (role IN ('student', 'teacher', 'reviewer')),
  onboarding_complete BOOLEAN NOT NULL DEFAULT FALSE,
  age INTEGER CHECK (age BETWEEN 7 AND 120),
  gender TEXT,
  guardian_email TEXT,
  parental_consent_at TIMESTAMPTZ,
  terms_accepted_at TIMESTAMPTZ,
  level INTEGER NOT NULL DEFAULT 1 CHECK (level >= 1),
  xp INTEGER NOT NULL DEFAULT 0 CHECK (xp >= 0),
  streak_days INTEGER NOT NULL DEFAULT 0 CHECK (streak_days >= 0),
  last_activity_date DATE,
  lessons_completed INTEGER NOT NULL DEFAULT 0 CHECK (lessons_completed >= 0),
  minutes_learned INTEGER NOT NULL DEFAULT 0 CHECK (minutes_learned >= 0),
  preferences JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.classes (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  name TEXT NOT NULL,
  teacher_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  description TEXT,
  grade_level INTEGER,
  join_code TEXT UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.class_members (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  class_id UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (class_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.live_tests (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  teacher_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  class_id UUID REFERENCES public.classes(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  subject TEXT NOT NULL DEFAULT 'Mandarin',
  duration_seconds INTEGER NOT NULL DEFAULT 300 CHECK (duration_seconds >= 60),
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'live', 'ended')),
  join_code TEXT UNIQUE,
  started_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.live_test_questions (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  test_id UUID NOT NULL REFERENCES public.live_tests(id) ON DELETE CASCADE,
  order_index INTEGER NOT NULL DEFAULT 0 CHECK (order_index >= 0),
  prompt TEXT NOT NULL,
  options JSONB NOT NULL DEFAULT '[]'::jsonb,
  points INTEGER NOT NULL DEFAULT 1 CHECK (points > 0),
  UNIQUE (test_id, order_index),
  UNIQUE (id, test_id)
);

CREATE TABLE IF NOT EXISTS public.live_test_participants (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  test_id UUID NOT NULL REFERENCES public.live_tests(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT,
  avatar_emoji TEXT NOT NULL DEFAULT '🦊',
  status TEXT NOT NULL DEFAULT 'waiting'
    CHECK (status IN ('waiting', 'active', 'submitted')),
  score INTEGER NOT NULL DEFAULT 0 CHECK (score >= 0),
  correct_count INTEGER NOT NULL DEFAULT 0 CHECK (correct_count >= 0),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  submitted_at TIMESTAMPTZ,
  UNIQUE (test_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.live_test_answers (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  test_id UUID NOT NULL REFERENCES public.live_tests(id) ON DELETE CASCADE,
  question_id UUID NOT NULL REFERENCES public.live_test_questions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  selected_option_id TEXT,
  is_correct BOOLEAN NOT NULL DEFAULT FALSE,
  answered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (test_id, question_id, user_id),
  FOREIGN KEY (question_id, test_id)
    REFERENCES public.live_test_questions(id, test_id)
    ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_classes_teacher
  ON public.classes(teacher_id);
CREATE INDEX IF NOT EXISTS idx_class_members_class
  ON public.class_members(class_id);
CREATE INDEX IF NOT EXISTS idx_class_members_user
  ON public.class_members(user_id);
CREATE INDEX IF NOT EXISTS idx_live_tests_teacher_created
  ON public.live_tests(teacher_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_live_tests_class_status
  ON public.live_tests(class_id, status);
CREATE INDEX IF NOT EXISTS idx_live_test_questions_test_order
  ON public.live_test_questions(test_id, order_index);
CREATE INDEX IF NOT EXISTS idx_live_test_participants_test
  ON public.live_test_participants(test_id);
CREATE INDEX IF NOT EXISTS idx_live_test_participants_user
  ON public.live_test_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_live_test_answers_test
  ON public.live_test_answers(test_id);
CREATE INDEX IF NOT EXISTS idx_live_test_answers_user
  ON public.live_test_answers(user_id);

ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.class_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_tests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_test_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_test_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_test_answers ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.live_tests REPLICA IDENTITY FULL;
ALTER TABLE public.live_test_participants REPLICA IDENTITY FULL;
ALTER TABLE public.live_test_answers REPLICA IDENTITY FULL;

DO $$
DECLARE
  relation_name TEXT;
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  ) THEN
    FOREACH relation_name IN ARRAY ARRAY[
      'live_tests',
      'live_test_participants',
      'live_test_answers'
    ]
    LOOP
      IF NOT EXISTS (
        SELECT 1
        FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public'
          AND tablename = relation_name
      ) THEN
        EXECUTE format(
          'ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',
          relation_name
        );
      END IF;
    END LOOP;
  END IF;
END;
$$;

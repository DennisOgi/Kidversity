-- Kidversity Plan B production baseline 2/5.
-- Foundation curriculum, reviewed content, audio metadata, and learner results.

CREATE TABLE IF NOT EXISTS public.reviewer_accounts (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  provisioned_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.courses (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  level TEXT NOT NULL,
  target_age TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.course_modules (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  course_id TEXT NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  sequence INTEGER NOT NULL CHECK (sequence > 0),
  title TEXT NOT NULL,
  subtitle TEXT NOT NULL DEFAULT '',
  quest_lesson_id TEXT,
  UNIQUE (course_id, sequence)
);

CREATE TABLE IF NOT EXISTS public.course_lessons (
  id TEXT PRIMARY KEY,
  course_id TEXT NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  module_sequence INTEGER NOT NULL CHECK (module_sequence > 0),
  sequence INTEGER NOT NULL CHECK (sequence > 0),
  title TEXT NOT NULL,
  objective TEXT NOT NULL DEFAULT '',
  explanation TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'shell'
    CHECK (status IN ('shell', 'ready', 'in_review', 'approved')),
  xp_reward INTEGER NOT NULL DEFAULT 100 CHECK (xp_reward >= 0),
  metadata_review_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (metadata_review_status IN ('pending', 'approved', 'corrected', 'rejected')),
  submitted_at TIMESTAMPTZ,
  published_at TIMESTAMPTZ,
  published_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (course_id, sequence),
  UNIQUE (course_id, module_sequence, sequence)
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'course_modules_quest_lesson_id_fkey'
      AND conrelid = 'public.course_modules'::regclass
  ) THEN
    ALTER TABLE public.course_modules
      ADD CONSTRAINT course_modules_quest_lesson_id_fkey
      FOREIGN KEY (quest_lesson_id)
      REFERENCES public.course_lessons(id)
      ON DELETE SET NULL;
  END IF;
END;
$$;

CREATE TABLE IF NOT EXISTS public.content_sources (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  source_name TEXT NOT NULL,
  url TEXT,
  licence TEXT NOT NULL,
  dataset_version TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.vocab_items (
  id TEXT PRIMARY KEY,
  lesson_id TEXT NOT NULL REFERENCES public.course_lessons(id) ON DELETE CASCADE,
  simplified_chinese TEXT NOT NULL,
  pinyin TEXT NOT NULL,
  english_meaning TEXT NOT NULL,
  part_of_speech TEXT NOT NULL DEFAULT '',
  source_id UUID NOT NULL REFERENCES public.content_sources(id),
  review_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (review_status IN ('pending', 'approved', 'corrected', 'rejected')),
  sequence INTEGER NOT NULL DEFAULT 0 CHECK (sequence >= 0),
  UNIQUE (lesson_id, sequence)
);

CREATE TABLE IF NOT EXISTS public.examples (
  id TEXT PRIMARY KEY,
  lesson_id TEXT NOT NULL REFERENCES public.course_lessons(id) ON DELETE CASCADE,
  chinese TEXT NOT NULL,
  pinyin TEXT NOT NULL,
  english TEXT NOT NULL,
  source_id UUID NOT NULL REFERENCES public.content_sources(id),
  review_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (review_status IN ('pending', 'approved', 'corrected', 'rejected')),
  sequence INTEGER NOT NULL DEFAULT 0 CHECK (sequence >= 0),
  UNIQUE (lesson_id, sequence)
);

CREATE TABLE IF NOT EXISTS public.grammar_patterns (
  id TEXT PRIMARY KEY,
  lesson_id TEXT NOT NULL REFERENCES public.course_lessons(id) ON DELETE CASCADE,
  pattern TEXT NOT NULL,
  explanation TEXT NOT NULL,
  chinese TEXT NOT NULL,
  pinyin TEXT NOT NULL,
  english TEXT NOT NULL,
  source_id UUID NOT NULL REFERENCES public.content_sources(id),
  review_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (review_status IN ('pending', 'approved', 'corrected', 'rejected'))
);

CREATE TABLE IF NOT EXISTS public.dialogues (
  id TEXT PRIMARY KEY,
  lesson_id TEXT NOT NULL REFERENCES public.course_lessons(id) ON DELETE CASCADE,
  speaker TEXT NOT NULL,
  chinese TEXT NOT NULL,
  pinyin TEXT NOT NULL,
  english TEXT NOT NULL,
  source_id UUID NOT NULL REFERENCES public.content_sources(id),
  review_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (review_status IN ('pending', 'approved', 'corrected', 'rejected')),
  sequence INTEGER NOT NULL DEFAULT 0 CHECK (sequence >= 0),
  UNIQUE (lesson_id, sequence)
);

CREATE TABLE IF NOT EXISTS public.activities (
  id TEXT PRIMARY KEY,
  lesson_id TEXT NOT NULL REFERENCES public.course_lessons(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('listen_tap', 'match', 'mcq', 'fill_blank')),
  prompt TEXT NOT NULL,
  answer TEXT NOT NULL,
  distractors JSONB NOT NULL DEFAULT '[]'::jsonb,
  explanation TEXT NOT NULL DEFAULT '',
  difficulty INTEGER NOT NULL DEFAULT 1 CHECK (difficulty BETWEEN 1 AND 5),
  source_id UUID NOT NULL REFERENCES public.content_sources(id),
  review_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (review_status IN ('pending', 'approved', 'corrected', 'rejected')),
  sequence INTEGER NOT NULL DEFAULT 0 CHECK (sequence >= 0),
  UNIQUE (lesson_id, sequence)
);

CREATE TABLE IF NOT EXISTS public.assessment_items (
  id TEXT PRIMARY KEY,
  lesson_id TEXT NOT NULL REFERENCES public.course_lessons(id) ON DELETE CASCADE,
  question TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('listen_tap', 'match', 'mcq', 'fill_blank')),
  correct_answer TEXT NOT NULL,
  distractors JSONB NOT NULL DEFAULT '[]'::jsonb,
  explanation TEXT NOT NULL,
  source_id UUID NOT NULL REFERENCES public.content_sources(id),
  review_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (review_status IN ('pending', 'approved', 'corrected', 'rejected')),
  sequence INTEGER NOT NULL DEFAULT 0 CHECK (sequence >= 0),
  UNIQUE (lesson_id, sequence)
);

CREATE TABLE IF NOT EXISTS public.audio_clips (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  lesson_id TEXT NOT NULL REFERENCES public.course_lessons(id) ON DELETE CASCADE,
  item_type TEXT NOT NULL,
  item_id TEXT NOT NULL,
  audio_text TEXT NOT NULL,
  speech_lang TEXT NOT NULL DEFAULT 'zh-CN',
  audio_url TEXT,
  storage_path TEXT,
  voice TEXT,
  provider TEXT,
  text_hash TEXT,
  generated_at TIMESTAMPTZ,
  source_id UUID NOT NULL REFERENCES public.content_sources(id),
  review_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (review_status IN ('pending', 'approved', 'corrected', 'rejected')),
  UNIQUE (lesson_id, item_type, item_id)
);

CREATE TABLE IF NOT EXISTS public.curriculum_constraints (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  course_id TEXT NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  tag TEXT NOT NULL,
  description TEXT NOT NULL,
  level TEXT NOT NULL DEFAULT 'beginner',
  vocabulary_or_character TEXT,
  grammar_point TEXT,
  language_function TEXT,
  listening_competency TEXT,
  speaking_competency TEXT,
  reading_competency TEXT,
  writing_competency TEXT,
  source_id UUID NOT NULL REFERENCES public.content_sources(id),
  verification_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (verification_status IN ('pending', 'verified', 'rejected')),
  UNIQUE (course_id, tag)
);

CREATE TABLE IF NOT EXISTS public.staged_sentences (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  simplified_chinese TEXT NOT NULL,
  pinyin TEXT,
  english_translation TEXT NOT NULL,
  estimated_level TEXT NOT NULL DEFAULT 'beginner',
  source_id UUID NOT NULL REFERENCES public.content_sources(id),
  review_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (review_status IN ('pending', 'approved', 'corrected', 'rejected')),
  imported_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.speech_assets (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  transcript TEXT NOT NULL,
  audio_url TEXT NOT NULL,
  language_code TEXT NOT NULL DEFAULT 'zh-CN',
  intended_use TEXT NOT NULL DEFAULT 'asr_evaluation'
    CHECK (intended_use IN ('asr_evaluation', 'pronunciation_research')),
  source_id UUID NOT NULL REFERENCES public.content_sources(id),
  review_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (review_status IN ('pending', 'approved', 'corrected', 'rejected'))
);

CREATE TABLE IF NOT EXISTS public.tts_provider_evaluations (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  provider TEXT NOT NULL CHECK (provider IN ('google', 'azure')),
  voice TEXT NOT NULL,
  test_text TEXT NOT NULL,
  pronunciation_score INTEGER CHECK (pronunciation_score BETWEEN 1 AND 5),
  tone_score INTEGER CHECK (tone_score BETWEEN 1 AND 5),
  naturalness_score INTEGER CHECK (naturalness_score BETWEEN 1 AND 5),
  latency_ms INTEGER CHECK (latency_ms >= 0),
  estimated_cost NUMERIC CHECK (estimated_cost >= 0),
  reviewer_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  notes TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.review_events (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  item_type TEXT NOT NULL,
  item_id TEXT NOT NULL,
  reviewer_id UUID NOT NULL REFERENCES auth.users(id),
  verdict TEXT NOT NULL CHECK (verdict IN ('approved', 'corrected', 'rejected')),
  notes TEXT NOT NULL DEFAULT '',
  version INTEGER NOT NULL DEFAULT 1 CHECK (version > 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (item_type, item_id, version)
);

CREATE TABLE IF NOT EXISTS public.lesson_results (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  lesson_id TEXT NOT NULL REFERENCES public.course_lessons(id) ON DELETE CASCADE,
  score INTEGER NOT NULL CHECK (score BETWEEN 0 AND 100),
  answers JSONB NOT NULL DEFAULT '[]'::jsonb,
  completed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, lesson_id)
);

CREATE INDEX IF NOT EXISTS idx_course_lessons_course_sequence
  ON public.course_lessons(course_id, sequence);
CREATE INDEX IF NOT EXISTS idx_vocab_lesson_sequence
  ON public.vocab_items(lesson_id, sequence);
CREATE INDEX IF NOT EXISTS idx_examples_lesson_sequence
  ON public.examples(lesson_id, sequence);
CREATE INDEX IF NOT EXISTS idx_dialogues_lesson_sequence
  ON public.dialogues(lesson_id, sequence);
CREATE INDEX IF NOT EXISTS idx_activities_lesson_sequence
  ON public.activities(lesson_id, sequence);
CREATE INDEX IF NOT EXISTS idx_assessments_lesson_sequence
  ON public.assessment_items(lesson_id, sequence);
CREATE INDEX IF NOT EXISTS idx_audio_clips_lesson
  ON public.audio_clips(lesson_id);
CREATE INDEX IF NOT EXISTS idx_review_events_item
  ON public.review_events(item_type, item_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_lesson_results_user
  ON public.lesson_results(user_id, completed_at DESC);
CREATE INDEX IF NOT EXISTS idx_lesson_results_lesson
  ON public.lesson_results(lesson_id);

ALTER TABLE public.reviewer_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.course_modules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.course_lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vocab_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.examples ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grammar_patterns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dialogues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assessment_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audio_clips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.curriculum_constraints ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staged_sentences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.speech_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tts_provider_evaluations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.review_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lesson_results ENABLE ROW LEVEL SECURITY;

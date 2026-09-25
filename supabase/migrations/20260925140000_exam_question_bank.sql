-- Past questions are stored as papers: one exam + subject + year
-- (+ university for Post-UTME). Practice never mixes years or exams.

CREATE TABLE IF NOT EXISTS public.exam_bank_exams (
  slug TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  sdash_id INTEGER
);

CREATE TABLE IF NOT EXISTS public.exam_bank_subjects (
  slug TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  sdash_id INTEGER
);

CREATE TABLE IF NOT EXISTS public.exam_bank_years (
  year INTEGER PRIMARY KEY CHECK (year BETWEEN 1980 AND 2100)
);

CREATE TABLE IF NOT EXISTS public.exam_bank_papers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  exam_slug TEXT NOT NULL CHECK (exam_slug ~ '^[a-z0-9-]{1,40}$'),
  subject_slug TEXT NOT NULL CHECK (subject_slug ~ '^[a-z0-9-]{1,40}$'),
  exam_year INTEGER NOT NULL CHECK (exam_year BETWEEN 1980 AND 2100),
  university TEXT NOT NULL DEFAULT '',
  question_count INTEGER NOT NULL DEFAULT 0 CHECK (question_count >= 0),
  exhausted BOOLEAN NOT NULL DEFAULT FALSE,
  empty_streak INTEGER NOT NULL DEFAULT 0,
  last_harvested_at TIMESTAMPTZ,
  UNIQUE (exam_slug, subject_slug, exam_year, university)
);

CREATE TABLE IF NOT EXISTS public.exam_bank_questions (
  id INTEGER PRIMARY KEY,
  paper_id UUID REFERENCES public.exam_bank_papers(id) ON DELETE SET NULL,
  exam_slug TEXT NOT NULL,
  exam_label TEXT NOT NULL,
  subject_slug TEXT NOT NULL,
  exam_year TEXT NOT NULL,
  university TEXT,
  payload JSONB NOT NULL,
  ingested_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS exam_bank_questions_paper_idx
  ON public.exam_bank_questions (paper_id);

CREATE INDEX IF NOT EXISTS exam_bank_questions_lookup_idx
  ON public.exam_bank_questions (exam_slug, subject_slug, exam_year);

CREATE INDEX IF NOT EXISTS exam_bank_papers_lookup_idx
  ON public.exam_bank_papers (exam_slug, subject_slug, exam_year DESC);

ALTER TABLE public.exam_bank_exams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_bank_subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_bank_years ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_bank_papers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_bank_questions ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.exam_bank_exams, public.exam_bank_subjects,
  public.exam_bank_years, public.exam_bank_papers,
  public.exam_bank_questions FROM PUBLIC, anon;

GRANT SELECT ON public.exam_bank_exams, public.exam_bank_subjects,
  public.exam_bank_years, public.exam_bank_papers,
  public.exam_bank_questions TO authenticated;

CREATE POLICY "Signed-in users read exam bank exams"
  ON public.exam_bank_exams
  FOR SELECT TO authenticated
  USING (TRUE);

CREATE POLICY "Signed-in users read exam bank subjects"
  ON public.exam_bank_subjects
  FOR SELECT TO authenticated
  USING (TRUE);

CREATE POLICY "Signed-in users read exam bank years"
  ON public.exam_bank_years
  FOR SELECT TO authenticated
  USING (TRUE);

CREATE POLICY "Signed-in users read exam bank papers"
  ON public.exam_bank_papers
  FOR SELECT TO authenticated
  USING (TRUE);

CREATE POLICY "Signed-in users read exam bank questions"
  ON public.exam_bank_questions
  FOR SELECT TO authenticated
  USING (TRUE);

INSERT INTO public.exam_bank_exams (slug, name, sdash_id) VALUES
  ('utme', 'UTME', 1),
  ('wassce', 'WASSCE', 2),
  ('neco', 'NECO', 3),
  ('post-utme', 'Post-UTME', 4),
  ('university', 'University', 5)
ON CONFLICT (slug) DO UPDATE
SET name = EXCLUDED.name,
    sdash_id = COALESCE(public.exam_bank_exams.sdash_id, EXCLUDED.sdash_id);

INSERT INTO public.exam_bank_subjects (slug, name, sdash_id) VALUES
  ('accounting', 'Accounting', NULL),
  ('agriculture', 'Agriculture', NULL),
  ('arabic', 'Arabic Studies', NULL),
  ('biology', 'Biology', NULL),
  ('chemistry', 'Chemistry', NULL),
  ('civiledu', 'Civic Education', NULL),
  ('commerce', 'Commerce', NULL),
  ('computer', 'Computer Studies', NULL),
  ('crk', 'CRK', NULL),
  ('currentaffairs', 'Current Affairs', NULL),
  ('economics', 'Economics', NULL),
  ('english', 'English Language', NULL),
  ('englishlit', 'English Literature', NULL),
  ('fineart', 'Fine Art', NULL),
  ('geography', 'Geography', NULL),
  ('geology', 'Geology', NULL),
  ('government', 'Government', NULL),
  ('hausa', 'Hausa', NULL),
  ('history', 'History', NULL),
  ('homeeconomics', 'Home Economics', NULL),
  ('igbo', 'Igbo', NULL),
  ('insurance', 'Insurance', NULL),
  ('irk', 'IRK', NULL),
  ('mathematics', 'Mathematics', NULL),
  ('music', 'Music', NULL),
  ('physics', 'Physics', NULL),
  ('yoruba', 'Yoruba', NULL)
ON CONFLICT (slug) DO UPDATE
SET name = EXCLUDED.name;

INSERT INTO public.exam_bank_years (year)
SELECT year FROM generate_series(1988, 2026) AS year
ON CONFLICT (year) DO NOTHING;

CREATE OR REPLACE FUNCTION public.exam_bank_pick_paper(
  p_exam_slug TEXT,
  p_subject_slug TEXT,
  p_year INTEGER DEFAULT NULL,
  p_university TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT COALESCE(
    (
      SELECT jsonb_build_object(
        'year', paper.exam_year,
        'count', paper.question_count,
        'university', paper.university
      )
      FROM public.exam_bank_papers AS paper
      WHERE paper.exam_slug = p_exam_slug
        AND paper.subject_slug = p_subject_slug
        AND paper.question_count > 0
        AND (p_year IS NULL OR paper.exam_year = p_year)
        AND (
          p_university IS NULL
          OR btrim(p_university) = ''
          OR lower(paper.university) = lower(p_university)
        )
      ORDER BY paper.exam_year DESC, paper.question_count DESC
      LIMIT 1
    ),
    'null'::jsonb
  );
$$;

CREATE OR REPLACE FUNCTION public.exam_bank_draw(
  p_exam_slug TEXT,
  p_subject_slug TEXT,
  p_limit INTEGER DEFAULT 10,
  p_year TEXT DEFAULT NULL,
  p_university TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  WITH chosen AS (
    SELECT (public.exam_bank_pick_paper(
      p_exam_slug,
      p_subject_slug,
      CASE
        WHEN p_year IS NULL OR btrim(p_year) = '' THEN NULL
        ELSE p_year::integer
      END,
      p_university
    )->>'year')::integer AS exam_year
  )
  SELECT COALESCE(jsonb_agg(picked.payload), '[]'::jsonb)
  FROM (
    SELECT question.payload
    FROM public.exam_bank_questions AS question
    JOIN chosen ON chosen.exam_year IS NOT NULL
    WHERE question.exam_slug = p_exam_slug
      AND question.subject_slug = p_subject_slug
      AND question.exam_year = chosen.exam_year::text
      AND (
        p_university IS NULL
        OR btrim(p_university) = ''
        OR lower(COALESCE(question.university, '')) = lower(p_university)
      )
    ORDER BY random()
    LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 10), 50))
  ) AS picked;
$$;

CREATE OR REPLACE FUNCTION public.exam_bank_ensure_paper(
  p_exam_slug TEXT,
  p_subject_slug TEXT,
  p_year INTEGER,
  p_university TEXT DEFAULT ''
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  paper_id UUID;
  uni TEXT := lower(btrim(COALESCE(p_university, '')));
BEGIN
  INSERT INTO public.exam_bank_papers (
    exam_slug, subject_slug, exam_year, university
  ) VALUES (
    p_exam_slug, p_subject_slug, p_year, uni
  )
  ON CONFLICT (exam_slug, subject_slug, exam_year, university)
  DO UPDATE SET exam_slug = EXCLUDED.exam_slug
  RETURNING id INTO paper_id;
  RETURN paper_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.exam_bank_upsert(p_rows JSONB)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  item JSONB;
  written INTEGER := 0;
  question_id INTEGER;
  exam_slug TEXT;
  subject_slug TEXT;
  answer_key TEXT;
  year_text TEXT;
  year_value INTEGER;
  paper_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;
  IF p_rows IS NULL OR jsonb_typeof(p_rows) <> 'array' THEN
    RETURN 0;
  END IF;

  FOR item IN SELECT value FROM jsonb_array_elements(p_rows)
  LOOP
    question_id := COALESCE((item->>'id')::integer, 0);
    exam_slug := lower(btrim(COALESCE(item->>'exam_slug', '')));
    subject_slug := lower(btrim(COALESCE(item->>'subject_slug', '')));
    answer_key := lower(btrim(COALESCE(item->>'answer', '')));
    year_text := btrim(COALESCE(item->>'examyear', ''));

    IF question_id <= 0 THEN
      CONTINUE;
    END IF;
    IF exam_slug = '' OR exam_slug !~ '^[a-z0-9-]{1,40}$' THEN
      CONTINUE;
    END IF;
    IF subject_slug = '' OR subject_slug !~ '^[a-z0-9-]{1,40}$' THEN
      CONTINUE;
    END IF;
    IF year_text !~ '^[0-9]{4}$' THEN
      CONTINUE;
    END IF;
    year_value := year_text::integer;
    IF COALESCE(item->>'question', '') = '' THEN
      CONTINUE;
    END IF;
    IF jsonb_typeof(item->'option') <> 'object' THEN
      CONTINUE;
    END IF;
    IF answer_key !~ '^[a-e]$' THEN
      CONTINUE;
    END IF;

    paper_id := public.exam_bank_ensure_paper(
      exam_slug,
      subject_slug,
      year_value,
      COALESCE(item->>'university', '')
    );

    INSERT INTO public.exam_bank_questions (
      id,
      paper_id,
      exam_slug,
      exam_label,
      subject_slug,
      exam_year,
      university,
      payload,
      ingested_at
    ) VALUES (
      question_id,
      paper_id,
      exam_slug,
      COALESCE(NULLIF(btrim(item->>'examtype'), ''), exam_slug),
      subject_slug,
      year_text,
      NULLIF(btrim(item->>'university'), ''),
      item,
      now()
    )
    ON CONFLICT (id) DO UPDATE
    SET paper_id = EXCLUDED.paper_id,
        exam_slug = EXCLUDED.exam_slug,
        exam_label = EXCLUDED.exam_label,
        subject_slug = EXCLUDED.subject_slug,
        exam_year = EXCLUDED.exam_year,
        university = EXCLUDED.university,
        payload = EXCLUDED.payload,
        ingested_at = now();

    written := written + 1;
  END LOOP;

  UPDATE public.exam_bank_papers AS paper
  SET question_count = (
    SELECT count(*)::integer
    FROM public.exam_bank_questions AS question
    WHERE question.paper_id = paper.id
  )
  WHERE paper.id IN (
    SELECT DISTINCT question.paper_id
    FROM public.exam_bank_questions AS question
    WHERE question.paper_id IS NOT NULL
      AND question.ingested_at > now() - interval '2 minutes'
  );

  RETURN written;
END;
$$;

CREATE OR REPLACE FUNCTION public.exam_bank_replace_catalog(
  p_exams JSONB,
  p_subjects JSONB,
  p_years JSONB
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  item JSONB;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  IF jsonb_typeof(p_exams) = 'array' THEN
    FOR item IN SELECT value FROM jsonb_array_elements(p_exams)
    LOOP
      IF COALESCE(item->>'slug', '') ~ '^[a-z0-9-]{1,40}$' THEN
        INSERT INTO public.exam_bank_exams (slug, name, sdash_id)
        VALUES (
          item->>'slug',
          COALESCE(NULLIF(btrim(item->>'name'), ''), item->>'slug'),
          (item->>'id')::integer
        )
        ON CONFLICT (slug) DO UPDATE
        SET name = EXCLUDED.name,
            sdash_id = COALESCE(EXCLUDED.sdash_id, public.exam_bank_exams.sdash_id);
      END IF;
    END LOOP;
  END IF;

  IF jsonb_typeof(p_subjects) = 'array' THEN
    FOR item IN SELECT value FROM jsonb_array_elements(p_subjects)
    LOOP
      IF COALESCE(item->>'slug', '') ~ '^[a-z0-9-]{1,40}$' THEN
        INSERT INTO public.exam_bank_subjects (slug, name, sdash_id)
        VALUES (
          item->>'slug',
          COALESCE(NULLIF(btrim(item->>'name'), ''), item->>'slug'),
          (item->>'id')::integer
        )
        ON CONFLICT (slug) DO UPDATE
        SET name = EXCLUDED.name,
            sdash_id = COALESCE(EXCLUDED.sdash_id, public.exam_bank_subjects.sdash_id);
      END IF;
    END LOOP;
  END IF;

  IF jsonb_typeof(p_years) = 'array' THEN
    INSERT INTO public.exam_bank_years (year)
    SELECT value::integer
    FROM jsonb_array_elements_text(p_years)
    WHERE value ~ '^[0-9]{4}$'
    ON CONFLICT (year) DO NOTHING;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.exam_bank_status()
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'questions', (SELECT count(*)::integer FROM public.exam_bank_questions),
    'exams', (SELECT count(*)::integer FROM public.exam_bank_exams),
    'subjects', (SELECT count(*)::integer FROM public.exam_bank_subjects),
    'papers', (
      SELECT count(*)::integer
      FROM public.exam_bank_papers
      WHERE question_count > 0
    ),
    'harvested', (
      SELECT count(*)::integer
      FROM public.exam_bank_papers
      WHERE last_harvested_at IS NOT NULL
    ),
    'exhausted', (
      SELECT count(*)::integer
      FROM public.exam_bank_papers
      WHERE exhausted
    )
  );
$$;

REVOKE ALL ON FUNCTION public.exam_bank_pick_paper(TEXT, TEXT, INTEGER, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.exam_bank_draw(TEXT, TEXT, INTEGER, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.exam_bank_ensure_paper(TEXT, TEXT, INTEGER, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.exam_bank_upsert(JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.exam_bank_replace_catalog(JSONB, JSONB, JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.exam_bank_status() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.exam_bank_pick_paper(TEXT, TEXT, INTEGER, TEXT)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.exam_bank_draw(TEXT, TEXT, INTEGER, TEXT, TEXT)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.exam_bank_upsert(JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.exam_bank_replace_catalog(JSONB, JSONB, JSONB)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.exam_bank_status() TO authenticated;

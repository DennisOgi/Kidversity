-- Saved exam attempts, a per-student mistake bank, maths results,
-- and teacher-assigned work with submissions.

CREATE TABLE IF NOT EXISTS public.class_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  teacher_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN ('exam', 'lesson', 'maths')),
  title TEXT NOT NULL CHECK (char_length(title) BETWEEN 1 AND 120),
  config JSONB NOT NULL DEFAULT '{}'::jsonb,
  due_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS class_assignments_class_idx
  ON public.class_assignments (class_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.assignment_submissions (
  assignment_id UUID NOT NULL REFERENCES public.class_assignments(id) ON DELETE CASCADE,
  user_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  correct INTEGER NOT NULL DEFAULT 0 CHECK (correct >= 0),
  total INTEGER NOT NULL DEFAULT 0 CHECK (total >= 0 AND correct <= total),
  completed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (assignment_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.exam_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  exam_slug TEXT NOT NULL,
  exam_label TEXT NOT NULL,
  subject_slug TEXT NOT NULL,
  subject_name TEXT NOT NULL,
  exam_year INTEGER,
  mode TEXT NOT NULL CHECK (mode IN ('quick', 'standard', 'challenge', 'mock', 'retry')),
  total INTEGER NOT NULL CHECK (total BETWEEN 1 AND 200),
  correct INTEGER NOT NULL CHECK (correct >= 0 AND correct <= total),
  duration_seconds INTEGER NOT NULL DEFAULT 0 CHECK (duration_seconds >= 0),
  assignment_id UUID REFERENCES public.class_assignments(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS exam_attempts_user_idx
  ON public.exam_attempts (user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.exam_mistakes (
  user_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  question_id INTEGER NOT NULL,
  exam_slug TEXT NOT NULL,
  exam_label TEXT NOT NULL,
  subject_slug TEXT NOT NULL,
  subject_name TEXT NOT NULL,
  payload JSONB NOT NULL,
  miss_count INTEGER NOT NULL DEFAULT 1,
  last_missed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at TIMESTAMPTZ,
  PRIMARY KEY (user_id, question_id)
);

CREATE TABLE IF NOT EXISTS public.maths_results (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  level INTEGER NOT NULL CHECK (level BETWEEN 1 AND 50),
  correct INTEGER NOT NULL CHECK (correct >= 0),
  total INTEGER NOT NULL CHECK (total BETWEEN 1 AND 100 AND correct <= total),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS maths_results_user_idx
  ON public.maths_results (user_id, created_at DESC);

ALTER TABLE public.class_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assignment_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_mistakes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maths_results ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.class_assignments, public.assignment_submissions,
  public.exam_attempts, public.exam_mistakes, public.maths_results FROM anon;

CREATE OR REPLACE FUNCTION private.teaches_student(p_student UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, private
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.class_members cm
    JOIN public.classes c ON c.id = cm.class_id
    WHERE cm.user_id = p_student AND c.teacher_id = auth.uid()
  );
$$;

REVOKE ALL ON FUNCTION private.teaches_student(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.teaches_student(UUID) TO authenticated;

DROP POLICY IF EXISTS "Teachers manage class assignments" ON public.class_assignments;
CREATE POLICY "Teachers manage class assignments" ON public.class_assignments
  FOR ALL TO authenticated
  USING (teacher_id = auth.uid() AND private.is_class_teacher(class_id))
  WITH CHECK (teacher_id = auth.uid() AND private.is_class_teacher(class_id));

DROP POLICY IF EXISTS "Students read class assignments" ON public.class_assignments;
CREATE POLICY "Students read class assignments" ON public.class_assignments
  FOR SELECT TO authenticated
  USING (private.is_enrolled_in_class(class_id));

DROP POLICY IF EXISTS "Students submit own work" ON public.assignment_submissions;
CREATE POLICY "Students submit own work" ON public.assignment_submissions
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.class_assignments a
      WHERE a.id = assignment_id AND private.is_enrolled_in_class(a.class_id)
    )
  );

DROP POLICY IF EXISTS "Students update own work" ON public.assignment_submissions;
CREATE POLICY "Students update own work" ON public.assignment_submissions
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Read own or taught submissions" ON public.assignment_submissions;
CREATE POLICY "Read own or taught submissions" ON public.assignment_submissions
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.class_assignments a
      WHERE a.id = assignment_id AND a.teacher_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Students save own attempts" ON public.exam_attempts;
CREATE POLICY "Students save own attempts" ON public.exam_attempts
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Read own or taught attempts" ON public.exam_attempts;
CREATE POLICY "Read own or taught attempts" ON public.exam_attempts
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR private.teaches_student(user_id));

DROP POLICY IF EXISTS "Students manage own mistakes" ON public.exam_mistakes;
CREATE POLICY "Students manage own mistakes" ON public.exam_mistakes
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Students save own maths" ON public.maths_results;
CREATE POLICY "Students save own maths" ON public.maths_results
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Read own or taught maths" ON public.maths_results;
CREATE POLICY "Read own or taught maths" ON public.maths_results
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR private.teaches_student(user_id));

-- One call per finished session: the attempt, new misses, cleared misses,
-- and the assignment submission when the session came from a teacher.
CREATE OR REPLACE FUNCTION public.record_exam_attempt(
  p_attempt JSONB,
  p_missed JSONB DEFAULT '[]'::jsonb,
  p_cleared INTEGER[] DEFAULT '{}'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_id UUID;
  v_item JSONB;
  v_assignment UUID := NULLIF(p_attempt->>'assignment_id', '')::UUID;
  v_total INTEGER := (p_attempt->>'total')::INTEGER;
  v_correct INTEGER := (p_attempt->>'correct')::INTEGER;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;
  IF jsonb_typeof(COALESCE(p_missed, '[]'::jsonb)) <> 'array'
     OR jsonb_array_length(COALESCE(p_missed, '[]'::jsonb)) > 200 THEN
    RAISE EXCEPTION 'INVALID_MISSED';
  END IF;

  INSERT INTO public.exam_attempts (
    user_id, exam_slug, exam_label, subject_slug, subject_name, exam_year,
    mode, total, correct, duration_seconds, assignment_id
  ) VALUES (
    v_uid,
    p_attempt->>'exam_slug',
    p_attempt->>'exam_label',
    p_attempt->>'subject_slug',
    p_attempt->>'subject_name',
    NULLIF(p_attempt->>'exam_year', '')::INTEGER,
    p_attempt->>'mode',
    v_total,
    v_correct,
    GREATEST(0, COALESCE((p_attempt->>'duration_seconds')::INTEGER, 0)),
    v_assignment
  )
  RETURNING id INTO v_id;

  FOR v_item IN SELECT * FROM jsonb_array_elements(COALESCE(p_missed, '[]'::jsonb)) LOOP
    INSERT INTO public.exam_mistakes (
      user_id, question_id, exam_slug, exam_label, subject_slug, subject_name, payload
    ) VALUES (
      v_uid,
      (v_item->>'id')::INTEGER,
      p_attempt->>'exam_slug',
      p_attempt->>'exam_label',
      p_attempt->>'subject_slug',
      p_attempt->>'subject_name',
      v_item
    )
    ON CONFLICT (user_id, question_id) DO UPDATE
    SET miss_count = public.exam_mistakes.miss_count + 1,
        last_missed_at = now(),
        resolved_at = NULL,
        payload = EXCLUDED.payload;
  END LOOP;

  UPDATE public.exam_mistakes
  SET resolved_at = now()
  WHERE user_id = v_uid
    AND resolved_at IS NULL
    AND question_id = ANY(COALESCE(p_cleared, '{}'));

  IF v_assignment IS NOT NULL THEN
    INSERT INTO public.assignment_submissions (assignment_id, user_id, correct, total)
    VALUES (v_assignment, v_uid, v_correct, v_total)
    ON CONFLICT (assignment_id, user_id) DO UPDATE
    SET correct = EXCLUDED.correct,
        total = EXCLUDED.total,
        completed_at = now()
    WHERE EXCLUDED.correct * GREATEST(public.assignment_submissions.total, 1)
      >= public.assignment_submissions.correct * GREATEST(EXCLUDED.total, 1);
  END IF;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.record_exam_attempt(JSONB, JSONB, INTEGER[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_exam_attempt(JSONB, JSONB, INTEGER[]) TO authenticated;

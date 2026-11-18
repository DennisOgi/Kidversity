-- Official school results and teacher targets.
--
-- A school's own subjects (English, Mathematics, Basic Science...) are not
-- Kidversity products: they are what the school reports on. Each term a
-- teacher sets a target per pupil and subject and records scores (a
-- baseline, then tests and exams, all as percentages).
--
-- Who can see a pupil's results: the pupil, their class teacher, their
-- school's admins, and parents linked through a family code. Only teachers
-- and admins write. Everything goes through the functions below.

CREATE TABLE IF NOT EXISTS public.school_subjects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  name TEXT NOT NULL CHECK (char_length(btrim(name)) BETWEEN 2 AND 60),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS school_subjects_name_uidx
  ON public.school_subjects (school_id, lower(btrim(name)));

CREATE TABLE IF NOT EXISTS public.school_terms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  label TEXT NOT NULL,
  starts_on DATE NOT NULL,
  ends_on DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (school_id, starts_on)
);

CREATE TABLE IF NOT EXISTS public.pupil_targets (
  student_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  subject_id UUID NOT NULL REFERENCES public.school_subjects(id) ON DELETE CASCADE,
  term_id UUID NOT NULL REFERENCES public.school_terms(id) ON DELETE CASCADE,
  target NUMERIC(5, 2) NOT NULL CHECK (target BETWEEN 0 AND 100),
  set_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (student_id, subject_id, term_id)
);

CREATE TABLE IF NOT EXISTS public.pupil_results (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  subject_id UUID NOT NULL REFERENCES public.school_subjects(id) ON DELETE CASCADE,
  term_id UUID NOT NULL REFERENCES public.school_terms(id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN ('baseline', 'test', 'exam')),
  title TEXT NOT NULL DEFAULT '' CHECK (char_length(title) <= 80),
  score NUMERIC(5, 2) NOT NULL CHECK (score BETWEEN 0 AND 100),
  assessed_on DATE NOT NULL DEFAULT current_date,
  recorded_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS pupil_results_student_idx
  ON public.pupil_results (student_id, term_id, subject_id, assessed_on);
CREATE INDEX IF NOT EXISTS pupil_results_subject_idx ON public.pupil_results (subject_id);
CREATE INDEX IF NOT EXISTS pupil_targets_subject_idx ON public.pupil_targets (subject_id);
CREATE INDEX IF NOT EXISTS pupil_targets_term_idx ON public.pupil_targets (term_id);
CREATE INDEX IF NOT EXISTS pupil_results_term_idx ON public.pupil_results (term_id);

ALTER TABLE public.school_subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_terms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pupil_targets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pupil_results ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.school_subjects, public.school_terms,
  public.pupil_targets, public.pupil_results FROM PUBLIC, anon, authenticated;

-- Helpers --------------------------------------------------------------------

-- The pupil's school (first membership as a student).
CREATE OR REPLACE FUNCTION private.pupil_school(p_student UUID)
RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, private
AS $$
  SELECT m.school_id FROM public.school_members m
  WHERE m.user_id = p_student
  ORDER BY CASE m.role WHEN 'student' THEN 0 ELSE 1 END, m.created_at
  LIMIT 1;
$$;

-- Teachers of the pupil's class and admins of the pupil's school may write.
CREATE OR REPLACE FUNCTION private.can_manage_pupil(p_student UUID)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, private
AS $$
  SELECT private.teaches_student(p_student)
  OR EXISTS (
    SELECT 1 FROM public.school_members me
    JOIN public.school_members pupil ON pupil.school_id = me.school_id
    WHERE me.user_id = auth.uid() AND me.role = 'admin'
      AND pupil.user_id = p_student
  );
$$;

CREATE OR REPLACE FUNCTION private.is_guardian_of(p_student UUID)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, private
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.payment_family_members g
    JOIN public.payment_family_members l
      ON l.family_id = g.family_id AND l.member_role = 'learner'
    WHERE g.user_id = auth.uid() AND g.member_role IN ('owner', 'guardian')
      AND l.user_id = p_student
  );
$$;

CREATE OR REPLACE FUNCTION private.can_view_pupil(p_student UUID)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, private
AS $$
  SELECT auth.uid() = p_student
  OR private.can_manage_pupil(p_student)
  OR private.is_guardian_of(p_student);
$$;

-- Nigerian school year: First term Sep-Dec, Second Jan-Apr, Third May-Aug.
CREATE OR REPLACE FUNCTION private.current_term(p_school UUID)
RETURNS UUID
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_today DATE := current_date;
  v_year INT := extract(year FROM v_today);
  v_month INT := extract(month FROM v_today);
  v_start DATE;
  v_end DATE;
  v_label TEXT;
  v_id UUID;
BEGIN
  IF p_school IS NULL THEN RETURN NULL; END IF;
  SELECT id INTO v_id FROM public.school_terms
  WHERE school_id = p_school AND v_today BETWEEN starts_on AND ends_on
  ORDER BY starts_on DESC LIMIT 1;
  IF v_id IS NOT NULL THEN RETURN v_id; END IF;

  IF v_month >= 9 THEN
    v_start := make_date(v_year, 9, 1); v_end := make_date(v_year, 12, 31);
    v_label := 'First term ' || v_year || '/' || (v_year + 1);
  ELSIF v_month <= 4 THEN
    v_start := make_date(v_year, 1, 1); v_end := make_date(v_year, 4, 30);
    v_label := 'Second term ' || (v_year - 1) || '/' || v_year;
  ELSE
    v_start := make_date(v_year, 5, 1); v_end := make_date(v_year, 8, 31);
    v_label := 'Third term ' || (v_year - 1) || '/' || v_year;
  END IF;

  INSERT INTO public.school_terms (school_id, label, starts_on, ends_on)
  VALUES (p_school, v_label, v_start, v_end)
  ON CONFLICT (school_id, starts_on) DO UPDATE SET label = EXCLUDED.label
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION private.pupil_school(UUID), private.can_manage_pupil(UUID),
  private.is_guardian_of(UUID), private.can_view_pupil(UUID),
  private.current_term(UUID) FROM PUBLIC, anon, authenticated;

-- Subjects -------------------------------------------------------------------

-- Subjects of the caller's school (staff) or the pupil's school.
CREATE OR REPLACE FUNCTION public.school_subject_list(p_student UUID DEFAULT NULL)
RETURNS TABLE (id UUID, name TEXT)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_school UUID;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  IF p_student IS NOT NULL THEN
    IF NOT private.can_view_pupil(p_student) THEN RAISE EXCEPTION 'NOT_AUTHORIZED'; END IF;
    v_school := private.pupil_school(p_student);
  ELSE
    SELECT m.school_id INTO v_school FROM public.school_members m
    WHERE m.user_id = auth.uid() AND m.role IN ('admin', 'teacher')
    ORDER BY CASE m.role WHEN 'admin' THEN 0 ELSE 1 END LIMIT 1;
  END IF;
  RETURN QUERY SELECT s.id, s.name FROM public.school_subjects s
  WHERE s.school_id = v_school ORDER BY lower(s.name);
END;
$$;

CREATE OR REPLACE FUNCTION public.add_school_subject(p_name TEXT)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_school UUID;
  v_name TEXT := btrim(regexp_replace(COALESCE(p_name, ''), '\s+', ' ', 'g'));
  v_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  IF char_length(v_name) < 2 OR char_length(v_name) > 60 THEN
    RAISE EXCEPTION 'INVALID_NAME';
  END IF;
  SELECT m.school_id INTO v_school FROM public.school_members m
  WHERE m.user_id = auth.uid() AND m.role IN ('admin', 'teacher')
  ORDER BY CASE m.role WHEN 'admin' THEN 0 ELSE 1 END LIMIT 1;
  IF v_school IS NULL THEN RAISE EXCEPTION 'NEEDS_SCHOOL'; END IF;

  SELECT id INTO v_id FROM public.school_subjects
  WHERE school_id = v_school AND lower(btrim(name)) = lower(v_name);
  IF v_id IS NOT NULL THEN RETURN v_id; END IF;

  INSERT INTO public.school_subjects (school_id, name, created_by)
  VALUES (v_school, v_name, auth.uid()) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

-- Writes -----------------------------------------------------------------------

CREATE OR REPLACE FUNCTION private.check_pupil_subject(p_student UUID, p_subject UUID)
RETURNS UUID
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_school UUID := private.pupil_school(p_student);
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  IF v_school IS NULL OR NOT private.can_manage_pupil(p_student) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.school_subjects WHERE id = p_subject AND school_id = v_school
  ) THEN
    RAISE EXCEPTION 'INVALID_SUBJECT';
  END IF;
  RETURN v_school;
END;
$$;
REVOKE ALL ON FUNCTION private.check_pupil_subject(UUID, UUID) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.set_pupil_target(p_student UUID, p_subject UUID, p_target NUMERIC)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_school UUID := private.check_pupil_subject(p_student, p_subject);
  v_term UUID := private.current_term(v_school);
BEGIN
  IF p_target IS NULL THEN
    DELETE FROM public.pupil_targets
    WHERE student_id = p_student AND subject_id = p_subject AND term_id = v_term;
    RETURN;
  END IF;
  IF p_target < 0 OR p_target > 100 THEN RAISE EXCEPTION 'INVALID_SCORE'; END IF;
  INSERT INTO public.pupil_targets (student_id, subject_id, term_id, target, set_by)
  VALUES (p_student, p_subject, v_term, round(p_target, 2), auth.uid())
  ON CONFLICT (student_id, subject_id, term_id)
  DO UPDATE SET target = EXCLUDED.target, set_by = EXCLUDED.set_by, updated_at = now();
END;
$$;

CREATE OR REPLACE FUNCTION public.record_pupil_result(
  p_student UUID,
  p_subject UUID,
  p_kind TEXT,
  p_score NUMERIC,
  p_title TEXT DEFAULT '',
  p_assessed_on DATE DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_school UUID := private.check_pupil_subject(p_student, p_subject);
  v_term UUID := private.current_term(v_school);
  v_id UUID;
BEGIN
  IF p_kind NOT IN ('baseline', 'test', 'exam') THEN RAISE EXCEPTION 'INVALID_KIND'; END IF;
  IF p_score IS NULL OR p_score < 0 OR p_score > 100 THEN RAISE EXCEPTION 'INVALID_SCORE'; END IF;
  -- One baseline per subject and term: a new one replaces the old.
  IF p_kind = 'baseline' THEN
    DELETE FROM public.pupil_results
    WHERE student_id = p_student AND subject_id = p_subject
      AND term_id = v_term AND kind = 'baseline';
  END IF;
  INSERT INTO public.pupil_results
    (student_id, subject_id, term_id, kind, title, score, assessed_on, recorded_by)
  VALUES (
    p_student, p_subject, v_term, p_kind, left(btrim(COALESCE(p_title, '')), 80),
    round(p_score, 2), COALESCE(p_assessed_on, current_date), auth.uid()
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_pupil_result(p_result UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_student UUID;
BEGIN
  SELECT student_id INTO v_student FROM public.pupil_results WHERE id = p_result;
  IF v_student IS NULL THEN RETURN; END IF;
  IF NOT private.can_manage_pupil(v_student) THEN RAISE EXCEPTION 'NOT_AUTHORIZED'; END IF;
  DELETE FROM public.pupil_results WHERE id = p_result;
END;
$$;

-- Reads ------------------------------------------------------------------------

-- One pupil's profile for the current term: each subject with its target,
-- baseline, latest score and every result.
CREATE OR REPLACE FUNCTION public.pupil_profile(p_student UUID)
RETURNS JSONB
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_school UUID;
  v_term UUID;
  v_result JSONB;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  IF NOT private.can_view_pupil(p_student) THEN RAISE EXCEPTION 'NOT_AUTHORIZED'; END IF;
  v_school := private.pupil_school(p_student);
  v_term := private.current_term(v_school);

  SELECT jsonb_build_object(
    'student_id', p.user_id,
    'display_name', p.display_name,
    'avatar_emoji', p.avatar_emoji,
    'xp', COALESCE(p.xp, 0),
    'level', COALESCE(p.level, 1),
    'streak_days', COALESCE(p.streak_days, 0),
    'lessons_completed', COALESCE(p.lessons_completed, 0),
    'school_name', (SELECT name FROM public.schools WHERE id = v_school),
    'class_name', (
      SELECT c.name FROM public.class_members cm JOIN public.classes c ON c.id = cm.class_id
      WHERE cm.user_id = p_student ORDER BY cm.joined_at DESC LIMIT 1
    ),
    'term_label', (SELECT label FROM public.school_terms WHERE id = v_term),
    'can_edit', private.can_manage_pupil(p_student),
    'subjects', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'subject_id', s.id,
        'name', s.name,
        'target', t.target,
        'baseline', (
          SELECT r.score FROM public.pupil_results r
          WHERE r.student_id = p_student AND r.subject_id = s.id
            AND r.term_id = v_term AND r.kind = 'baseline'
          LIMIT 1
        ),
        'latest', (
          SELECT r.score FROM public.pupil_results r
          WHERE r.student_id = p_student AND r.subject_id = s.id
            AND r.term_id = v_term AND r.kind <> 'baseline'
          ORDER BY r.assessed_on DESC, r.created_at DESC LIMIT 1
        ),
        'results', COALESCE((
          SELECT jsonb_agg(jsonb_build_object(
            'id', r.id, 'kind', r.kind, 'title', r.title,
            'score', r.score, 'assessed_on', r.assessed_on
          ) ORDER BY r.assessed_on, r.created_at)
          FROM public.pupil_results r
          WHERE r.student_id = p_student AND r.subject_id = s.id AND r.term_id = v_term
        ), '[]'::jsonb)
      ) ORDER BY lower(s.name))
      FROM public.school_subjects s
      LEFT JOIN public.pupil_targets t
        ON t.subject_id = s.id AND t.student_id = p_student AND t.term_id = v_term
      WHERE s.school_id = v_school
        AND (t.target IS NOT NULL OR EXISTS (
          SELECT 1 FROM public.pupil_results r
          WHERE r.student_id = p_student AND r.subject_id = s.id AND r.term_id = v_term
        ) OR private.can_manage_pupil(p_student))
    ), '[]'::jsonb)
  ) INTO v_result
  FROM public.user_profiles p
  WHERE p.user_id = p_student;

  RETURN v_result;
END;
$$;

-- Whole class at a glance: each pupil's latest score and target per subject.
CREATE OR REPLACE FUNCTION public.class_results(p_class_id UUID)
RETURNS JSONB
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_school UUID;
  v_term UUID;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  IF NOT private.is_class_teacher(p_class_id) THEN RAISE EXCEPTION 'NOT_AUTHORIZED'; END IF;
  SELECT school_id INTO v_school FROM public.classes WHERE id = p_class_id;
  v_term := private.current_term(v_school);

  RETURN jsonb_build_object(
    'term_label', (SELECT label FROM public.school_terms WHERE id = v_term),
    'subjects', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name) ORDER BY lower(s.name))
      FROM public.school_subjects s WHERE s.school_id = v_school
    ), '[]'::jsonb),
    'pupils', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'student_id', cm.user_id,
        'display_name', COALESCE(p.display_name, 'Learner'),
        'avatar_emoji', COALESCE(p.avatar_emoji, '🦊'),
        'scores', COALESCE((
          SELECT jsonb_object_agg(s.id::text, jsonb_build_object(
            'target', t.target,
            'latest', (
              SELECT r.score FROM public.pupil_results r
              WHERE r.student_id = cm.user_id AND r.subject_id = s.id
                AND r.term_id = v_term AND r.kind <> 'baseline'
              ORDER BY r.assessed_on DESC, r.created_at DESC LIMIT 1
            )
          ))
          FROM public.school_subjects s
          LEFT JOIN public.pupil_targets t
            ON t.subject_id = s.id AND t.student_id = cm.user_id AND t.term_id = v_term
          WHERE s.school_id = v_school
        ), '{}'::jsonb)
      ) ORDER BY lower(COALESCE(p.display_name, '')))
      FROM public.class_members cm
      LEFT JOIN public.user_profiles p ON p.user_id = cm.user_id
      WHERE cm.class_id = p_class_id
    ), '[]'::jsonb)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.school_subject_list(UUID), public.add_school_subject(TEXT),
  public.set_pupil_target(UUID, UUID, NUMERIC),
  public.record_pupil_result(UUID, UUID, TEXT, NUMERIC, TEXT, DATE),
  public.delete_pupil_result(UUID), public.pupil_profile(UUID),
  public.class_results(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.school_subject_list(UUID), public.add_school_subject(TEXT),
  public.set_pupil_target(UUID, UUID, NUMERIC),
  public.record_pupil_result(UUID, UUID, TEXT, NUMERIC, TEXT, DATE),
  public.delete_pupil_result(UUID), public.pupil_profile(UUID),
  public.class_results(UUID) TO authenticated;

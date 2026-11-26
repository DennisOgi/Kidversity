-- ACE staff dashboards: teacher overview, marking queue, class progress,
-- student detail, and school admin (people, join code, subjects).
-- Staff = school_members with role teacher or admin. Everything is scoped
-- to the caller's school; nothing crosses schools.

-- The caller's school where they are staff (admin preferred).
CREATE OR REPLACE FUNCTION private.staff_school()
RETURNS TABLE (school_id UUID, role TEXT)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, private
AS $$
  SELECT m.school_id, m.role FROM public.school_members m
  WHERE m.user_id = auth.uid() AND m.role IN ('teacher', 'admin')
  ORDER BY CASE m.role WHEN 'admin' THEN 0 ELSE 1 END, m.created_at
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION private.require_staff(p_admin BOOLEAN DEFAULT FALSE)
RETURNS UUID
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_school UUID;
  v_role TEXT;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  SELECT s.school_id, s.role INTO v_school, v_role FROM private.staff_school() s;
  IF v_school IS NULL THEN RAISE EXCEPTION 'NOT_STAFF'; END IF;
  IF p_admin AND v_role <> 'admin' THEN RAISE EXCEPTION 'NOT_ADMIN'; END IF;
  RETURN v_school;
END;
$$;

REVOKE ALL ON FUNCTION private.staff_school(), private.require_staff(BOOLEAN)
  FROM PUBLIC, anon, authenticated;

-- Teacher / admin overview ---------------------------------------------------

CREATE OR REPLACE FUNCTION public.ace_staff_overview()
RETURNS JSONB
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_school UUID := private.require_staff(FALSE);
  v_role TEXT := (SELECT role FROM private.staff_school());
BEGIN
  RETURN jsonb_build_object(
    'school', (SELECT jsonb_build_object('id', id, 'name', name, 'join_code',
                 CASE WHEN v_role = 'admin' THEN join_code END)
               FROM public.schools WHERE id = v_school),
    'role', v_role,
    'display_name', (SELECT display_name FROM public.profiles WHERE user_id = auth.uid()),
    'counts', jsonb_build_object(
      'students', (SELECT count(*) FROM public.school_members WHERE school_id = v_school AND role = 'student'),
      'teachers', (SELECT count(*) FROM public.school_members WHERE school_id = v_school AND role IN ('teacher', 'admin')),
      'to_mark', (SELECT count(*) FROM public.attempts WHERE school_id = v_school AND marking_state = 'needs_review'),
      'attempts_7d', (SELECT count(*) FROM public.attempts WHERE school_id = v_school AND created_at > now() - interval '7 days'),
      'active_7d', (SELECT count(DISTINCT user_id) FROM public.attempts WHERE school_id = v_school AND created_at > now() - interval '7 days'),
      'marked_7d', (SELECT count(*) FROM public.attempt_reviews r JOIN public.attempts a ON a.id = r.attempt_id
                    WHERE a.school_id = v_school AND r.created_at > now() - interval '7 days')
    ),
    -- Attempts per day for the last 14 days.
    'activity', (
      SELECT jsonb_agg(jsonb_build_object('day', d::date, 'attempts', (
        SELECT count(*) FROM public.attempts a
        WHERE a.school_id = v_school AND a.created_at::date = d::date
      )) ORDER BY d)
      FROM generate_series(current_date - 13, current_date, interval '1 day') d
    ),
    'channels', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', c.id, 'stage', c.stage, 'subject', c.subject,
        'questions', (SELECT count(*) FROM public.questions q WHERE q.channel_id = c.id
                      AND (q.school_id IS NULL OR q.school_id = v_school) AND q.review_status <> 'archived'),
        'learners', (SELECT count(DISTINCT a.user_id) FROM public.attempts a JOIN public.questions q ON q.id = a.question_id
                     WHERE a.school_id = v_school AND q.channel_id = c.id),
        'attempts', (SELECT count(*) FROM public.attempts a JOIN public.questions q ON q.id = a.question_id
                     WHERE a.school_id = v_school AND q.channel_id = c.id),
        'correct_rate', (
          SELECT round(100.0 * count(*) FILTER (WHERE a.final_answer_status IN ('final_answer_match', 'option_match'))
                 / NULLIF(count(*) FILTER (WHERE a.final_answer_status <> 'not_auto_checked'), 0))
          FROM public.attempts a JOIN public.questions q ON q.id = a.question_id
          WHERE a.school_id = v_school AND q.channel_id = c.id)
      ) ORDER BY c.sort_order)
      FROM public.channels c JOIN public.school_channels sc ON sc.channel_id = c.id
      WHERE sc.school_id = v_school
    ), '[]'::jsonb),
    -- Students who may need help: low correct rate or work waiting.
    'attention', COALESCE((
      SELECT jsonb_agg(x ORDER BY (x->>'rate')::numeric NULLS LAST) FROM (
        SELECT jsonb_build_object(
          'user_id', m.user_id, 'name', p.display_name,
          'attempts', count(a.id),
          'rate', round(100.0 * count(*) FILTER (WHERE a.final_answer_status IN ('final_answer_match', 'option_match'))
                  / NULLIF(count(*) FILTER (WHERE a.final_answer_status <> 'not_auto_checked'), 0)),
          'last_active', max(a.created_at)
        ) AS x
        FROM public.school_members m
        JOIN public.profiles p ON p.user_id = m.user_id
        LEFT JOIN public.attempts a ON a.user_id = m.user_id AND a.school_id = v_school
        WHERE m.school_id = v_school AND m.role = 'student'
        GROUP BY m.user_id, p.display_name
        HAVING count(a.id) = 0 OR
          (100.0 * count(*) FILTER (WHERE a.final_answer_status IN ('final_answer_match', 'option_match'))
           / NULLIF(count(*) FILTER (WHERE a.final_answer_status <> 'not_auto_checked'), 0)) < 60
        LIMIT 8
      ) s
    ), '[]'::jsonb),
    'recent', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'attempt_id', a.id, 'name', p.display_name, 'question', left(q.prompt_markdown, 120),
        'lesson', l.title, 'status', a.final_answer_status, 'state', a.marking_state, 'at', a.created_at
      ) ORDER BY a.created_at DESC)
      FROM (SELECT * FROM public.attempts WHERE school_id = v_school ORDER BY created_at DESC LIMIT 8) a
      JOIN public.profiles p ON p.user_id = a.user_id
      JOIN public.questions q ON q.id = a.question_id
      LEFT JOIN public.lessons l ON l.id = q.lesson_id
    ), '[]'::jsonb)
  );
END;
$$;

-- Marking -------------------------------------------------------------------------

-- Attempts in the caller's school, newest first. p_state: needs_review
-- (default), teacher_marked, or all.
CREATE OR REPLACE FUNCTION public.ace_review_queue(p_state TEXT DEFAULT 'needs_review', p_channel TEXT DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_school UUID := private.require_staff(FALSE);
BEGIN
  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'attempt_id', a.id, 'user_id', a.user_id, 'name', p.display_name,
      'question_id', q.id, 'question', q.prompt_markdown, 'kind', q.kind,
      'max_marks', q.max_marks, 'channel_id', q.channel_id, 'stage', c.stage, 'subject', c.subject,
      'lesson', l.title, 'attempt_no', a.attempt_no, 'status', a.final_answer_status,
      'state', a.marking_state, 'awarded', a.awarded_marks, 'at', a.created_at
    ) ORDER BY a.created_at DESC)
    FROM public.attempts a
    JOIN public.profiles p ON p.user_id = a.user_id
    JOIN public.questions q ON q.id = a.question_id
    JOIN public.channels c ON c.id = q.channel_id
    LEFT JOIN public.lessons l ON l.id = q.lesson_id
    WHERE a.school_id = v_school
      AND (p_state = 'all' OR a.marking_state = p_state)
      AND (p_channel IS NULL OR q.channel_id = p_channel)
    LIMIT 200
  ), '[]'::jsonb);
END;
$$;

-- One attempt with everything a teacher needs to mark it: the response, the
-- approved answer, worked solution and rubric, and earlier reviews.
CREATE OR REPLACE FUNCTION public.ace_attempt_detail(p_attempt UUID)
RETURNS JSONB
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_school UUID := private.require_staff(FALSE);
  v_a public.attempts%ROWTYPE;
BEGIN
  SELECT * INTO v_a FROM public.attempts WHERE id = p_attempt;
  IF v_a.id IS NULL OR v_a.school_id IS DISTINCT FROM v_school THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  RETURN (
    SELECT jsonb_build_object(
      'attempt_id', v_a.id, 'user_id', v_a.user_id, 'name', p.display_name,
      'attempt_no', v_a.attempt_no, 'at', v_a.created_at, 'response', v_a.response,
      'status', v_a.final_answer_status, 'state', v_a.marking_state, 'awarded', v_a.awarded_marks,
      'question', jsonb_build_object('id', q.id, 'prompt', q.prompt_markdown, 'kind', q.kind,
        'max_marks', q.max_marks, 'unit', q.answer_unit, 'lesson', l.title,
        'stage', c.stage, 'subject', c.subject),
      'key', jsonb_build_object('answer', k.answer_markdown, 'worked_solution', k.worked_solution,
        'rubric', k.rubric),
      'reviews', COALESCE((
        SELECT jsonb_agg(jsonb_build_object('marks', r.awarded_marks, 'criteria', r.criterion_marks,
          'comment', r.comment, 'by', rp.display_name, 'at', r.created_at) ORDER BY r.created_at DESC)
        FROM public.attempt_reviews r LEFT JOIN public.profiles rp ON rp.user_id = r.reviewer_id
        WHERE r.attempt_id = v_a.id
      ), '[]'::jsonb)
    )
    FROM public.questions q
    JOIN public.channels c ON c.id = q.channel_id
    JOIN public.profiles p ON p.user_id = v_a.user_id
    LEFT JOIN public.lessons l ON l.id = q.lesson_id
    LEFT JOIN private.question_keys k ON k.question_id = q.id AND k.content_version = v_a.question_version
    WHERE q.id = v_a.question_id
  );
END;
$$;

-- Record a teacher's marks. Criterion marks are optional; the total must be
-- within the question's maximum. Each review is kept (audit trail).
CREATE OR REPLACE FUNCTION public.ace_mark_attempt(
  p_attempt UUID, p_marks NUMERIC, p_criteria JSONB DEFAULT '[]'::jsonb, p_comment TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_school UUID := private.require_staff(FALSE);
  v_a public.attempts%ROWTYPE;
  v_max INT;
BEGIN
  SELECT * INTO v_a FROM public.attempts WHERE id = p_attempt FOR UPDATE;
  IF v_a.id IS NULL OR v_a.school_id IS DISTINCT FROM v_school THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  SELECT max_marks INTO v_max FROM public.questions WHERE id = v_a.question_id;
  IF p_marks IS NULL OR p_marks < 0 OR p_marks > v_max THEN RAISE EXCEPTION 'INVALID_MARKS'; END IF;
  IF p_comment IS NOT NULL AND char_length(p_comment) > 2000 THEN RAISE EXCEPTION 'COMMENT_TOO_LONG'; END IF;

  INSERT INTO public.attempt_reviews (attempt_id, reviewer_id, criterion_marks, awarded_marks, comment)
  VALUES (v_a.id, auth.uid(), COALESCE(p_criteria, '[]'::jsonb), p_marks, NULLIF(btrim(p_comment), ''));
  UPDATE public.attempts SET awarded_marks = p_marks, marking_state = 'teacher_marked' WHERE id = v_a.id;
  RETURN jsonb_build_object('attempt_id', v_a.id, 'awarded', p_marks, 'max', v_max);
END;
$$;

-- Progress -------------------------------------------------------------------------

-- Students x lessons for one channel.
CREATE OR REPLACE FUNCTION public.ace_class_progress(p_channel TEXT)
RETURNS JSONB
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_school UUID := private.require_staff(FALSE);
BEGIN
  RETURN jsonb_build_object(
    'lessons', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('id', l.id, 'title', l.title,
        'questions', (SELECT count(*) FROM public.questions q WHERE q.lesson_id = l.id)) ORDER BY l.sort_order)
      FROM public.lessons l WHERE l.channel_id = p_channel
        AND (l.school_id IS NULL OR l.school_id = v_school) AND l.review_status <> 'archived'
    ), '[]'::jsonb),
    'students', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'user_id', m.user_id, 'name', p.display_name,
        'last_active', (SELECT max(created_at) FROM public.attempts a WHERE a.user_id = m.user_id AND a.school_id = v_school),
        'cells', (
          SELECT jsonb_object_agg(l.id, jsonb_build_object(
            'tried', (SELECT count(DISTINCT a.question_id) FROM public.attempts a JOIN public.questions q ON q.id = a.question_id
                      WHERE a.user_id = m.user_id AND q.lesson_id = l.id),
            'correct', (SELECT count(DISTINCT a.question_id) FROM public.attempts a JOIN public.questions q ON q.id = a.question_id
                        WHERE a.user_id = m.user_id AND q.lesson_id = l.id
                          AND a.final_answer_status IN ('final_answer_match', 'option_match'))
          ))
          FROM public.lessons l WHERE l.channel_id = p_channel
            AND (l.school_id IS NULL OR l.school_id = v_school) AND l.review_status <> 'archived'
        )
      ) ORDER BY lower(p.display_name))
      FROM public.school_members m JOIN public.profiles p ON p.user_id = m.user_id
      WHERE m.school_id = v_school AND m.role = 'student'
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.ace_student_detail(p_student UUID)
RETURNS JSONB
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_school UUID := private.require_staff(FALSE);
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.school_members WHERE school_id = v_school AND user_id = p_student) THEN
    RAISE EXCEPTION 'NOT_FOUND';
  END IF;
  RETURN jsonb_build_object(
    'user_id', p_student,
    'name', (SELECT display_name FROM public.profiles WHERE user_id = p_student),
    'joined', (SELECT created_at FROM public.school_members WHERE school_id = v_school AND user_id = p_student),
    'attempts', (SELECT count(*) FROM public.attempts WHERE user_id = p_student AND school_id = v_school),
    'tried', (SELECT count(DISTINCT question_id) FROM public.attempts WHERE user_id = p_student AND school_id = v_school),
    'correct', (SELECT count(DISTINCT question_id) FROM public.attempts WHERE user_id = p_student AND school_id = v_school
                AND final_answer_status IN ('final_answer_match', 'option_match')),
    'to_mark', (SELECT count(*) FROM public.attempts WHERE user_id = p_student AND school_id = v_school AND marking_state = 'needs_review'),
    'channels', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('id', c.id, 'stage', c.stage, 'subject', c.subject,
        'questions', (SELECT count(*) FROM public.questions q WHERE q.channel_id = c.id AND (q.school_id IS NULL OR q.school_id = v_school)),
        'tried', (SELECT count(DISTINCT a.question_id) FROM public.attempts a JOIN public.questions q ON q.id = a.question_id
                  WHERE a.user_id = p_student AND q.channel_id = c.id),
        'correct', (SELECT count(DISTINCT a.question_id) FROM public.attempts a JOIN public.questions q ON q.id = a.question_id
                    WHERE a.user_id = p_student AND q.channel_id = c.id
                      AND a.final_answer_status IN ('final_answer_match', 'option_match'))
      ) ORDER BY c.sort_order)
      FROM public.channels c JOIN public.school_channels sc ON sc.channel_id = c.id WHERE sc.school_id = v_school
    ), '[]'::jsonb),
    'history', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('attempt_id', a.id, 'question', left(q.prompt_markdown, 140),
        'lesson', l.title, 'status', a.final_answer_status, 'state', a.marking_state,
        'awarded', a.awarded_marks, 'max', q.max_marks, 'at', a.created_at) ORDER BY a.created_at DESC)
      FROM (SELECT * FROM public.attempts WHERE user_id = p_student AND school_id = v_school
            ORDER BY created_at DESC LIMIT 40) a
      JOIN public.questions q ON q.id = a.question_id LEFT JOIN public.lessons l ON l.id = q.lesson_id
    ), '[]'::jsonb)
  );
END;
$$;

-- School admin --------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.ace_school_people()
RETURNS JSONB
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_school UUID := private.require_staff(FALSE);
BEGIN
  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'user_id', m.user_id, 'name', p.display_name, 'role', m.role, 'joined', m.created_at,
      'is_me', m.user_id = auth.uid(),
      'attempts', (SELECT count(*) FROM public.attempts a WHERE a.user_id = m.user_id AND a.school_id = v_school),
      'last_active', (SELECT max(created_at) FROM public.attempts a WHERE a.user_id = m.user_id AND a.school_id = v_school)
    ) ORDER BY CASE m.role WHEN 'admin' THEN 0 WHEN 'teacher' THEN 1 ELSE 2 END, lower(p.display_name))
    FROM public.school_members m JOIN public.profiles p ON p.user_id = m.user_id
    WHERE m.school_id = v_school
  ), '[]'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION public.ace_set_member_role(p_user UUID, p_role TEXT)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_school UUID := private.require_staff(TRUE);
BEGIN
  IF p_role NOT IN ('student', 'teacher', 'admin') THEN RAISE EXCEPTION 'INVALID_ROLE'; END IF;
  IF p_user = auth.uid() THEN RAISE EXCEPTION 'CANNOT_CHANGE_SELF'; END IF;
  UPDATE public.school_members SET role = p_role WHERE school_id = v_school AND user_id = p_user;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.ace_remove_member(p_user UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_school UUID := private.require_staff(TRUE);
BEGIN
  IF p_user = auth.uid() THEN RAISE EXCEPTION 'CANNOT_CHANGE_SELF'; END IF;
  DELETE FROM public.school_members WHERE school_id = v_school AND user_id = p_user;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.ace_new_join_code()
RETURNS TEXT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_school UUID := private.require_staff(TRUE);
  v_code TEXT;
BEGIN
  LOOP
    v_code := upper(substr(translate(md5(random()::text || clock_timestamp()::text), '01', ''), 1, 8));
    EXIT WHEN NOT EXISTS (SELECT 1 FROM public.schools WHERE join_code = v_code);
  END LOOP;
  UPDATE public.schools SET join_code = v_code WHERE id = v_school;
  RETURN v_code;
END;
$$;

-- Learners: show a teacher's marks and comment on each question -----------------

CREATE OR REPLACE FUNCTION public.ace_my_reviews(p_lesson TEXT)
RETURNS JSONB
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, private
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  RETURN COALESCE((
    SELECT jsonb_object_agg(x.question_id, x.review) FROM (
      SELECT DISTINCT ON (a.question_id) a.question_id,
        jsonb_build_object('awarded', r.awarded_marks, 'max', q.max_marks, 'comment', r.comment,
          'by', rp.display_name, 'at', r.created_at) AS review
      FROM public.attempts a
      JOIN public.attempt_reviews r ON r.attempt_id = a.id
      JOIN public.questions q ON q.id = a.question_id
      LEFT JOIN public.profiles rp ON rp.user_id = r.reviewer_id
      WHERE a.user_id = auth.uid() AND q.lesson_id = p_lesson
      ORDER BY a.question_id, r.created_at DESC
    ) x
  ), '{}'::jsonb);
END;
$$;

REVOKE ALL ON FUNCTION public.ace_staff_overview(), public.ace_review_queue(TEXT, TEXT),
  public.ace_attempt_detail(UUID), public.ace_mark_attempt(UUID, NUMERIC, JSONB, TEXT),
  public.ace_class_progress(TEXT), public.ace_student_detail(UUID), public.ace_school_people(),
  public.ace_set_member_role(UUID, TEXT), public.ace_remove_member(UUID), public.ace_new_join_code(),
  public.ace_my_reviews(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ace_staff_overview(), public.ace_review_queue(TEXT, TEXT),
  public.ace_attempt_detail(UUID), public.ace_mark_attempt(UUID, NUMERIC, JSONB, TEXT),
  public.ace_class_progress(TEXT), public.ace_student_detail(UUID), public.ace_school_people(),
  public.ace_set_member_role(UUID, TEXT), public.ace_remove_member(UUID), public.ace_new_join_code(),
  public.ace_my_reviews(TEXT) TO authenticated;

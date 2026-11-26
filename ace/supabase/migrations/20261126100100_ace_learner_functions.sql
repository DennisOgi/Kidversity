-- ACE learner functions: what a user may see, the learning feed, and
-- attempts with a server-side final-answer check. Answer keys never leave
-- the server except through ace_submit_attempt's practice feedback.

-- Access helpers -----------------------------------------------------------------

CREATE OR REPLACE FUNCTION private.is_platform_staff()
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, private
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE user_id = auth.uid() AND platform_role IN ('reviewer', 'platform_admin')
  );
$$;

-- Channels the caller can study or teach: bought by one of their schools.
CREATE OR REPLACE FUNCTION private.my_channels()
RETURNS TABLE (channel_id TEXT, school_id UUID, content_mode TEXT, role TEXT)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, private
AS $$
  SELECT sc.channel_id, s.id, s.content_mode, m.role
  FROM public.school_members m
  JOIN public.schools s ON s.id = m.school_id
  JOIN public.school_channels sc ON sc.school_id = s.id
  WHERE m.user_id = auth.uid();
$$;

-- Can the caller see this piece of content?
CREATE OR REPLACE FUNCTION private.can_see_content(
  p_channel TEXT, p_school UUID, p_review TEXT
)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, private
AS $$
  SELECT CASE
    WHEN p_review = 'archived' THEN FALSE
    WHEN private.is_platform_staff() THEN TRUE
    ELSE EXISTS (
      SELECT 1 FROM private.my_channels() c
      WHERE c.channel_id = p_channel
        -- School-private content only for that school.
        AND (p_school IS NULL OR p_school = c.school_id)
        AND (
          p_review = 'published'
          -- Pilot schools in staging mode review drafts; their teachers can
          -- always see their own school's unpublished items.
          OR c.content_mode = 'staging'
          OR (p_school IS NOT NULL AND c.role IN ('teacher', 'admin'))
        )
    )
  END;
$$;

REVOKE ALL ON FUNCTION private.is_platform_staff(), private.my_channels(),
  private.can_see_content(TEXT, UUID, TEXT) FROM PUBLIC, anon, authenticated;

-- Units: canonical token for common equivalent spellings.
CREATE OR REPLACE FUNCTION private.canonical_unit(p_unit TEXT)
RETURNS TEXT
LANGUAGE sql IMMUTABLE SET search_path = ''
AS $$
  SELECT CASE
    WHEN p_unit IS NULL OR btrim(p_unit) = '' THEN NULL
    ELSE (
      SELECT CASE u
        WHEN 'ω' THEN 'ohm' WHEN 'ohms' THEN 'ohm' WHEN 'ohm' THEN 'ohm'
        WHEN 'ms^-1' THEN 'm/s' WHEN 'ms-1' THEN 'm/s' WHEN 'm s^-1' THEN 'm/s'
        WHEN 'm s-1' THEN 'm/s' WHEN 'mps' THEN 'm/s' WHEN 'm/s' THEN 'm/s'
        WHEN '°' THEN 'deg' WHEN 'degrees' THEN 'deg' WHEN 'degree' THEN 'deg' WHEN 'deg' THEN 'deg'
        WHEN 'n kg^-1' THEN 'N/kg' WHEN 'nkg^-1' THEN 'N/kg' WHEN 'n/kg' THEN 'N/kg'
        WHEN 'j kg^-1' THEN 'J/kg' WHEN 'j/kg' THEN 'J/kg'
        WHEN 's-1' THEN 's^-1' WHEN '/s' THEN 's^-1' WHEN 's^-1' THEN 's^-1'
        WHEN 'count/min' THEN 'counts/min' WHEN 'counts per minute' THEN 'counts/min'
        WHEN 'counts/min' THEN 'counts/min'
        WHEN 'volts' THEN 'V' WHEN 'v' THEN 'V'
        WHEN 'amps' THEN 'A' WHEN 'a' THEN 'A'
        WHEN 'watts' THEN 'W' WHEN 'w' THEN 'W'
        WHEN 'newtons' THEN 'N' WHEN 'n' THEN 'N'
        WHEN 'seconds' THEN 's' WHEN 's' THEN 's'
        WHEN 'metres' THEN 'm' WHEN 'meters' THEN 'm' WHEN 'm' THEN 'm'
        ELSE btrim(p_unit)
      END
      FROM (SELECT lower(regexp_replace(btrim(p_unit), '\s+', ' ', 'g')) AS u) x
    )
  END;
$$;

-- Port of tools/numeric_check.py. Final answer only; never awards marks.
CREATE OR REPLACE FUNCTION private.check_final_answer(
  p_kind TEXT, p_numeric JSONB, p_correct_option TEXT, p_response JSONB
)
RETURNS TEXT
LANGUAGE plpgsql IMMUTABLE SET search_path = public, private
AS $$
DECLARE
  v_value NUMERIC;
  v_expected NUMERIC;
  v_tol NUMERIC;
BEGIN
  IF p_kind = 'multiple_choice' THEN
    IF p_correct_option IS NULL THEN RETURN 'not_auto_checked'; END IF;
    RETURN CASE WHEN p_response->>'option' = p_correct_option
      THEN 'option_match' ELSE 'option_wrong' END;
  END IF;
  IF p_kind <> 'numeric' OR p_numeric IS NULL THEN
    RETURN 'not_auto_checked';
  END IF;
  IF jsonb_typeof(p_response->'final_answer') IS DISTINCT FROM 'number' THEN
    RETURN 'invalid_numeric_input';
  END IF;
  v_value := (p_response->>'final_answer')::numeric;
  IF private.canonical_unit(p_response->>'unit')
     IS DISTINCT FROM private.canonical_unit(p_numeric->>'unit') THEN
    RETURN 'unit_mismatch';
  END IF;
  v_expected := (p_numeric->>'value')::numeric;
  v_tol := COALESCE((p_numeric->>'absolute_tolerance')::numeric, 0);
  RETURN CASE WHEN abs(v_value - v_expected) <= v_tol
    THEN 'final_answer_match' ELSE 'try_again' END;
END;
$$;

REVOKE ALL ON FUNCTION private.canonical_unit(TEXT),
  private.check_final_answer(TEXT, JSONB, TEXT, JSONB) FROM PUBLIC, anon, authenticated;

-- Who am I --------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.ace_me()
RETURNS JSONB
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, private
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  RETURN jsonb_build_object(
    'user_id', auth.uid(),
    'display_name', (SELECT display_name FROM public.profiles WHERE user_id = auth.uid()),
    'platform_role', (SELECT platform_role FROM public.profiles WHERE user_id = auth.uid()),
    'schools', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', s.id, 'name', s.name, 'role', m.role, 'content_mode', s.content_mode
      ) ORDER BY s.name)
      FROM public.school_members m JOIN public.schools s ON s.id = m.school_id
      WHERE m.user_id = auth.uid()
    ), '[]'::jsonb),
    'channels', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', c.id, 'stage', c.stage, 'subject', c.subject, 'group', c.group_label,
        'profile_id', c.profile_id,
        'syllabus', p.board || ' ' || p.syllabus_code,
        'lessons', (
          SELECT count(*) FROM public.lessons l
          WHERE l.channel_id = c.id
            AND private.can_see_content(l.channel_id, l.school_id, l.review_status)
        )
      ) ORDER BY c.sort_order)
      FROM public.channels c
      JOIN public.syllabus_profiles p ON p.id = c.profile_id
      WHERE private.is_platform_staff()
         OR c.id IN (SELECT channel_id FROM private.my_channels())
    ), '[]'::jsonb)
  );
END;
$$;

-- Join a school as a student with its join code.
CREATE OR REPLACE FUNCTION public.ace_join_school(p_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_school public.schools%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  SELECT * INTO v_school FROM public.schools
  WHERE join_code = upper(regexp_replace(COALESCE(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
  IF v_school.id IS NULL THEN RAISE EXCEPTION 'INVALID_CODE'; END IF;
  INSERT INTO public.school_members (school_id, user_id, role)
  VALUES (v_school.id, auth.uid(), 'student')
  ON CONFLICT (school_id, user_id) DO NOTHING;
  RETURN jsonb_build_object('school_id', v_school.id, 'name', v_school.name);
END;
$$;

-- Learning feed ------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.ace_channel(p_channel TEXT)
RETURNS JSONB
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_channel public.channels%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  SELECT * INTO v_channel FROM public.channels WHERE id = p_channel;
  IF v_channel.id IS NULL THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF NOT private.is_platform_staff()
     AND p_channel NOT IN (SELECT channel_id FROM private.my_channels()) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  RETURN jsonb_build_object(
    'id', v_channel.id,
    'stage', v_channel.stage,
    'subject', v_channel.subject,
    'syllabus', (SELECT board || ' ' || syllabus_code || ' · exams ' ||
                   array_to_string(exam_years, '–')
                 FROM public.syllabus_profiles WHERE id = v_channel.profile_id),
    'route_pending', v_channel.mathematics_route_filter_required AND NOT EXISTS (
      SELECT 1 FROM private.my_channels() c JOIN public.schools s ON s.id = c.school_id
      WHERE c.channel_id = p_channel AND s.mathematics_route_id IS NOT NULL
    ),
    'lessons', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', l.id, 'title', l.title, 'minutes', l.minutes,
        'topic', t.title, 'topic_ref', t.syllabus_ref,
        'review_status', l.review_status,
        'questions', (SELECT count(*) FROM public.questions q WHERE q.lesson_id = l.id),
        'answered', (
          SELECT count(DISTINCT a.question_id) FROM public.attempts a
          JOIN public.questions q ON q.id = a.question_id
          WHERE q.lesson_id = l.id AND a.user_id = auth.uid()
        )
      ) ORDER BY l.sort_order, l.title)
      FROM public.lessons l
      LEFT JOIN public.topics t ON t.id = l.topic_id
      WHERE l.channel_id = p_channel
        AND private.can_see_content(l.channel_id, l.school_id, l.review_status)
    ), '[]'::jsonb),
    -- A2 learners keep their AS prerequisites.
    'prerequisite_channel', CASE WHEN v_channel.as_prerequisite_links THEN (
      SELECT c.id FROM public.channels c
      WHERE c.profile_id = v_channel.profile_id AND c.stage = 'AS' LIMIT 1
    ) END
  );
END;
$$;

-- One lesson with its questions. No answers, solutions or rubrics.
CREATE OR REPLACE FUNCTION public.ace_lesson(p_lesson TEXT)
RETURNS JSONB
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_lesson public.lessons%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  SELECT * INTO v_lesson FROM public.lessons WHERE id = p_lesson;
  IF v_lesson.id IS NULL
     OR NOT private.can_see_content(v_lesson.channel_id, v_lesson.school_id, v_lesson.review_status) THEN
    RAISE EXCEPTION 'NOT_FOUND';
  END IF;

  RETURN jsonb_build_object(
    'id', v_lesson.id,
    'channel_id', v_lesson.channel_id,
    'stage', v_lesson.stage,
    'title', v_lesson.title,
    'minutes', v_lesson.minutes,
    'topic', (SELECT jsonb_build_object('ref', syllabus_ref, 'title', title)
              FROM public.topics WHERE id = v_lesson.topic_id),
    'objectives', to_jsonb(v_lesson.objectives),
    'prerequisites', to_jsonb(v_lesson.prerequisites),
    'explanation_markdown', v_lesson.explanation_markdown,
    'worked_example', v_lesson.worked_example,
    'common_errors', to_jsonb(v_lesson.common_errors),
    'exit_check', v_lesson.exit_check,
    'review_status', v_lesson.review_status,
    'provenance', v_lesson.provenance,
    'content_version', v_lesson.content_version,
    'questions', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', q.id,
        'kind', q.kind,
        'prompt_markdown', q.prompt_markdown,
        'parts', q.parts,
        'options', q.options,
        'max_marks', q.max_marks,
        'answer_unit', q.answer_unit,
        'exam_mode_response', q.exam_mode_response,
        'workings_required', q.workings_required_for_exam_mode,
        'content_version', q.content_version,
        'review_status', q.review_status,
        'attempts', (SELECT count(*) FROM public.attempts a
                     WHERE a.question_id = q.id AND a.user_id = auth.uid()),
        'last_status', (SELECT a.final_answer_status FROM public.attempts a
                        WHERE a.question_id = q.id AND a.user_id = auth.uid()
                        ORDER BY a.created_at DESC LIMIT 1)
      ) ORDER BY q.sort_order, q.id)
      FROM public.questions q
      WHERE q.lesson_id = v_lesson.id
        AND private.can_see_content(q.channel_id, q.school_id, q.review_status)
    ), '[]'::jsonb)
  );
END;
$$;

-- Attempts -------------------------------------------------------------------------------

-- Save the learner's response, check a supported final answer on the server,
-- and in practice mode return the worked solution. Never awards marks.
CREATE OR REPLACE FUNCTION public.ace_submit_attempt(
  p_question TEXT,
  p_response JSONB,
  p_mode TEXT DEFAULT 'practice'
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_q public.questions%ROWTYPE;
  v_key private.question_keys%ROWTYPE;
  v_school UUID;
  v_status TEXT;
  v_state TEXT;
  v_attempt_no INT;
  v_id UUID;
  v_working TEXT;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  IF p_mode NOT IN ('practice', 'assessment') THEN RAISE EXCEPTION 'INVALID_MODE'; END IF;
  IF p_response IS NULL OR jsonb_typeof(p_response) <> 'object'
     OR octet_length(p_response::text) > 20000 THEN
    RAISE EXCEPTION 'INVALID_RESPONSE';
  END IF;

  SELECT * INTO v_q FROM public.questions WHERE id = p_question;
  IF v_q.id IS NULL
     OR NOT private.can_see_content(v_q.channel_id, v_q.school_id, v_q.review_status) THEN
    RAISE EXCEPTION 'NOT_FOUND';
  END IF;
  -- Assessments are teacher-set (phase 4); practice is the only open mode now.
  IF p_mode = 'assessment' THEN RAISE EXCEPTION 'ASSESSMENT_NOT_OPEN'; END IF;

  SELECT * INTO v_key FROM private.question_keys
  WHERE question_id = v_q.id AND content_version = v_q.content_version;

  SELECT c.school_id INTO v_school FROM private.my_channels() c
  WHERE c.channel_id = v_q.channel_id
  ORDER BY (c.school_id = v_q.school_id) DESC NULLS LAST LIMIT 1;

  v_status := private.check_final_answer(
    v_q.kind, v_key.numeric_answer, v_key.correct_option, p_response
  );
  v_working := btrim(COALESCE(p_response->>'working_text', ''));
  v_state := CASE
    WHEN v_q.kind = 'constructed_response' THEN 'needs_review'
    WHEN v_working <> '' THEN 'needs_review'   -- written method: a teacher marks it
    ELSE 'final_answer_checked'
  END;

  SELECT COALESCE(max(attempt_no), 0) + 1 INTO v_attempt_no
  FROM public.attempts WHERE user_id = auth.uid() AND question_id = v_q.id;

  INSERT INTO public.attempts (
    user_id, school_id, question_id, question_version, attempt_no, mode,
    response, final_answer_status, marking_state
  ) VALUES (
    auth.uid(), v_school, v_q.id, v_q.content_version, v_attempt_no, p_mode,
    p_response, v_status, v_state
  ) RETURNING id INTO v_id;

  RETURN jsonb_build_object(
    'attempt_id', v_id,
    'attempt_no', v_attempt_no,
    'final_answer_status', v_status,
    'marking_state', v_state,
    'awarded_marks', NULL,
    'method_marks_require_teacher', TRUE,
    -- Practice: release the approved reference after the attempt.
    'feedback', jsonb_build_object(
      'correct_answer', v_key.answer_markdown,
      'correct_value', v_key.numeric_answer->'value',
      'unit', v_key.numeric_answer->'unit',
      'worked_solution', v_key.worked_solution,
      'max_marks', v_q.max_marks
    )
  );
END;
$$;

-- Learner's progress in a channel: questions tried and auto-checked results.
CREATE OR REPLACE FUNCTION public.ace_progress(p_channel TEXT)
RETURNS JSONB
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, private
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  RETURN (
    SELECT jsonb_build_object(
      'questions', count(*),
      'attempted', count(*) FILTER (WHERE x.tries > 0),
      'final_answer_matched', count(*) FILTER (WHERE x.matched),
      'awaiting_teacher', count(*) FILTER (WHERE x.review)
    )
    FROM (
      SELECT q.id,
        (SELECT count(*) FROM public.attempts a WHERE a.question_id = q.id AND a.user_id = auth.uid()) AS tries,
        EXISTS (SELECT 1 FROM public.attempts a WHERE a.question_id = q.id AND a.user_id = auth.uid()
                AND a.final_answer_status IN ('final_answer_match', 'option_match')) AS matched,
        EXISTS (SELECT 1 FROM public.attempts a WHERE a.question_id = q.id AND a.user_id = auth.uid()
                AND a.marking_state = 'needs_review') AS review
      FROM public.questions q
      WHERE q.channel_id = p_channel
        AND private.can_see_content(q.channel_id, q.school_id, q.review_status)
    ) x
  );
END;
$$;

REVOKE ALL ON FUNCTION public.ace_me(), public.ace_join_school(TEXT),
  public.ace_channel(TEXT), public.ace_lesson(TEXT),
  public.ace_submit_attempt(TEXT, JSONB, TEXT), public.ace_progress(TEXT)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ace_me(), public.ace_join_school(TEXT),
  public.ace_channel(TEXT), public.ace_lesson(TEXT),
  public.ace_submit_attempt(TEXT, JSONB, TEXT), public.ace_progress(TEXT)
  TO authenticated;

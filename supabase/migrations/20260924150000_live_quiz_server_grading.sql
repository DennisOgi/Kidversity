-- Grade live answers on the server, and keep the answer key off the
-- student payload until the quiz has ended or that student has submitted.

CREATE OR REPLACE FUNCTION private.validate_live_answer()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  question_test_id UUID;
  question_options JSONB;
BEGIN
  SELECT test_id, options
  INTO question_test_id, question_options
  FROM public.live_test_questions
  WHERE id = NEW.question_id;

  IF question_test_id IS NULL OR question_test_id <> NEW.test_id THEN
    RAISE EXCEPTION 'QUESTION_TEST_MISMATCH';
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.selected_option_id IS NOT NULL THEN
    NEW.selected_option_id := OLD.selected_option_id;
  END IF;

  NEW.is_correct := EXISTS (
    SELECT 1
    FROM jsonb_array_elements(question_options) option
    WHERE option->>'id' = NEW.selected_option_id
      AND COALESCE((option->>'is_correct')::boolean, FALSE)
  );
  NEW.answered_at := NOW();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.recalculate_live_participant()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  NEW.score := COALESCE((
    SELECT sum(question.points)
    FROM public.live_test_answers answer
    JOIN public.live_test_questions question ON question.id = answer.question_id
    WHERE answer.test_id = NEW.test_id
      AND answer.user_id = NEW.user_id
      AND answer.is_correct
  ), 0);
  NEW.correct_count := (
    SELECT count(*)::integer
    FROM public.live_test_answers answer
    WHERE answer.test_id = NEW.test_id
      AND answer.user_id = NEW.user_id
      AND answer.is_correct
  );
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.sync_live_score()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  UPDATE public.live_test_participants participant
  SET score = totals.score,
      correct_count = totals.correct_count
  FROM (
    SELECT
      COALESCE(sum(question.points) FILTER (WHERE answer.is_correct), 0)::integer AS score,
      count(*) FILTER (WHERE answer.is_correct)::integer AS correct_count
    FROM public.live_test_answers answer
    JOIN public.live_test_questions question ON question.id = answer.question_id
    WHERE answer.test_id = NEW.test_id
      AND answer.user_id = NEW.user_id
  ) totals
  WHERE participant.test_id = NEW.test_id
    AND participant.user_id = NEW.user_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS validate_live_answer ON public.live_test_answers;
CREATE TRIGGER validate_live_answer
  BEFORE INSERT OR UPDATE ON public.live_test_answers
  FOR EACH ROW EXECUTE FUNCTION private.validate_live_answer();

DROP TRIGGER IF EXISTS recalculate_live_participant
  ON public.live_test_participants;
CREATE TRIGGER recalculate_live_participant
  BEFORE INSERT OR UPDATE OF score, correct_count
  ON public.live_test_participants
  FOR EACH ROW EXECUTE FUNCTION private.recalculate_live_participant();

DROP TRIGGER IF EXISTS sync_live_score ON public.live_test_answers;
CREATE TRIGGER sync_live_score
  AFTER INSERT OR UPDATE ON public.live_test_answers
  FOR EACH ROW EXECUTE FUNCTION private.sync_live_score();

CREATE OR REPLACE FUNCTION public.live_questions_for_caller(p_test_id uuid)
RETURNS TABLE (
  id uuid,
  test_id uuid,
  order_index integer,
  prompt text,
  options jsonb,
  points integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
#variable_conflict use_column
DECLARE
  v_teacher uuid;
  v_status text;
  v_class uuid;
  v_reveal boolean;
BEGIN
  SELECT t.teacher_id, t.status, t.class_id
  INTO v_teacher, v_status, v_class
  FROM public.live_tests t
  WHERE t.id = p_test_id;

  IF v_teacher IS NULL THEN
    RETURN;
  END IF;

  IF v_teacher = auth.uid() THEN
    v_reveal := true;
  ELSIF v_status IN ('live', 'ended')
    AND v_class IS NOT NULL
    AND private.is_enrolled_in_class(v_class) THEN
    v_reveal := v_status = 'ended' OR EXISTS (
      SELECT 1
      FROM public.live_test_participants participant
      WHERE participant.test_id = p_test_id
        AND participant.user_id = auth.uid()
        AND participant.status = 'submitted'
    );
  ELSE
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    q.id,
    q.test_id,
    q.order_index,
    q.prompt,
    CASE
      WHEN v_reveal THEN q.options
      ELSE (
        SELECT COALESCE(
          jsonb_agg((entry.item - 'is_correct') ORDER BY entry.ord),
          '[]'::jsonb
        )
        FROM jsonb_array_elements(q.options)
          WITH ORDINALITY AS entry(item, ord)
      )
    END,
    q.points
  FROM public.live_test_questions q
  WHERE q.test_id = p_test_id
  ORDER BY q.order_index;
END;
$$;

REVOKE ALL ON FUNCTION public.live_questions_for_caller(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.live_questions_for_caller(uuid) TO authenticated;

DROP POLICY IF EXISTS "Participants read test questions" ON public.live_test_questions;
DROP POLICY IF EXISTS "Students read live questions" ON public.live_test_questions;

DROP POLICY IF EXISTS "Students manage own answers" ON public.live_test_answers;
DROP POLICY IF EXISTS "Students insert own answers" ON public.live_test_answers;
CREATE POLICY "Students insert own answers"
  ON public.live_test_answers FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Students update own answers" ON public.live_test_answers;
CREATE POLICY "Students update own answers"
  ON public.live_test_answers FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

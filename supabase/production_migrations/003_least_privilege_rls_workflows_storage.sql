-- Kidversity Plan B production baseline 3/5.
-- Least-privilege grants/RLS, private workflows, auth triggers, and audio storage.

REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA private TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA private
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.user_profiles(
    user_id,
    display_name,
    avatar_emoji,
    onboarding_complete
  )
  VALUES (
    NEW.id,
    COALESCE(
      NULLIF(BTRIM(NEW.raw_user_meta_data->>'display_name'), ''),
      split_part(COALESCE(NEW.email, 'Explorer'), '@', 1)
    ),
    COALESCE(NULLIF(NEW.raw_user_meta_data->>'avatar_emoji', ''), '🦊'),
    FALSE
  )
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.generate_class_code()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  alphabet CONSTANT TEXT := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  candidate TEXT;
BEGIN
  LOOP
    SELECT string_agg(substr(alphabet, floor(random() * length(alphabet) + 1)::int, 1), '')
    INTO candidate
    FROM generate_series(1, 6);
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM public.classes WHERE join_code = candidate
    );
  END LOOP;
  RETURN candidate;
END;
$$;

CREATE OR REPLACE FUNCTION private.set_class_join_code()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NEW.join_code IS NULL THEN
    NEW.join_code := private.generate_class_code();
  ELSE
    NEW.join_code := upper(trim(NEW.join_code));
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION private.handle_new_user();

DROP TRIGGER IF EXISTS set_user_profiles_updated_at ON public.user_profiles;
CREATE TRIGGER set_user_profiles_updated_at
  BEFORE UPDATE ON public.user_profiles
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();

DROP TRIGGER IF EXISTS set_classes_updated_at ON public.classes;
CREATE TRIGGER set_classes_updated_at
  BEFORE UPDATE ON public.classes
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();

DROP TRIGGER IF EXISTS set_course_lessons_updated_at ON public.course_lessons;
CREATE TRIGGER set_course_lessons_updated_at
  BEFORE UPDATE ON public.course_lessons
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();

DROP TRIGGER IF EXISTS set_class_join_code ON public.classes;
CREATE TRIGGER set_class_join_code
  BEFORE INSERT OR UPDATE OF join_code ON public.classes
  FOR EACH ROW EXECUTE FUNCTION private.set_class_join_code();

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

CREATE OR REPLACE FUNCTION private.is_class_teacher(p_class_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.classes
    WHERE id = p_class_id
      AND teacher_id = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION private.is_enrolled_in_class(p_class_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.class_members
    WHERE class_id = p_class_id
      AND user_id = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS TEXT
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
STABLE
AS $$
  SELECT CASE
    WHEN profile.role = 'reviewer' AND EXISTS (
      SELECT 1
      FROM public.reviewer_accounts reviewer
      WHERE reviewer.user_id = auth.uid()
        AND reviewer.active
    ) THEN 'reviewer'
    WHEN profile.role IN ('student', 'teacher') THEN profile.role
    ELSE NULL
  END
  FROM public.user_profiles profile
  WHERE profile.user_id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION private.join_class_with_code(
  p_user_id UUID,
  p_code TEXT
)
RETURNS TABLE(class_id UUID, class_name TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  target_id UUID;
  target_name TEXT;
BEGIN
  IF p_user_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM auth.users WHERE id = p_user_id
  ) THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  SELECT id, name
  INTO target_id, target_name
  FROM public.classes
  WHERE join_code = upper(trim(p_code));

  IF target_id IS NULL THEN
    RAISE EXCEPTION 'INVALID_CODE';
  END IF;

  INSERT INTO public.class_members(class_id, user_id)
  VALUES (target_id, p_user_id)
  ON CONFLICT (class_id, user_id) DO NOTHING;

  RETURN QUERY SELECT target_id, target_name;
END;
$$;

CREATE OR REPLACE FUNCTION private.regenerate_class_code(
  p_user_id UUID,
  p_class_id UUID
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  new_code TEXT;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.classes
    WHERE id = p_class_id
      AND teacher_id = p_user_id
  ) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  new_code := private.generate_class_code();
  UPDATE public.classes
  SET join_code = new_code
  WHERE id = p_class_id;
  RETURN new_code;
END;
$$;

CREATE OR REPLACE FUNCTION private.complete_foundation_lesson(
  p_user_id UUID,
  p_lesson_id TEXT,
  p_score INTEGER,
  p_answers JSONB,
  p_minutes INTEGER DEFAULT 10
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  first_completion BOOLEAN;
  lesson_sequence INTEGER;
  lesson_course_id TEXT;
  reward INTEGER;
BEGIN
  SELECT sequence, course_id, xp_reward
  INTO lesson_sequence, lesson_course_id, reward
  FROM public.course_lessons
  WHERE id = p_lesson_id
    AND status = 'approved';

  IF lesson_sequence IS NULL THEN
    RAISE EXCEPTION 'LESSON_NOT_APPROVED';
  END IF;

  IF lesson_sequence > 1 AND NOT EXISTS (
    SELECT 1
    FROM public.course_lessons previous
    JOIN public.lesson_results result
      ON result.lesson_id = previous.id
     AND result.user_id = p_user_id
    WHERE previous.course_id = lesson_course_id
      AND previous.sequence = lesson_sequence - 1
  ) THEN
    RAISE EXCEPTION 'PREVIOUS_LESSON_REQUIRED';
  END IF;

  INSERT INTO public.lesson_results(user_id, lesson_id, score, answers)
  VALUES (
    p_user_id,
    p_lesson_id,
    greatest(0, least(100, p_score)),
    COALESCE(p_answers, '[]'::jsonb)
  )
  ON CONFLICT (user_id, lesson_id) DO NOTHING;
  first_completion := FOUND;

  IF first_completion THEN
    UPDATE public.user_profiles
    SET xp = xp + greatest(0, reward),
        level = floor((xp + greatest(0, reward)) / 500.0)::integer + 1,
        streak_days = CASE
          WHEN last_activity_date = CURRENT_DATE THEN streak_days
          WHEN last_activity_date = CURRENT_DATE - 1 THEN streak_days + 1
          ELSE 1
        END,
        last_activity_date = CURRENT_DATE,
        lessons_completed = lessons_completed + 1,
        minutes_learned = minutes_learned + greatest(1, p_minutes)
    WHERE user_id = p_user_id;
  ELSE
    UPDATE public.lesson_results
    SET score = greatest(score, greatest(0, least(100, p_score))),
        answers = CASE
          WHEN p_score >= score THEN COALESCE(p_answers, answers)
          ELSE answers
        END,
        completed_at = NOW()
    WHERE user_id = p_user_id
      AND lesson_id = p_lesson_id;
  END IF;

  RETURN first_completion;
END;
$$;

CREATE OR REPLACE FUNCTION private.is_active_reviewer(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.reviewer_accounts reviewer
    JOIN public.user_profiles profile ON profile.user_id = reviewer.user_id
    WHERE reviewer.user_id = p_user_id
      AND reviewer.active
      AND profile.role = 'reviewer'
  );
$$;

CREATE OR REPLACE FUNCTION private.review_foundation_item(
  p_reviewer_id UUID,
  p_item_type TEXT,
  p_item_id TEXT,
  p_verdict TEXT,
  p_notes TEXT DEFAULT '',
  p_corrections JSONB DEFAULT '{}'::jsonb
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  next_version INTEGER;
BEGIN
  IF NOT private.is_active_reviewer(p_reviewer_id) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;
  IF p_verdict NOT IN ('approved', 'corrected', 'rejected') THEN
    RAISE EXCEPTION 'INVALID_VERDICT';
  END IF;

  CASE p_item_type
    WHEN 'lesson' THEN
      UPDATE public.course_lessons SET
        title = COALESCE(p_corrections->>'title', title),
        objective = COALESCE(p_corrections->>'objective', objective),
        explanation = COALESCE(p_corrections->>'explanation', explanation),
        metadata_review_status = p_verdict,
        status = CASE WHEN p_verdict = 'rejected' THEN 'ready' ELSE status END
      WHERE id = p_item_id;
    WHEN 'vocab' THEN
      UPDATE public.vocab_items SET
        simplified_chinese = COALESCE(p_corrections->>'chinese', simplified_chinese),
        pinyin = COALESCE(p_corrections->>'pinyin', pinyin),
        english_meaning = COALESCE(p_corrections->>'english', english_meaning),
        review_status = p_verdict
      WHERE id = p_item_id;
    WHEN 'example' THEN
      UPDATE public.examples SET
        chinese = COALESCE(p_corrections->>'chinese', chinese),
        pinyin = COALESCE(p_corrections->>'pinyin', pinyin),
        english = COALESCE(p_corrections->>'english', english),
        review_status = p_verdict
      WHERE id = p_item_id;
    WHEN 'grammar' THEN
      UPDATE public.grammar_patterns SET
        pattern = COALESCE(p_corrections->>'pattern', pattern),
        explanation = COALESCE(p_corrections->>'explanation', explanation),
        chinese = COALESCE(p_corrections->>'chinese', chinese),
        pinyin = COALESCE(p_corrections->>'pinyin', pinyin),
        english = COALESCE(p_corrections->>'english', english),
        review_status = p_verdict
      WHERE id = p_item_id;
    WHEN 'dialogue' THEN
      UPDATE public.dialogues SET
        chinese = COALESCE(p_corrections->>'chinese', chinese),
        pinyin = COALESCE(p_corrections->>'pinyin', pinyin),
        english = COALESCE(p_corrections->>'english', english),
        review_status = p_verdict
      WHERE id = p_item_id;
    WHEN 'activity' THEN
      UPDATE public.activities SET
        prompt = COALESCE(p_corrections->>'prompt', prompt),
        answer = COALESCE(p_corrections->>'answer', answer),
        explanation = COALESCE(p_corrections->>'explanation', explanation),
        review_status = p_verdict
      WHERE id = p_item_id;
    WHEN 'assessment' THEN
      UPDATE public.assessment_items SET
        question = COALESCE(p_corrections->>'question', question),
        correct_answer = COALESCE(p_corrections->>'answer', correct_answer),
        explanation = COALESCE(p_corrections->>'explanation', explanation),
        review_status = p_verdict
      WHERE id = p_item_id;
    WHEN 'audio' THEN
      UPDATE public.audio_clips SET
        audio_text = COALESCE(p_corrections->>'audio_text', audio_text),
        voice = COALESCE(p_corrections->>'voice', voice),
        review_status = p_verdict
      WHERE id::text = p_item_id;
    ELSE
      RAISE EXCEPTION 'INVALID_ITEM_TYPE';
  END CASE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ITEM_NOT_FOUND';
  END IF;

  SELECT COALESCE(MAX(version), 0) + 1
  INTO next_version
  FROM public.review_events
  WHERE item_type = p_item_type
    AND item_id = p_item_id;

  INSERT INTO public.review_events(
    item_type, item_id, reviewer_id, verdict, notes, version
  )
  VALUES (
    p_item_type, p_item_id, p_reviewer_id, p_verdict,
    COALESCE(p_notes, ''), next_version
  );
END;
$$;

CREATE OR REPLACE FUNCTION private.submit_foundation_lesson(
  p_reviewer_id UUID,
  p_lesson_id TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT private.is_active_reviewer(p_reviewer_id) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  UPDATE public.course_lessons
  SET status = 'in_review',
      submitted_at = NOW()
  WHERE id = p_lesson_id
    AND status IN ('ready', 'in_review');

  IF NOT FOUND THEN
    RAISE EXCEPTION 'LESSON_NOT_READY';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION private.publish_foundation_lesson(
  p_reviewer_id UUID,
  p_lesson_id TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  vocab_count INTEGER;
  activity_count INTEGER;
  assessment_count INTEGER;
  audio_count INTEGER;
  next_version INTEGER;
BEGIN
  IF NOT private.is_active_reviewer(p_reviewer_id) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.course_lessons
    WHERE id = p_lesson_id
      AND status = 'in_review'
  ) THEN
    RAISE EXCEPTION 'LESSON_NOT_IN_REVIEW';
  END IF;

  SELECT count(*) INTO vocab_count
  FROM public.vocab_items WHERE lesson_id = p_lesson_id;
  SELECT count(*) INTO activity_count
  FROM public.activities WHERE lesson_id = p_lesson_id;
  SELECT count(*) INTO assessment_count
  FROM public.assessment_items WHERE lesson_id = p_lesson_id;
  SELECT count(*) INTO audio_count
  FROM public.audio_clips WHERE lesson_id = p_lesson_id;

  IF vocab_count < 4 OR activity_count < 2
     OR assessment_count <> 5 OR audio_count = 0 THEN
    RAISE EXCEPTION 'CONTENT_REQUIREMENTS_NOT_MET';
  END IF;
  IF EXISTS (
    SELECT 1
    FROM (
      SELECT review_status FROM public.vocab_items WHERE lesson_id = p_lesson_id
      UNION ALL
      SELECT review_status FROM public.examples WHERE lesson_id = p_lesson_id
      UNION ALL
      SELECT review_status FROM public.grammar_patterns WHERE lesson_id = p_lesson_id
      UNION ALL
      SELECT review_status FROM public.dialogues WHERE lesson_id = p_lesson_id
      UNION ALL
      SELECT review_status FROM public.activities WHERE lesson_id = p_lesson_id
      UNION ALL
      SELECT review_status FROM public.assessment_items WHERE lesson_id = p_lesson_id
      UNION ALL
      SELECT review_status FROM public.audio_clips WHERE lesson_id = p_lesson_id
    ) reviewed
    WHERE review_status NOT IN ('approved', 'corrected')
  ) THEN
    RAISE EXCEPTION 'REVIEW_INCOMPLETE';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.course_lessons
    WHERE id = p_lesson_id
      AND metadata_review_status NOT IN ('approved', 'corrected')
  ) THEN
    RAISE EXCEPTION 'LESSON_METADATA_INCOMPLETE';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.audio_clips
    WHERE lesson_id = p_lesson_id
      AND (
        provider IS DISTINCT FROM 'google'
        OR storage_path IS NULL
        OR review_status NOT IN ('approved', 'corrected')
      )
  ) THEN
    RAISE EXCEPTION 'AUDIO_INCOMPLETE';
  END IF;

  UPDATE public.course_lessons
  SET status = 'approved',
      published_at = NOW(),
      published_by = p_reviewer_id
  WHERE id = p_lesson_id;

  SELECT COALESCE(MAX(version), 0) + 1
  INTO next_version
  FROM public.review_events
  WHERE item_type = 'lesson'
    AND item_id = p_lesson_id;

  INSERT INTO public.review_events(
    item_type, item_id, reviewer_id, verdict, notes, version
  )
  VALUES (
    'lesson', p_lesson_id, p_reviewer_id, 'approved',
    'Lesson published', next_version
  );
END;
$$;

CREATE OR REPLACE FUNCTION private.provision_reviewer(p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_user_id) THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;

  UPDATE public.user_profiles
  SET role = 'reviewer',
      onboarding_complete = TRUE
  WHERE user_id = p_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PROFILE_NOT_FOUND';
  END IF;

  INSERT INTO public.reviewer_accounts(user_id, active)
  VALUES (p_user_id, TRUE)
  ON CONFLICT (user_id) DO UPDATE
  SET active = TRUE,
      provisioned_at = NOW();
END;
$$;

REVOKE ALL ON FUNCTION public.current_user_role()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_user_role()
  TO authenticated;

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA private
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.is_class_teacher(UUID)
  TO authenticated;
GRANT EXECUTE ON FUNCTION private.is_enrolled_in_class(UUID)
  TO authenticated;

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon, authenticated;
GRANT SELECT ON public.user_profiles TO authenticated;
GRANT INSERT (
  user_id, display_name, avatar_emoji, role, onboarding_complete,
  age, gender, guardian_email, parental_consent_at, terms_accepted_at,
  preferences, updated_at
) ON public.user_profiles TO authenticated;
GRANT UPDATE (
  display_name, avatar_emoji, role, onboarding_complete,
  age, gender, guardian_email, parental_consent_at, terms_accepted_at,
  preferences, updated_at
) ON public.user_profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.classes TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.class_members TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.live_tests TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.live_test_questions TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.live_test_participants TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.live_test_answers TO authenticated;
GRANT SELECT ON public.courses, public.course_modules, public.course_lessons,
  public.content_sources, public.vocab_items, public.examples,
  public.grammar_patterns, public.dialogues, public.activities,
  public.assessment_items, public.audio_clips, public.curriculum_constraints,
  public.staged_sentences, public.speech_assets,
  public.tts_provider_evaluations, public.review_events,
  public.lesson_results, public.reviewer_accounts
  TO authenticated;
GRANT SELECT ON public.course_lessons TO anon;

DROP POLICY IF EXISTS "Users insert own profile" ON public.user_profiles;
CREATE POLICY "Users insert own profile"
  ON public.user_profiles FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid() AND role IS DISTINCT FROM 'reviewer');
DROP POLICY IF EXISTS "Users view own profile" ON public.user_profiles;
CREATE POLICY "Users view own profile"
  ON public.user_profiles FOR SELECT TO authenticated
  USING (user_id = auth.uid());
DROP POLICY IF EXISTS "Teachers view class learner profiles" ON public.user_profiles;
CREATE POLICY "Teachers view class learner profiles"
  ON public.user_profiles FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.class_members membership
      WHERE membership.user_id = user_profiles.user_id
        AND private.is_class_teacher(membership.class_id)
    )
  );
DROP POLICY IF EXISTS "Users update own profile" ON public.user_profiles;
CREATE POLICY "Users update own profile"
  ON public.user_profiles FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (
    user_id = auth.uid()
    AND (
      role IS DISTINCT FROM 'reviewer'
      OR EXISTS (
        SELECT 1 FROM public.reviewer_accounts
        WHERE user_id = auth.uid() AND active
      )
    )
  );

DROP POLICY IF EXISTS "Teachers manage own classes" ON public.classes;
CREATE POLICY "Teachers manage own classes"
  ON public.classes FOR ALL TO authenticated
  USING (teacher_id = auth.uid())
  WITH CHECK (teacher_id = auth.uid());
DROP POLICY IF EXISTS "Students view enrolled classes" ON public.classes;
CREATE POLICY "Students view enrolled classes"
  ON public.classes FOR SELECT TO authenticated
  USING (private.is_enrolled_in_class(id));
DROP POLICY IF EXISTS "Teachers manage class members" ON public.class_members;
CREATE POLICY "Teachers manage class members"
  ON public.class_members FOR ALL TO authenticated
  USING (private.is_class_teacher(class_id))
  WITH CHECK (private.is_class_teacher(class_id));
DROP POLICY IF EXISTS "Members view own class membership" ON public.class_members;
CREATE POLICY "Members view own class membership"
  ON public.class_members FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR private.is_class_teacher(class_id));

DROP POLICY IF EXISTS "Teachers manage own live tests" ON public.live_tests;
CREATE POLICY "Teachers manage own live tests"
  ON public.live_tests FOR ALL TO authenticated
  USING (teacher_id = auth.uid())
  WITH CHECK (
    teacher_id = auth.uid()
    AND (class_id IS NULL OR private.is_class_teacher(class_id))
  );
DROP POLICY IF EXISTS "Students read class live tests" ON public.live_tests;
CREATE POLICY "Students read class live tests"
  ON public.live_tests FOR SELECT TO authenticated
  USING (
    status IN ('live', 'ended')
    AND class_id IS NOT NULL
    AND private.is_enrolled_in_class(class_id)
  );
DROP POLICY IF EXISTS "Teachers manage live questions" ON public.live_test_questions;
CREATE POLICY "Teachers manage live questions"
  ON public.live_test_questions FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.live_tests test
      WHERE test.id = test_id AND test.teacher_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.live_tests test
      WHERE test.id = test_id AND test.teacher_id = auth.uid()
    )
  );
DROP POLICY IF EXISTS "Students read live questions" ON public.live_test_questions;
CREATE POLICY "Students read live questions"
  ON public.live_test_questions FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.live_tests test
      WHERE test.id = test_id
        AND test.status IN ('live', 'ended')
        AND test.class_id IS NOT NULL
        AND private.is_enrolled_in_class(test.class_id)
    )
  );
DROP POLICY IF EXISTS "Teachers read live participants" ON public.live_test_participants;
CREATE POLICY "Teachers read live participants"
  ON public.live_test_participants FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.live_tests test
      WHERE test.id = test_id AND test.teacher_id = auth.uid()
    )
  );
DROP POLICY IF EXISTS "Students manage own participation" ON public.live_test_participants;
CREATE POLICY "Students manage own participation"
  ON public.live_test_participants FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.live_tests test
      WHERE test.id = test_id
        AND test.status = 'live'
        AND test.class_id IS NOT NULL
        AND private.is_enrolled_in_class(test.class_id)
    )
  );
DROP POLICY IF EXISTS "Teachers read live answers" ON public.live_test_answers;
CREATE POLICY "Teachers read live answers"
  ON public.live_test_answers FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.live_tests test
      WHERE test.id = test_id AND test.teacher_id = auth.uid()
    )
  );
DROP POLICY IF EXISTS "Students manage own answers" ON public.live_test_answers;
CREATE POLICY "Students manage own answers"
  ON public.live_test_answers FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.live_tests test
      WHERE test.id = test_id
        AND test.status = 'live'
        AND test.class_id IS NOT NULL
        AND private.is_enrolled_in_class(test.class_id)
    )
  );

DROP POLICY IF EXISTS "Authenticated read course metadata" ON public.courses;
CREATE POLICY "Authenticated read course metadata"
  ON public.courses FOR SELECT TO authenticated USING (TRUE);
DROP POLICY IF EXISTS "Authenticated read module metadata" ON public.course_modules;
CREATE POLICY "Authenticated read module metadata"
  ON public.course_modules FOR SELECT TO authenticated USING (TRUE);
DROP POLICY IF EXISTS "Authenticated read content provenance" ON public.content_sources;
CREATE POLICY "Authenticated read content provenance"
  ON public.content_sources FOR SELECT TO authenticated USING (TRUE);
DROP POLICY IF EXISTS "Authenticated read curriculum constraints" ON public.curriculum_constraints;
CREATE POLICY "Authenticated read curriculum constraints"
  ON public.curriculum_constraints FOR SELECT TO authenticated USING (TRUE);
DROP POLICY IF EXISTS "Public reads approved lesson metadata" ON public.course_lessons;
CREATE POLICY "Public reads approved lesson metadata"
  ON public.course_lessons FOR SELECT TO anon
  USING (status = 'approved');
DROP POLICY IF EXISTS "Authenticated read lesson metadata" ON public.course_lessons;
CREATE POLICY "Authenticated read lesson metadata"
  ON public.course_lessons FOR SELECT TO authenticated
  USING (
    status IN ('shell', 'approved')
    OR public.current_user_role() IN ('teacher', 'reviewer')
  );

DO $$
DECLARE
  table_name TEXT;
  policy_name TEXT;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'vocab_items', 'examples', 'grammar_patterns', 'dialogues',
    'activities', 'assessment_items', 'audio_clips'
  ]
  LOOP
    policy_name := 'Learners read approved ' || table_name;
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', policy_name, table_name);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING (
        (
          review_status IN (''approved'', ''corrected'')
          AND EXISTS (
            SELECT 1 FROM public.course_lessons lesson
            WHERE lesson.id = lesson_id AND lesson.status = ''approved''
          )
        )
        OR public.current_user_role() = ''reviewer''
      )',
      policy_name,
      table_name
    );
  END LOOP;
END;
$$;

DROP POLICY IF EXISTS "Reviewers view own account" ON public.reviewer_accounts;
CREATE POLICY "Reviewers view own account"
  ON public.reviewer_accounts FOR SELECT TO authenticated
  USING (user_id = auth.uid());
DROP POLICY IF EXISTS "Reviewers read staged sentences" ON public.staged_sentences;
CREATE POLICY "Reviewers read staged sentences"
  ON public.staged_sentences FOR SELECT TO authenticated
  USING (public.current_user_role() = 'reviewer');
DROP POLICY IF EXISTS "Reviewers read speech assets" ON public.speech_assets;
CREATE POLICY "Reviewers read speech assets"
  ON public.speech_assets FOR SELECT TO authenticated
  USING (public.current_user_role() = 'reviewer');
DROP POLICY IF EXISTS "Reviewers read TTS evaluations" ON public.tts_provider_evaluations;
CREATE POLICY "Reviewers read TTS evaluations"
  ON public.tts_provider_evaluations FOR SELECT TO authenticated
  USING (public.current_user_role() = 'reviewer');
DROP POLICY IF EXISTS "Reviewers read review events" ON public.review_events;
CREATE POLICY "Reviewers read review events"
  ON public.review_events FOR SELECT TO authenticated
  USING (public.current_user_role() = 'reviewer');
DROP POLICY IF EXISTS "Users view own Foundation results" ON public.lesson_results;
CREATE POLICY "Users view own Foundation results"
  ON public.lesson_results FOR SELECT TO authenticated
  USING (user_id = auth.uid());
DROP POLICY IF EXISTS "Teachers view class Foundation results" ON public.lesson_results;
CREATE POLICY "Teachers view class Foundation results"
  ON public.lesson_results FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.class_members membership
      WHERE membership.user_id = lesson_results.user_id
        AND private.is_class_teacher(membership.class_id)
    )
  );

INSERT INTO storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'mandarin-audio',
  'mandarin-audio',
  FALSE,
  10485760,
  ARRAY['audio/mpeg', 'audio/mp3']
)
ON CONFLICT (id) DO UPDATE
SET public = FALSE,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "Authenticated read approved Mandarin audio"
  ON storage.objects;
CREATE POLICY "Authenticated read approved Mandarin audio"
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'mandarin-audio'
    AND EXISTS (
      SELECT 1
      FROM public.audio_clips clip
      JOIN public.course_lessons lesson ON lesson.id = clip.lesson_id
      WHERE clip.storage_path = name
        AND (
          (
            clip.review_status IN ('approved', 'corrected')
            AND lesson.status = 'approved'
          )
          OR public.current_user_role() = 'reviewer'
        )
    )
  );

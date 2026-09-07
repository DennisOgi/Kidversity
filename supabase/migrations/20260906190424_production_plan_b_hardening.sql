-- Final production hardening for the Mandarin Foundation product.

DROP TRIGGER IF EXISTS on_auth_user_auto_confirm ON auth.users;
DROP FUNCTION IF EXISTS public.auto_confirm_new_user();
DROP EVENT TRIGGER IF EXISTS ensure_rls;
DROP FUNCTION IF EXISTS public.rls_auto_enable();

ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS age INTEGER CHECK (age BETWEEN 7 AND 120),
  ADD COLUMN IF NOT EXISTS gender TEXT,
  ADD COLUMN IF NOT EXISTS guardian_email TEXT,
  ADD COLUMN IF NOT EXISTS parental_consent_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS terms_accepted_at TIMESTAMPTZ;

ALTER TABLE public.course_lessons
  ADD COLUMN IF NOT EXISTS submitted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS published_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS published_by UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS metadata_review_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (metadata_review_status IN ('pending', 'approved', 'corrected', 'rejected'));

ALTER TABLE public.audio_clips
  ADD COLUMN IF NOT EXISTS storage_path TEXT,
  ADD COLUMN IF NOT EXISTS text_hash TEXT,
  ADD COLUMN IF NOT EXISTS generated_at TIMESTAMPTZ;

ALTER TABLE public.review_events
  ADD COLUMN IF NOT EXISTS corrections JSONB NOT NULL DEFAULT '{}'::jsonb;

CREATE UNIQUE INDEX IF NOT EXISTS idx_audio_clips_item
  ON public.audio_clips(lesson_id, item_type, item_id);
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
CREATE INDEX IF NOT EXISTS idx_review_events_item
  ON public.review_events(item_type, item_id, created_at DESC);

UPDATE public.audio_clips
SET provider = NULL,
    audio_url = NULL,
    storage_path = NULL,
    text_hash = NULL,
    generated_at = NULL,
    review_status = 'pending'
WHERE provider = 'device_tts';

UPDATE public.course_lessons lesson
SET status = 'in_review',
    submitted_at = COALESCE(submitted_at, NOW()),
    updated_at = NOW()
WHERE lesson.status = 'approved'
  AND EXISTS (
    SELECT 1 FROM public.audio_clips clip
    WHERE clip.lesson_id = lesson.id
      AND clip.review_status = 'pending'
  );

UPDATE public.course_lessons
SET metadata_review_status = 'approved'
WHERE sequence <= 3;

DROP POLICY IF EXISTS "Reviewers view own account" ON public.reviewer_accounts;
CREATE POLICY "Reviewers view own account"
  ON public.reviewer_accounts
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS TEXT
LANGUAGE sql
SECURITY INVOKER
SET search_path = public
STABLE
AS $$
  SELECT CASE
    WHEN profile.role = 'reviewer' AND EXISTS (
      SELECT 1 FROM public.reviewer_accounts reviewer
      WHERE reviewer.user_id = auth.uid() AND reviewer.active
    ) THEN 'reviewer'
    WHEN profile.role IN ('student', 'teacher') THEN profile.role
    ELSE NULL
  END
  FROM public.user_profiles profile
  WHERE profile.user_id = auth.uid();
$$;

REVOKE ALL ON FUNCTION public.current_user_role() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_user_role() TO authenticated;

DROP POLICY IF EXISTS "Reviewers manage lesson content"
  ON public.course_lessons;
DROP POLICY IF EXISTS "Reviewers record review events"
  ON public.review_events;
DROP POLICY IF EXISTS "Reviewers manage staged sentences"
  ON public.staged_sentences;
DROP POLICY IF EXISTS "Reviewers manage speech research assets"
  ON public.speech_assets;
DROP POLICY IF EXISTS "Reviewers manage TTS evaluations"
  ON public.tts_provider_evaluations;

CREATE POLICY "Reviewers read staged sentences"
  ON public.staged_sentences FOR SELECT TO authenticated
  USING (public.current_user_role() = 'reviewer');
CREATE POLICY "Reviewers read speech research assets"
  ON public.speech_assets FOR SELECT TO authenticated
  USING (public.current_user_role() = 'reviewer');
CREATE POLICY "Reviewers read TTS evaluations"
  ON public.tts_provider_evaluations FOR SELECT TO authenticated
  USING (public.current_user_role() = 'reviewer');

DROP POLICY IF EXISTS "Public reads published lesson metadata"
  ON public.course_lessons;
CREATE POLICY "Public reads published lesson metadata"
  ON public.course_lessons FOR SELECT TO anon
  USING (status = 'approved');

DROP POLICY IF EXISTS "Students read approved lesson metadata"
  ON public.course_lessons;
CREATE POLICY "Students read approved lesson metadata"
  ON public.course_lessons FOR SELECT TO authenticated
  USING (
    status = 'approved'
    OR public.current_user_role() IN ('teacher', 'reviewer')
  );

CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA private TO authenticated;

CREATE OR REPLACE FUNCTION private.is_class_teacher(p_class_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, private
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.classes
    WHERE id = p_class_id AND teacher_id = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION private.is_enrolled_in_class(p_class_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, private
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.class_members
    WHERE class_id = p_class_id AND user_id = auth.uid()
  );
$$;

GRANT EXECUTE ON FUNCTION private.is_class_teacher(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION private.is_enrolled_in_class(UUID) TO authenticated;

DROP FUNCTION IF EXISTS public.is_class_teacher(UUID) CASCADE;
DROP FUNCTION IF EXISTS public.is_enrolled_in_class(UUID) CASCADE;

DROP POLICY IF EXISTS "Teachers manage own classes" ON public.classes;
DROP POLICY IF EXISTS "Students view enrolled classes" ON public.classes;
DROP POLICY IF EXISTS "Teachers manage class members" ON public.class_members;
DROP POLICY IF EXISTS "Members view own class membership" ON public.class_members;

CREATE POLICY "Teachers manage own classes"
  ON public.classes FOR ALL TO authenticated
  USING (auth.uid() = teacher_id)
  WITH CHECK (auth.uid() = teacher_id);
CREATE POLICY "Students view enrolled classes"
  ON public.classes FOR SELECT TO authenticated
  USING (private.is_enrolled_in_class(id));
CREATE POLICY "Teachers manage class members"
  ON public.class_members FOR ALL TO authenticated
  USING (private.is_class_teacher(class_id))
  WITH CHECK (private.is_class_teacher(class_id));
CREATE POLICY "Members view own class membership"
  ON public.class_members FOR SELECT TO authenticated
  USING (auth.uid() = user_id OR private.is_class_teacher(class_id));

CREATE OR REPLACE FUNCTION private.join_class_with_code(
  p_user_id UUID,
  p_code TEXT
)
RETURNS TABLE(class_id UUID, class_name TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_class_id UUID;
  v_class_name TEXT;
BEGIN
  SELECT id, name INTO v_class_id, v_class_name
  FROM public.classes
  WHERE join_code = upper(trim(p_code));

  IF v_class_id IS NULL THEN
    RAISE EXCEPTION 'INVALID_CODE';
  END IF;

  INSERT INTO public.class_members(class_id, user_id)
  VALUES (v_class_id, p_user_id)
  ON CONFLICT(class_id, user_id) DO NOTHING;

  RETURN QUERY SELECT v_class_id, v_class_name;
END;
$$;

CREATE OR REPLACE FUNCTION private.regenerate_class_code(
  p_user_id UUID,
  p_class_id UUID
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_code TEXT;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.classes
    WHERE id = p_class_id AND teacher_id = p_user_id
  ) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  v_code := public.generate_class_code();
  UPDATE public.classes
  SET join_code = v_code, updated_at = NOW()
  WHERE id = p_class_id;
  RETURN v_code;
END;
$$;

DROP FUNCTION IF EXISTS public.join_class_with_code(TEXT);
DROP FUNCTION IF EXISTS public.regenerate_class_code(UUID);

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
SET search_path = public, private
AS $$
DECLARE
  v_inserted INTEGER;
  v_sequence INTEGER;
  v_reward INTEGER;
BEGIN
  SELECT sequence, xp_reward
  INTO v_sequence, v_reward
  FROM public.course_lessons
  WHERE id = p_lesson_id AND status = 'approved';

  IF v_sequence IS NULL THEN
    RAISE EXCEPTION 'LESSON_NOT_APPROVED';
  END IF;

  IF v_sequence > 1 AND NOT EXISTS (
    SELECT 1
    FROM public.course_lessons previous
    JOIN public.lesson_results result
      ON result.lesson_id = previous.id
     AND result.user_id = p_user_id
    WHERE previous.course_id = 'mandarin_foundation_v1'
      AND previous.sequence = v_sequence - 1
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
  ON CONFLICT(user_id, lesson_id) DO NOTHING;
  GET DIAGNOSTICS v_inserted = ROW_COUNT;

  IF v_inserted = 1 THEN
    UPDATE public.user_profiles
    SET xp = xp + greatest(0, v_reward),
        level = floor((xp + greatest(0, v_reward)) / 500.0) + 1,
        streak_days = CASE
          WHEN last_activity_date = CURRENT_DATE THEN streak_days
          WHEN last_activity_date = CURRENT_DATE - 1 THEN streak_days + 1
          ELSE 1
        END,
        last_activity_date = CURRENT_DATE,
        lessons_completed = lessons_completed + 1,
        minutes_learned = minutes_learned + greatest(1, p_minutes),
        updated_at = NOW()
    WHERE user_id = p_user_id;
  ELSE
    UPDATE public.lesson_results
    SET score = greatest(score, greatest(0, least(100, p_score))),
        answers = CASE
          WHEN p_score >= score THEN COALESCE(p_answers, answers)
          ELSE answers
        END,
        completed_at = NOW()
    WHERE user_id = p_user_id AND lesson_id = p_lesson_id;
  END IF;

  RETURN v_inserted = 1;
END;
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
SET search_path = public, private
AS $$
DECLARE
  v_status TEXT;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.reviewer_accounts reviewer
    JOIN public.user_profiles profile ON profile.user_id = reviewer.user_id
    WHERE reviewer.user_id = p_reviewer_id
      AND reviewer.active
      AND profile.role = 'reviewer'
  ) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  IF p_verdict NOT IN ('approved', 'corrected', 'rejected') THEN
    RAISE EXCEPTION 'INVALID_VERDICT';
  END IF;
  v_status := p_verdict;

  CASE p_item_type
    WHEN 'lesson' THEN
      UPDATE public.course_lessons SET
        title = COALESCE(p_corrections->>'title', title),
        objective = COALESCE(p_corrections->>'objective', objective),
        explanation = COALESCE(p_corrections->>'explanation', explanation),
        metadata_review_status = v_status,
        status = CASE WHEN p_verdict = 'rejected' THEN 'ready' ELSE status END,
        updated_at = NOW()
      WHERE id = p_item_id;
    WHEN 'vocab' THEN
      UPDATE public.vocab_items SET
        simplified_chinese = COALESCE(p_corrections->>'chinese', simplified_chinese),
        pinyin = COALESCE(p_corrections->>'pinyin', pinyin),
        english_meaning = COALESCE(p_corrections->>'english', english_meaning),
        review_status = v_status
      WHERE id = p_item_id;
    WHEN 'example' THEN
      UPDATE public.examples SET
        chinese = COALESCE(p_corrections->>'chinese', chinese),
        pinyin = COALESCE(p_corrections->>'pinyin', pinyin),
        english = COALESCE(p_corrections->>'english', english),
        review_status = v_status
      WHERE id = p_item_id;
    WHEN 'grammar' THEN
      UPDATE public.grammar_patterns SET
        pattern = COALESCE(p_corrections->>'pattern', pattern),
        explanation = COALESCE(p_corrections->>'explanation', explanation),
        chinese = COALESCE(p_corrections->>'chinese', chinese),
        pinyin = COALESCE(p_corrections->>'pinyin', pinyin),
        english = COALESCE(p_corrections->>'english', english),
        review_status = v_status
      WHERE id = p_item_id;
    WHEN 'dialogue' THEN
      UPDATE public.dialogues SET
        chinese = COALESCE(p_corrections->>'chinese', chinese),
        pinyin = COALESCE(p_corrections->>'pinyin', pinyin),
        english = COALESCE(p_corrections->>'english', english),
        review_status = v_status
      WHERE id = p_item_id;
    WHEN 'activity' THEN
      UPDATE public.activities SET
        prompt = COALESCE(p_corrections->>'prompt', prompt),
        answer = COALESCE(p_corrections->>'answer', answer),
        explanation = COALESCE(p_corrections->>'explanation', explanation),
        review_status = v_status
      WHERE id = p_item_id;
    WHEN 'assessment' THEN
      UPDATE public.assessment_items SET
        question = COALESCE(p_corrections->>'question', question),
        correct_answer = COALESCE(p_corrections->>'answer', correct_answer),
        explanation = COALESCE(p_corrections->>'explanation', explanation),
        review_status = v_status
      WHERE id = p_item_id;
    WHEN 'audio' THEN
      UPDATE public.audio_clips SET
        review_status = v_status
      WHERE id::text = p_item_id;
    ELSE
      RAISE EXCEPTION 'INVALID_ITEM_TYPE';
  END CASE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ITEM_NOT_FOUND';
  END IF;

  IF p_verdict = 'corrected'
    AND p_item_type IN ('vocab', 'dialogue', 'activity', 'assessment')
  THEN
    UPDATE public.audio_clips clip
    SET audio_text = CASE p_item_type
          WHEN 'vocab' THEN (
            SELECT simplified_chinese FROM public.vocab_items WHERE id = p_item_id
          )
          WHEN 'dialogue' THEN (
            SELECT chinese FROM public.dialogues WHERE id = p_item_id
          )
          WHEN 'activity' THEN (
            SELECT answer FROM public.activities WHERE id = p_item_id
          )
          WHEN 'assessment' THEN (
            SELECT correct_answer FROM public.assessment_items WHERE id = p_item_id
          )
        END,
        storage_path = NULL,
        text_hash = NULL,
        provider = NULL,
        voice = NULL,
        generated_at = NULL,
        review_status = 'pending'
    WHERE clip.item_type = p_item_type AND clip.item_id = p_item_id;
  END IF;

  INSERT INTO public.review_events(
    item_type,
    item_id,
    reviewer_id,
    verdict,
    notes,
    corrections,
    version
  )
  SELECT
    p_item_type,
    p_item_id,
    p_reviewer_id,
    p_verdict,
    COALESCE(p_notes, ''),
    COALESCE(p_corrections, '{}'::jsonb),
    COALESCE(MAX(version), 0) + 1
  FROM public.review_events
  WHERE item_type = p_item_type AND item_id = p_item_id;
END;
$$;

CREATE OR REPLACE FUNCTION private.submit_foundation_lesson(
  p_reviewer_id UUID,
  p_lesson_id TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.reviewer_accounts
    WHERE user_id = p_reviewer_id AND active
  ) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  UPDATE public.course_lessons
  SET status = 'in_review', submitted_at = NOW(), updated_at = NOW()
  WHERE id = p_lesson_id AND status IN ('ready', 'in_review');

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
SET search_path = public, private
AS $$
DECLARE
  v_vocab INTEGER;
  v_examples INTEGER;
  v_grammar INTEGER;
  v_dialogue INTEGER;
  v_activities INTEGER;
  v_assessments INTEGER;
  v_required_audio INTEGER;
  v_expected_audio INTEGER;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.reviewer_accounts
    WHERE user_id = p_reviewer_id AND active
  ) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.course_lessons
    WHERE id = p_lesson_id AND status = 'in_review'
  ) THEN
    RAISE EXCEPTION 'LESSON_NOT_IN_REVIEW';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.course_lessons lesson
    WHERE lesson.id = p_lesson_id
      AND lesson.sequence > 1
      AND NOT EXISTS (
        SELECT 1 FROM public.course_lessons previous
        WHERE previous.course_id = lesson.course_id
          AND previous.sequence = lesson.sequence - 1
          AND previous.status = 'approved'
      )
  ) THEN
    RAISE EXCEPTION 'PREVIOUS_LESSON_NOT_PUBLISHED';
  END IF;

  SELECT count(*) INTO v_vocab FROM public.vocab_items WHERE lesson_id = p_lesson_id;
  SELECT count(*) INTO v_examples FROM public.examples WHERE lesson_id = p_lesson_id;
  SELECT count(*) INTO v_grammar FROM public.grammar_patterns WHERE lesson_id = p_lesson_id;
  SELECT count(*) INTO v_dialogue FROM public.dialogues WHERE lesson_id = p_lesson_id;
  SELECT count(*) INTO v_activities FROM public.activities WHERE lesson_id = p_lesson_id;
  SELECT count(*) INTO v_assessments FROM public.assessment_items WHERE lesson_id = p_lesson_id;
  SELECT count(*) INTO v_required_audio FROM public.audio_clips WHERE lesson_id = p_lesson_id;
  SELECT
    (SELECT count(*) FROM public.vocab_items WHERE lesson_id = p_lesson_id)
    + (SELECT count(*) FROM public.dialogues WHERE lesson_id = p_lesson_id)
    + (SELECT count(*) FROM public.activities
       WHERE lesson_id = p_lesson_id AND type = 'listen_tap')
    + (SELECT count(*) FROM public.assessment_items
       WHERE lesson_id = p_lesson_id AND type = 'listen_tap')
  INTO v_expected_audio;

  IF v_vocab < 4
    OR v_examples < 2
    OR v_grammar < 1
    OR v_dialogue < 2
    OR v_activities < 2
    OR v_assessments <> 5
    OR v_required_audio < v_expected_audio
  THEN
    RAISE EXCEPTION 'CONTENT_REQUIREMENTS_NOT_MET';
  END IF;

  IF EXISTS (
    SELECT 1 FROM (
      SELECT review_status FROM public.vocab_items WHERE lesson_id = p_lesson_id
      UNION ALL SELECT review_status FROM public.examples WHERE lesson_id = p_lesson_id
      UNION ALL SELECT review_status FROM public.grammar_patterns WHERE lesson_id = p_lesson_id
      UNION ALL SELECT review_status FROM public.dialogues WHERE lesson_id = p_lesson_id
      UNION ALL SELECT review_status FROM public.activities WHERE lesson_id = p_lesson_id
      UNION ALL SELECT review_status FROM public.assessment_items WHERE lesson_id = p_lesson_id
      UNION ALL SELECT review_status FROM public.audio_clips WHERE lesson_id = p_lesson_id
    ) item
    WHERE item.review_status NOT IN ('approved', 'corrected')
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
      AND (storage_path IS NULL OR provider <> 'google')
  ) THEN
    RAISE EXCEPTION 'AUDIO_INCOMPLETE';
  END IF;

  UPDATE public.course_lessons
  SET status = 'approved',
      published_at = NOW(),
      published_by = p_reviewer_id,
      updated_at = NOW()
  WHERE id = p_lesson_id;

  INSERT INTO public.review_events(
    item_type, item_id, reviewer_id, verdict, notes
  )
  VALUES ('lesson', p_lesson_id, p_reviewer_id, 'approved', 'Lesson published');
END;
$$;

CREATE OR REPLACE FUNCTION private.provision_reviewer(
  p_user_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_user_id) THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;

  UPDATE public.user_profiles
  SET role = 'reviewer', onboarding_complete = TRUE, updated_at = NOW()
  WHERE user_id = p_user_id;

  INSERT INTO public.reviewer_accounts(user_id, active)
  VALUES (p_user_id, TRUE)
  ON CONFLICT(user_id) DO UPDATE SET active = TRUE, provisioned_at = NOW();
END;
$$;

CREATE OR REPLACE FUNCTION private.prevent_review_event_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, private
AS $$
BEGIN
  RAISE EXCEPTION 'REVIEW_EVENTS_ARE_IMMUTABLE';
END;
$$;

DROP TRIGGER IF EXISTS trg_review_events_immutable ON public.review_events;
CREATE TRIGGER trg_review_events_immutable
  BEFORE UPDATE OR DELETE ON public.review_events
  FOR EACH ROW EXECUTE FUNCTION private.prevent_review_event_mutation();

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA private
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.is_class_teacher(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION private.is_enrolled_in_class(UUID) TO authenticated;

DROP FUNCTION IF EXISTS public.review_foundation_item(
  TEXT, TEXT, TEXT, TEXT, JSONB
);
DROP FUNCTION IF EXISTS public.complete_foundation_lesson(
  TEXT, INTEGER, JSONB, INTEGER, INTEGER
);
DROP FUNCTION IF EXISTS public.award_xp(UUID, INTEGER, TEXT, UUID);
DROP FUNCTION IF EXISTS public.unlock_user_badge(UUID, TEXT);
DROP FUNCTION IF EXISTS public.update_user_streak(UUID);

DELETE FROM public.reviewer_accounts reviewer
USING auth.users user_account
WHERE reviewer.user_id = user_account.id
  AND user_account.email LIKE '%@kidversity.demo';

DELETE FROM public.user_profiles profile
USING auth.users user_account
WHERE profile.user_id = user_account.id
  AND user_account.email LIKE '%@kidversity.demo';

DROP TABLE IF EXISTS public.lesson_assignments CASCADE;
DROP TABLE IF EXISTS public.lesson_progress CASCADE;
DROP TABLE IF EXISTS public.uploaded_files CASCADE;
DROP TABLE IF EXISTS public.user_badges CASCADE;
DROP TABLE IF EXISTS public.badges CASCADE;
DROP TABLE IF EXISTS public.xp_logs CASCADE;
DROP TABLE IF EXISTS public.lessons CASCADE;

INSERT INTO storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'mandarin-audio',
  'mandarin-audio',
  FALSE,
  10485760,
  ARRAY['audio/mpeg', 'audio/mp3']
)
ON CONFLICT(id) DO UPDATE SET
  public = FALSE,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "Authenticated users read approved Mandarin audio"
  ON storage.objects;
CREATE POLICY "Authenticated users read approved Mandarin audio"
  ON storage.objects
  FOR SELECT TO authenticated
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

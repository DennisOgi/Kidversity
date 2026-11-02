-- 1. Evaluate auth.uid() once per query, not once per row, in every policy.
DO $$
DECLARE
  pol RECORD;
  new_qual TEXT;
  new_check TEXT;
  stmt TEXT;
BEGIN
  FOR pol IN
    SELECT schemaname, tablename, policyname, qual, with_check
    FROM pg_policies
    WHERE schemaname = 'public'
      AND (qual LIKE '%auth.uid()%' OR with_check LIKE '%auth.uid()%')
      AND COALESCE(qual, '') NOT LIKE '%SELECT auth.uid()%'
      AND COALESCE(with_check, '') NOT LIKE '%SELECT auth.uid()%'
  LOOP
    new_qual := replace(pol.qual, 'auth.uid()', '(SELECT auth.uid())');
    new_check := replace(pol.with_check, 'auth.uid()', '(SELECT auth.uid())');
    stmt := format('ALTER POLICY %I ON %I.%I', pol.policyname, pol.schemaname, pol.tablename);
    IF new_qual IS NOT NULL THEN
      stmt := stmt || format(' USING (%s)', new_qual);
    END IF;
    IF new_check IS NOT NULL THEN
      stmt := stmt || format(' WITH CHECK (%s)', new_check);
    END IF;
    EXECUTE stmt;
  END LOOP;
END $$;

-- 2. Cover foreign keys the advisor flagged.
CREATE INDEX IF NOT EXISTS idx_activities_source ON public.activities (source_id);
CREATE INDEX IF NOT EXISTS idx_assessment_items_source ON public.assessment_items (source_id);
CREATE INDEX IF NOT EXISTS idx_assignment_submissions_user ON public.assignment_submissions (user_id);
CREATE INDEX IF NOT EXISTS idx_audio_clips_source ON public.audio_clips (source_id);
CREATE INDEX IF NOT EXISTS idx_class_assignments_teacher ON public.class_assignments (teacher_id);
CREATE INDEX IF NOT EXISTS idx_course_lessons_published_by ON public.course_lessons (published_by);
CREATE INDEX IF NOT EXISTS idx_course_modules_quest_lesson ON public.course_modules (quest_lesson_id);
CREATE INDEX IF NOT EXISTS idx_curriculum_constraints_source ON public.curriculum_constraints (source_id);
CREATE INDEX IF NOT EXISTS idx_dialogues_source ON public.dialogues (source_id);
CREATE INDEX IF NOT EXISTS idx_exam_attempts_assignment ON public.exam_attempts (assignment_id);
CREATE INDEX IF NOT EXISTS idx_examples_source ON public.examples (source_id);
CREATE INDEX IF NOT EXISTS idx_grammar_patterns_lesson ON public.grammar_patterns (lesson_id);
CREATE INDEX IF NOT EXISTS idx_grammar_patterns_source ON public.grammar_patterns (source_id);
CREATE INDEX IF NOT EXISTS idx_lesson_results_lesson ON public.lesson_results (lesson_id);
CREATE INDEX IF NOT EXISTS idx_live_test_answers_question ON public.live_test_answers (question_id);
CREATE INDEX IF NOT EXISTS idx_live_test_answers_user ON public.live_test_answers (user_id);
CREATE INDEX IF NOT EXISTS idx_live_test_participants_user ON public.live_test_participants (user_id);
CREATE INDEX IF NOT EXISTS idx_payment_entitlements_credit ON public.payment_entitlements (credit_id);
CREATE INDEX IF NOT EXISTS idx_payment_pack_credits_family ON public.payment_pack_credits (family_id);
CREATE INDEX IF NOT EXISTS idx_review_events_reviewer ON public.review_events (reviewer_id);
CREATE INDEX IF NOT EXISTS idx_speech_assets_source ON public.speech_assets (source_id);
CREATE INDEX IF NOT EXISTS idx_staged_sentences_source ON public.staged_sentences (source_id);
CREATE INDEX IF NOT EXISTS idx_tts_provider_evaluations_reviewer ON public.tts_provider_evaluations (reviewer_id);
CREATE INDEX IF NOT EXISTS idx_vocab_items_source ON public.vocab_items (source_id);

-- 3. Sign-up accepts learners from age 5; the profile check said 7.
ALTER TABLE public.user_profiles DROP CONSTRAINT IF EXISTS user_profiles_age_check;
ALTER TABLE public.user_profiles
  ADD CONSTRAINT user_profiles_age_check CHECK (age IS NULL OR (age >= 5 AND age <= 120));

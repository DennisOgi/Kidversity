-- Kidversity Plan B production baseline 5/5.
-- Static post-migration assertions. This file changes no application data.

DO $$
DECLARE
  expected_table TEXT;
  legacy_table TEXT;
  missing_tables TEXT[] := ARRAY[]::TEXT[];
  missing_rls TEXT[] := ARRAY[]::TEXT[];
BEGIN
  FOREACH expected_table IN ARRAY ARRAY[
    'user_profiles', 'classes', 'class_members',
    'live_tests', 'live_test_questions', 'live_test_participants',
    'live_test_answers', 'reviewer_accounts', 'courses', 'course_modules',
    'course_lessons', 'content_sources', 'vocab_items', 'examples',
    'grammar_patterns', 'dialogues', 'activities', 'assessment_items',
    'audio_clips', 'curriculum_constraints', 'staged_sentences',
    'speech_assets', 'tts_provider_evaluations', 'review_events',
    'lesson_results'
  ]
  LOOP
    IF to_regclass(format('public.%I', expected_table)) IS NULL THEN
      missing_tables := array_append(missing_tables, expected_table);
    ELSIF NOT (
      SELECT class.relrowsecurity
      FROM pg_class class
      WHERE class.oid = to_regclass(format('public.%I', expected_table))
    ) THEN
      missing_rls := array_append(missing_rls, expected_table);
    END IF;
  END LOOP;

  IF cardinality(missing_tables) > 0 THEN
    RAISE EXCEPTION 'PLAN_B_MISSING_TABLES: %', array_to_string(missing_tables, ', ');
  END IF;
  IF cardinality(missing_rls) > 0 THEN
    RAISE EXCEPTION 'PLAN_B_MISSING_RLS: %', array_to_string(missing_rls, ', ');
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_proc procedure
    JOIN pg_namespace namespace ON namespace.oid = procedure.pronamespace
    WHERE namespace.nspname = 'public'
      AND procedure.prosecdef
      AND (
        has_function_privilege('anon', procedure.oid, 'EXECUTE')
        OR has_function_privilege('authenticated', procedure.oid, 'EXECUTE')
      )
  ) THEN
    RAISE EXCEPTION
      'PLAN_B_UNSAFE_PUBLIC_DEFINER_GRANT: anon/authenticated can execute a public SECURITY DEFINER function';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_proc procedure
    JOIN pg_namespace namespace ON namespace.oid = procedure.pronamespace
    WHERE namespace.nspname = 'private'
      AND (
        has_function_privilege('anon', procedure.oid, 'EXECUTE')
        OR (
          has_function_privilege('authenticated', procedure.oid, 'EXECUTE')
          AND procedure.proname NOT IN ('is_class_teacher', 'is_enrolled_in_class')
        )
      )
  ) THEN
    RAISE EXCEPTION
      'PLAN_B_UNSAFE_PRIVATE_FUNCTION_GRANT: only RLS helpers may be client-callable';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.course_lessons lesson
    WHERE lesson.status = 'approved'
      AND (
        lesson.metadata_review_status NOT IN ('approved', 'corrected')
        OR NOT EXISTS (
          SELECT 1
          FROM public.audio_clips clip
          WHERE clip.lesson_id = lesson.id
        )
        OR EXISTS (
          SELECT 1
          FROM public.audio_clips clip
          WHERE clip.lesson_id = lesson.id
            AND (
              clip.provider IS DISTINCT FROM 'google'
              OR clip.storage_path IS NULL
              OR clip.review_status NOT IN ('approved', 'corrected')
            )
        )
      )
  ) THEN
    RAISE EXCEPTION
      'PLAN_B_APPROVED_LESSON_HAS_INCOMPLETE_GOOGLE_AUDIO';
  END IF;

  FOREACH legacy_table IN ARRAY ARRAY[
    'lessons', 'lesson_assignments', 'lesson_progress',
    'badges', 'user_badges', 'leaderboards', 'leaderboard_entries',
    'uploaded_files', 'xp_logs'
  ]
  LOOP
    IF to_regclass(format('public.%I', legacy_table)) IS NOT NULL THEN
      RAISE EXCEPTION 'PLAN_B_LEGACY_TABLE_PRESENT: %', legacy_table;
    END IF;
  END LOOP;

  IF EXISTS (
    SELECT 1
    FROM pg_proc procedure
    JOIN pg_namespace namespace ON namespace.oid = procedure.pronamespace
    WHERE namespace.nspname = 'public'
      AND procedure.proname IN ('auto_confirm_new_user', 'rls_auto_enable')
  ) THEN
    RAISE EXCEPTION 'PLAN_B_FORBIDDEN_LEGACY_FUNCTION_PRESENT';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'course_lessons'
      AND policyname = 'Public reads approved lesson metadata'
      AND 'anon' = ANY(roles)
  ) THEN
    RAISE EXCEPTION 'PLAN_B_PUBLIC_APPROVED_LESSON_POLICY_MISSING';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM storage.buckets
    WHERE id = 'mandarin-audio'
      AND public = FALSE
  ) THEN
    RAISE EXCEPTION 'PLAN_B_PRIVATE_AUDIO_BUCKET_MISSING';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM unnest(ARRAY[
      'live_tests', 'live_test_participants', 'live_test_answers'
    ]) AS required_realtime(table_name)
    WHERE NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables published
      WHERE published.pubname = 'supabase_realtime'
        AND published.schemaname = 'public'
        AND published.tablename = required_realtime.table_name
    )
  ) THEN
    RAISE EXCEPTION 'PLAN_B_REALTIME_PUBLICATION_INCOMPLETE';
  END IF;
END;
$$;

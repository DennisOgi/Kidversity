BEGIN;
SELECT plan(12);

SELECT has_table('public', 'course_lessons', 'Foundation lessons exist');
SELECT has_table('public', 'review_events', 'Review audit exists');
SELECT has_table('public', 'lesson_results', 'Foundation results exist');
SELECT has_table('public', 'live_tests', 'Mandarin live quizzes exist');

SELECT ok(
  (SELECT relrowsecurity FROM pg_class
   WHERE oid = 'public.course_lessons'::regclass),
  'Foundation lessons enforce RLS'
);
SELECT ok(
  (SELECT relrowsecurity FROM pg_class
   WHERE oid = 'public.lesson_results'::regclass),
  'Foundation results enforce RLS'
);
SELECT ok(
  (SELECT relrowsecurity FROM pg_class
   WHERE oid = 'public.reviewer_accounts'::regclass),
  'Reviewer accounts enforce RLS'
);
SELECT ok(
  (SELECT NOT has_function_privilege(
    'authenticated',
    'private.complete_foundation_lesson(uuid,text,integer,jsonb,integer)',
    'EXECUTE'
  )),
  'Clients cannot execute Foundation completion directly'
);
SELECT ok(
  (SELECT NOT has_function_privilege(
    'authenticated',
    'private.review_foundation_item(uuid,text,text,text,text,jsonb)',
    'EXECUTE'
  )),
  'Clients cannot execute review decisions directly'
);
SELECT ok(
  (SELECT NOT has_function_privilege(
    'authenticated',
    'private.publish_foundation_lesson(uuid,text)',
    'EXECUTE'
  )),
  'Clients cannot publish lessons directly'
);
SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM information_schema.routine_privileges
    WHERE routine_schema = 'private'
      AND grantee IN ('anon', 'authenticated', 'PUBLIC')
      AND privilege_type = 'EXECUTE'
      AND routine_name NOT IN ('is_class_teacher', 'is_enrolled_in_class')
  ),
  'Private workflow functions grant no client execution'
);
SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM public.course_lessons lesson
    WHERE lesson.status = 'approved'
      AND EXISTS (
        SELECT 1 FROM public.audio_clips clip
        WHERE clip.lesson_id = lesson.id
          AND (
            clip.provider IS DISTINCT FROM 'google'
            OR clip.storage_path IS NULL
            OR clip.review_status NOT IN ('approved', 'corrected')
          )
      )
  ),
  'Published lessons have approved Google audio'
);

SELECT * FROM finish();
ROLLBACK;

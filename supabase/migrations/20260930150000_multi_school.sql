-- A person can belong to more than one school. Overview, classes, and
-- teacher invites follow the school the caller asked for. An existing
-- school admin can open another school and become its admin.

DROP FUNCTION IF EXISTS private.caller_school(UUID);

CREATE FUNCTION private.caller_school(
  p_user_id UUID,
  p_school_id UUID DEFAULT NULL
)
RETURNS TABLE(school_id UUID, school_name TEXT, member_role TEXT)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, private
AS $$
  SELECT s.id, s.name, m.role
  FROM public.school_members m
  JOIN public.schools s ON s.id = m.school_id
  WHERE m.user_id = p_user_id
    AND (p_school_id IS NULL OR s.id = p_school_id)
  ORDER BY CASE m.role
    WHEN 'admin' THEN 0
    WHEN 'teacher' THEN 1
    ELSE 2
  END, s.name
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION private.caller_school(UUID, UUID) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.caller_memberships(p_user_id UUID)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, private
AS $$
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object('id', s.id, 'name', s.name, 'role', m.role)
      ORDER BY s.name
    ),
    '[]'::jsonb
  )
  FROM public.school_members m
  JOIN public.schools s ON s.id = m.school_id
  WHERE m.user_id = p_user_id;
$$;

REVOKE ALL ON FUNCTION private.caller_memberships(UUID) FROM PUBLIC, anon, authenticated;

DROP FUNCTION IF EXISTS public.fetch_school_overview();

CREATE FUNCTION public.fetch_school_overview(p_school_id UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_school UUID;
  v_name TEXT;
  v_role TEXT;
  v_staff BOOLEAN := FALSE;
  v_students INTEGER := 0;
  v_classes JSONB := '[]'::jsonb;
  v_entries JSONB := '[]'::jsonb;
  v_memberships JSONB := '[]'::jsonb;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  v_memberships := private.caller_memberships(v_user);

  SELECT school_id, school_name, member_role
  INTO v_school, v_name, v_role
  FROM private.caller_school(v_user, p_school_id);

  IF v_school IS NULL THEN
    RETURN jsonb_build_object(
      'school_id', NULL,
      'school_name', NULL,
      'viewer_role', NULL,
      'student_count', 0,
      'classes', '[]'::jsonb,
      'entries', '[]'::jsonb,
      'memberships', v_memberships
    );
  END IF;

  v_staff := v_role IN ('admin', 'teacher');

  SELECT COUNT(*) INTO v_students
  FROM public.school_members
  WHERE school_id = v_school AND role = 'student';

  SELECT COALESCE(jsonb_agg(row_to_json(listed)::jsonb ORDER BY listed.name), '[]'::jsonb)
  INTO v_classes
  FROM (
    SELECT
      c.id,
      c.name,
      CASE WHEN v_role = 'student' THEN NULL ELSE c.join_code END AS join_code,
      c.teacher_id,
      COALESCE(NULLIF(trim(teacher.display_name), ''), 'Teacher') AS teacher_name,
      (SELECT COUNT(*) FROM public.class_members cm WHERE cm.class_id = c.id) AS member_count
    FROM public.classes c
    LEFT JOIN public.user_profiles teacher ON teacher.user_id = c.teacher_id
    WHERE c.school_id = v_school
      AND (
        v_role = 'admin'
        OR c.teacher_id = v_user
        OR EXISTS (
          SELECT 1 FROM public.class_members cm
          WHERE cm.class_id = c.id AND cm.user_id = v_user
        )
      )
    ORDER BY c.name
  ) listed;

  SELECT COALESCE(jsonb_agg(numbered.entry ORDER BY numbered.rank), '[]'::jsonb)
  INTO v_entries
  FROM (
    SELECT jsonb_build_object(
      'user_id', ranked.user_id,
      'display_name', ranked.display_name,
      'avatar', ranked.avatar,
      'weekly_xp', ranked.weekly_xp,
      'exam_correct', ranked.exam_correct,
      'maths_correct', ranked.maths_correct,
      'total_xp', ranked.total_xp,
      'opted_in', ranked.opted_in,
      'is_you', ranked.is_you,
      'rank', ranked.rank
    ) AS entry, ranked.rank
    FROM (
      SELECT
        profile.user_id,
        COALESCE(NULLIF(trim(profile.display_name), ''), 'Learner') AS display_name,
        COALESCE(NULLIF(trim(profile.avatar_emoji), ''), '🦊') AS avatar,
        COALESCE(weekly.weekly_xp, 0) AS weekly_xp,
        COALESCE(exams.exam_correct, 0) AS exam_correct,
        COALESCE(maths.maths_correct, 0) AS maths_correct,
        COALESCE(profile.xp, 0) AS total_xp,
        COALESCE((profile.preferences->>'class_leaderboard')::boolean, false) AS opted_in,
        (profile.user_id = v_user) AS is_you,
        ROW_NUMBER() OVER (
          ORDER BY
            COALESCE(weekly.weekly_xp, 0) DESC,
            COALESCE(exams.exam_correct, 0) DESC,
            COALESCE(maths.maths_correct, 0) DESC,
            COALESCE(profile.xp, 0) DESC,
            COALESCE(NULLIF(trim(profile.display_name), ''), 'Learner') ASC
        ) AS rank
      FROM public.school_members membership
      JOIN public.user_profiles profile ON profile.user_id = membership.user_id
      LEFT JOIN (
        SELECT result.user_id, COALESCE(SUM(lesson.xp_reward), 0)::int AS weekly_xp
        FROM public.lesson_results result
        JOIN public.course_lessons lesson ON lesson.id = result.lesson_id
        WHERE result.completed_at >= date_trunc('week', timezone('utc', now()))
        GROUP BY result.user_id
      ) weekly ON weekly.user_id = profile.user_id
      LEFT JOIN (
        SELECT attempt.user_id, COALESCE(SUM(attempt.correct), 0)::int AS exam_correct
        FROM public.exam_attempts attempt
        GROUP BY attempt.user_id
      ) exams ON exams.user_id = profile.user_id
      LEFT JOIN (
        SELECT result.user_id, COALESCE(SUM(result.correct), 0)::int AS maths_correct
        FROM public.maths_results result
        GROUP BY result.user_id
      ) maths ON maths.user_id = profile.user_id
      WHERE membership.school_id = v_school
        AND membership.role = 'student'
        AND (
          v_staff
          OR profile.user_id = v_user
          OR COALESCE((profile.preferences->>'class_leaderboard')::boolean, false)
        )
    ) ranked
  ) numbered;

  RETURN jsonb_build_object(
    'school_id', v_school,
    'school_name', v_name,
    'viewer_role', v_role,
    'student_count', v_students,
    'classes', COALESCE(v_classes, '[]'::jsonb),
    'entries', COALESCE(v_entries, '[]'::jsonb),
    'memberships', v_memberships
  );
END;
$$;

DROP FUNCTION IF EXISTS public.create_school_class(TEXT);

CREATE FUNCTION public.create_school_class(
  p_name TEXT,
  p_school_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_school UUID;
  v_role TEXT;
  v_name TEXT := trim(COALESCE(p_name, ''));
  v_row public.classes%ROWTYPE;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  SELECT school_id, member_role INTO v_school, v_role
  FROM private.caller_school(v_user, p_school_id);

  IF v_school IS NULL OR v_role NOT IN ('admin', 'teacher') THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  IF char_length(v_name) < 2 OR char_length(v_name) > 60 THEN
    RAISE EXCEPTION 'INVALID_NAME';
  END IF;

  INSERT INTO public.classes (name, teacher_id, school_id, description)
  VALUES (v_name, v_user, v_school, 'Class in the school')
  RETURNING * INTO v_row;

  RETURN jsonb_build_object(
    'id', v_row.id,
    'name', v_row.name,
    'join_code', v_row.join_code
  );
END;
$$;

DROP FUNCTION IF EXISTS public.add_school_teacher(TEXT);

CREATE FUNCTION public.add_school_teacher(
  p_email TEXT,
  p_school_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_school UUID;
  v_role TEXT;
  v_email TEXT := lower(trim(COALESCE(p_email, '')));
  v_teacher UUID;
  v_teacher_name TEXT;
  v_profile_role TEXT;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  SELECT school_id, member_role INTO v_school, v_role
  FROM private.caller_school(v_user, p_school_id);

  IF v_school IS NULL OR v_role <> 'admin' THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  SELECT id INTO v_teacher FROM auth.users WHERE lower(email) = v_email;
  IF v_teacher IS NULL THEN
    RAISE EXCEPTION 'NOT_FOUND';
  END IF;

  SELECT role INTO v_profile_role
  FROM public.user_profiles
  WHERE user_id = v_teacher;

  IF v_profile_role IS DISTINCT FROM 'teacher'
     AND v_profile_role IS DISTINCT FROM 'reviewer' THEN
    UPDATE public.user_profiles
    SET role = 'teacher', onboarding_complete = true, updated_at = now()
    WHERE user_id = v_teacher;
  END IF;

  INSERT INTO public.school_members (school_id, user_id, role)
  VALUES (v_school, v_teacher, 'teacher')
  ON CONFLICT (school_id, user_id) DO UPDATE
  SET role = CASE
    WHEN public.school_members.role = 'admin' THEN 'admin'
    ELSE 'teacher'
  END;

  UPDATE public.classes
  SET school_id = v_school, updated_at = now()
  WHERE teacher_id = v_teacher AND school_id IS NULL;

  SELECT COALESCE(NULLIF(trim(display_name), ''), v_email)
  INTO v_teacher_name
  FROM public.user_profiles
  WHERE user_id = v_teacher;

  RETURN jsonb_build_object(
    'user_id', v_teacher,
    'display_name', COALESCE(v_teacher_name, v_email)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.create_school(p_name TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_name TEXT := trim(COALESCE(p_name, ''));
  v_school UUID;
  v_profile_role TEXT;
  v_is_admin BOOLEAN := FALSE;
  v_has_membership BOOLEAN := FALSE;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  IF char_length(v_name) < 2 OR char_length(v_name) > 80 THEN
    RAISE EXCEPTION 'INVALID_NAME';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.school_members
    WHERE user_id = v_user AND role = 'admin'
  ) INTO v_is_admin;

  SELECT EXISTS (
    SELECT 1 FROM public.school_members WHERE user_id = v_user
  ) INTO v_has_membership;

  SELECT role INTO v_profile_role
  FROM public.user_profiles
  WHERE user_id = v_user;

  IF NOT v_is_admin
     AND NOT (v_profile_role = 'teacher' AND NOT v_has_membership) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  INSERT INTO public.schools (name) VALUES (v_name) RETURNING id INTO v_school;
  INSERT INTO public.school_members (school_id, user_id, role)
  VALUES (v_school, v_user, 'admin');

  RETURN jsonb_build_object('id', v_school, 'name', v_name);
END;
$$;

REVOKE ALL ON FUNCTION public.fetch_school_overview(UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.create_school_class(TEXT, UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.add_school_teacher(TEXT, UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.create_school(TEXT) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.fetch_school_overview(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_school_class(TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_school_teacher(TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_school(TEXT) TO authenticated;

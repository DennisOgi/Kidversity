-- A school sits above classes. Admins see every class and the school
-- ranking. Teachers manage only the classes they own. Students join a
-- class with its code and show on the school board when they opt in.

CREATE TABLE IF NOT EXISTS public.schools (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL CHECK (char_length(trim(name)) BETWEEN 2 AND 80),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.school_members (
  school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('admin', 'teacher', 'student')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (school_id, user_id)
);

CREATE INDEX IF NOT EXISTS school_members_user_idx
  ON public.school_members (user_id);

ALTER TABLE public.classes
  ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES public.schools(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS classes_school_idx
  ON public.classes (school_id);

ALTER TABLE public.schools ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_members ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.schools, public.school_members FROM anon;

DROP POLICY IF EXISTS "Members read their school" ON public.schools;
CREATE POLICY "Members read their school"
  ON public.schools FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.school_members membership
      WHERE membership.school_id = schools.id
        AND membership.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Staff read school members" ON public.school_members;
CREATE POLICY "Staff read school members"
  ON public.school_members FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.school_members mine
      WHERE mine.school_id = school_members.school_id
        AND mine.user_id = auth.uid()
        AND mine.role IN ('admin', 'teacher')
    )
  );

CREATE OR REPLACE FUNCTION private.caller_school(p_user_id UUID)
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
  ORDER BY CASE m.role
    WHEN 'admin' THEN 0
    WHEN 'teacher' THEN 1
    ELSE 2
  END, m.created_at DESC
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION private.caller_school(UUID) FROM PUBLIC, anon, authenticated;

-- Joining a class inside a school also enrols the learner in that school.
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
  v_school_id UUID;
BEGIN
  SELECT id, name, school_id
  INTO v_class_id, v_class_name, v_school_id
  FROM public.classes
  WHERE join_code = upper(trim(p_code));

  IF v_class_id IS NULL THEN
    RAISE EXCEPTION 'INVALID_CODE';
  END IF;

  INSERT INTO public.class_members(class_id, user_id)
  VALUES (v_class_id, p_user_id)
  ON CONFLICT (class_id, user_id) DO NOTHING;

  IF v_school_id IS NOT NULL THEN
    INSERT INTO public.school_members (school_id, user_id, role)
    VALUES (v_school_id, p_user_id, 'student')
    ON CONFLICT (school_id, user_id) DO NOTHING;
  END IF;

  RETURN QUERY SELECT v_class_id, v_class_name;
END;
$$;

-- School admins can refresh a code for any class in their school.
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
    SELECT 1
    FROM public.classes c
    WHERE c.id = p_class_id
      AND (
        c.teacher_id = p_user_id
        OR EXISTS (
          SELECT 1 FROM public.school_members m
          WHERE m.school_id = c.school_id
            AND m.user_id = p_user_id
            AND m.role = 'admin'
        )
      )
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

CREATE OR REPLACE FUNCTION public.fetch_school_overview()
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
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  SELECT school_id, school_name, member_role
  INTO v_school, v_name, v_role
  FROM private.caller_school(v_user);

  IF v_school IS NULL THEN
    RETURN jsonb_build_object(
      'school_id', NULL,
      'school_name', NULL,
      'viewer_role', NULL,
      'student_count', 0,
      'classes', '[]'::jsonb,
      'entries', '[]'::jsonb
    );
  END IF;

  v_staff := v_role IN ('admin', 'teacher');

  SELECT COUNT(*)
  INTO v_students
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
      (
        SELECT COUNT(*) FROM public.class_members cm WHERE cm.class_id = c.id
      ) AS member_count
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
    SELECT
      jsonb_build_object(
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
      ) AS entry,
      ranked.rank
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
        SELECT
          result.user_id,
          COALESCE(SUM(lesson.xp_reward), 0)::int AS weekly_xp
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
    'entries', COALESCE(v_entries, '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.create_school_class(p_name TEXT)
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
  FROM private.caller_school(v_user);

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

CREATE OR REPLACE FUNCTION public.add_school_teacher(p_email TEXT)
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
  FROM private.caller_school(v_user);

  IF v_school IS NULL OR v_role <> 'admin' THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  SELECT id INTO v_teacher
  FROM auth.users
  WHERE lower(email) = v_email;

  IF v_teacher IS NULL THEN
    RAISE EXCEPTION 'NOT_FOUND';
  END IF;

  SELECT role INTO v_profile_role
  FROM public.user_profiles
  WHERE user_id = v_teacher;

  IF v_profile_role IS DISTINCT FROM 'teacher' AND v_profile_role IS DISTINCT FROM 'reviewer' THEN
    UPDATE public.user_profiles
    SET role = 'teacher',
        onboarding_complete = true,
        updated_at = now()
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

REVOKE ALL ON FUNCTION public.fetch_school_overview() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.create_school_class(TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.add_school_teacher(TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fetch_school_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_school_class(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_school_teacher(TEXT) TO authenticated;

-- Class board can open a chosen class when the caller teaches it,
-- or when they are the school admin.
DROP FUNCTION IF EXISTS public.fetch_class_board();
DROP FUNCTION IF EXISTS private.fetch_class_board(UUID);

CREATE OR REPLACE FUNCTION private.fetch_class_board(
  p_user_id UUID,
  p_class_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_class_id UUID;
  v_class_name TEXT;
  v_is_teacher BOOLEAN := FALSE;
  v_week_start DATE;
  v_opted_in BOOLEAN := FALSE;
  v_member_count INTEGER := 0;
  v_hidden_count INTEGER := 0;
  v_entries JSONB := '[]'::jsonb;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  IF p_class_id IS NOT NULL AND EXISTS (
    SELECT 1
    FROM public.classes c
    WHERE c.id = p_class_id
      AND (
        c.teacher_id = p_user_id
        OR EXISTS (
          SELECT 1 FROM public.school_members m
          WHERE m.school_id = c.school_id
            AND m.user_id = p_user_id
            AND m.role = 'admin'
        )
      )
  ) THEN
    SELECT id, name INTO v_class_id, v_class_name
    FROM public.classes
    WHERE id = p_class_id;
    v_is_teacher := TRUE;
  ELSE
    SELECT id, name
    INTO v_class_id, v_class_name
    FROM public.classes
    WHERE teacher_id = p_user_id
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_class_id IS NOT NULL THEN
      v_is_teacher := TRUE;
    ELSE
      SELECT c.id, c.name
      INTO v_class_id, v_class_name
      FROM public.class_members membership
      JOIN public.classes c ON c.id = membership.class_id
      WHERE membership.user_id = p_user_id
      ORDER BY membership.joined_at DESC
      LIMIT 1;
    END IF;
  END IF;

  SELECT COALESCE((preferences->>'class_leaderboard')::boolean, false)
  INTO v_opted_in
  FROM public.user_profiles
  WHERE user_id = p_user_id;

  v_week_start := date_trunc('week', timezone('utc', now()))::date;

  IF v_class_id IS NULL THEN
    RETURN jsonb_build_object(
      'class_id', NULL,
      'class_name', NULL,
      'week_start', v_week_start,
      'viewer_opted_in', COALESCE(v_opted_in, false),
      'viewer_is_teacher', false,
      'member_count', 0,
      'hidden_count', 0,
      'entries', '[]'::jsonb
    );
  END IF;

  SELECT COUNT(*) INTO v_member_count
  FROM public.class_members WHERE class_id = v_class_id;

  SELECT COUNT(*) INTO v_hidden_count
  FROM public.class_members membership
  JOIN public.user_profiles profile ON profile.user_id = membership.user_id
  WHERE membership.class_id = v_class_id
    AND NOT COALESCE((profile.preferences->>'class_leaderboard')::boolean, false);

  SELECT COALESCE(
    (
      SELECT jsonb_agg(numbered.entry ORDER BY numbered.rank)
      FROM (
        SELECT
          jsonb_build_object(
            'user_id', ranked.user_id,
            'display_name', ranked.display_name,
            'avatar', ranked.avatar,
            'weekly_xp', ranked.weekly_xp,
            'weekly_lessons', ranked.weekly_lessons,
            'total_xp', ranked.total_xp,
            'total_lessons', ranked.total_lessons,
            'opted_in', ranked.opted_in,
            'is_you', ranked.is_you,
            'rank', ROW_NUMBER() OVER (
              ORDER BY ranked.weekly_xp DESC, ranked.weekly_lessons DESC,
                ranked.total_xp DESC, ranked.display_name ASC
            )
          ) AS entry,
          ROW_NUMBER() OVER (
            ORDER BY ranked.weekly_xp DESC, ranked.weekly_lessons DESC,
              ranked.total_xp DESC, ranked.display_name ASC
          ) AS rank
        FROM (
          SELECT
            profile.user_id,
            COALESCE(NULLIF(trim(profile.display_name), ''), 'Learner') AS display_name,
            COALESCE(NULLIF(trim(profile.avatar_emoji), ''), '🦊') AS avatar,
            COALESCE(weekly.weekly_xp, 0) AS weekly_xp,
            COALESCE(weekly.weekly_lessons, 0) AS weekly_lessons,
            COALESCE(profile.xp, 0) AS total_xp,
            COALESCE(totals.total_lessons, 0) AS total_lessons,
            COALESCE((profile.preferences->>'class_leaderboard')::boolean, false) AS opted_in,
            (profile.user_id = p_user_id) AS is_you
          FROM public.class_members membership
          JOIN public.user_profiles profile ON profile.user_id = membership.user_id
          LEFT JOIN (
            SELECT result.user_id,
              COUNT(*)::int AS weekly_lessons,
              COALESCE(SUM(lesson.xp_reward), 0)::int AS weekly_xp
            FROM public.lesson_results result
            JOIN public.course_lessons lesson ON lesson.id = result.lesson_id
            WHERE result.completed_at >= v_week_start
            GROUP BY result.user_id
          ) weekly ON weekly.user_id = profile.user_id
          LEFT JOIN (
            SELECT result.user_id, COUNT(*)::int AS total_lessons
            FROM public.lesson_results result
            GROUP BY result.user_id
          ) totals ON totals.user_id = profile.user_id
          WHERE membership.class_id = v_class_id
            AND (
              v_is_teacher
              OR COALESCE((profile.preferences->>'class_leaderboard')::boolean, false)
            )
        ) ranked
      ) numbered
    ),
    '[]'::jsonb
  ) INTO v_entries;

  RETURN jsonb_build_object(
    'class_id', v_class_id,
    'class_name', v_class_name,
    'week_start', v_week_start,
    'viewer_opted_in', COALESCE(v_opted_in, false),
    'viewer_is_teacher', v_is_teacher,
    'member_count', v_member_count,
    'hidden_count', v_hidden_count,
    'entries', COALESCE(v_entries, '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fetch_class_board(p_class_id UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
BEGIN
  RETURN private.fetch_class_board(auth.uid(), p_class_id);
END;
$$;

REVOKE ALL ON FUNCTION private.fetch_class_board(UUID, UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fetch_class_board(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fetch_class_board(UUID) TO authenticated;

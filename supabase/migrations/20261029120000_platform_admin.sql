-- Platform admin: cross-tenant ops role (not school_members.admin).

ALTER TABLE public.user_profiles DROP CONSTRAINT IF EXISTS user_profiles_role_check;
ALTER TABLE public.user_profiles ADD CONSTRAINT user_profiles_role_check
  CHECK (role IN ('student', 'teacher', 'reviewer', 'platform_admin'));

CREATE TABLE IF NOT EXISTS public.platform_admin_accounts (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  provisioned_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.platform_admin_accounts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Platform admins view own account" ON public.platform_admin_accounts;
CREATE POLICY "Platform admins view own account"
  ON public.platform_admin_accounts FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS TEXT
LANGUAGE sql
SECURITY INVOKER
SET search_path = public
STABLE
AS $$
  SELECT CASE
    WHEN profile.role = 'platform_admin' AND EXISTS (
      SELECT 1 FROM public.platform_admin_accounts admin
      WHERE admin.user_id = auth.uid() AND admin.active
    ) THEN 'platform_admin'
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

DROP POLICY IF EXISTS "Users insert own profile" ON public.user_profiles;
CREATE POLICY "Users insert own profile"
  ON public.user_profiles FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND role IS DISTINCT FROM 'reviewer'
    AND role IS DISTINCT FROM 'platform_admin'
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
    AND (
      role IS DISTINCT FROM 'platform_admin'
      OR EXISTS (
        SELECT 1 FROM public.platform_admin_accounts
        WHERE user_id = auth.uid() AND active
      )
    )
  );

CREATE OR REPLACE FUNCTION private.provision_platform_admin(p_user_id UUID)
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
  SET
    role = 'platform_admin',
    onboarding_complete = TRUE,
    display_name = COALESCE(NULLIF(trim(display_name), ''), 'Platform Admin'),
    updated_at = NOW()
  WHERE user_id = p_user_id;

  IF NOT FOUND THEN
    INSERT INTO public.user_profiles (
      user_id, display_name, role, onboarding_complete
    ) VALUES (
      p_user_id, 'Platform Admin', 'platform_admin', TRUE
    );
  END IF;

  INSERT INTO public.platform_admin_accounts(user_id, active)
  VALUES (p_user_id, TRUE)
  ON CONFLICT (user_id) DO UPDATE
    SET active = TRUE, provisioned_at = NOW();
END;
$$;

CREATE OR REPLACE FUNCTION private.require_platform_admin()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_user UUID := auth.uid();
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;
  IF public.current_user_role() IS DISTINCT FROM 'platform_admin' THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;
  RETURN v_user;
END;
$$;

CREATE OR REPLACE FUNCTION private.account_is_active(p_prefs JSONB)
RETURNS BOOLEAN
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT COALESCE((p_prefs->>'account_active')::boolean, TRUE);
$$;

-- Overview KPIs
CREATE OR REPLACE FUNCTION public.admin_platform_overview()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_week_start TIMESTAMPTZ := date_trunc('week', NOW());
BEGIN
  PERFORM private.require_platform_admin();

  RETURN jsonb_build_object(
    'school_count', (SELECT count(*)::int FROM public.schools),
    'student_count', (
      SELECT count(*)::int FROM public.user_profiles
      WHERE role = 'student'
    ),
    'teacher_count', (
      SELECT count(*)::int FROM public.user_profiles
      WHERE role = 'teacher'
    ),
    'reviewer_count', (
      SELECT count(*)::int FROM public.user_profiles
      WHERE role = 'reviewer'
    ),
    'class_count', (SELECT count(*)::int FROM public.classes),
    'active_7d', (
      SELECT count(*)::int FROM public.user_profiles
      WHERE last_activity_date >= (CURRENT_DATE - 7)
        AND private.account_is_active(preferences)
    ),
    'lessons_this_week', (
      SELECT count(*)::int FROM public.lesson_results
      WHERE completed_at >= v_week_start
    ),
    'live_sessions_this_week', (
      SELECT count(*)::int FROM public.live_tests
      WHERE created_at >= v_week_start
    ),
    'exam_attempts_this_week', (
      SELECT count(*)::int FROM public.exam_attempts
      WHERE created_at >= v_week_start
    ),
    'maths_attempts_this_week', (
      SELECT count(*)::int FROM public.maths_results
      WHERE created_at >= v_week_start
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_list_schools()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_week_start TIMESTAMPTZ := date_trunc('week', NOW());
BEGIN
  PERFORM private.require_platform_admin();

  RETURN COALESCE((
    SELECT jsonb_agg(row_data ORDER BY row_data->>'name')
    FROM (
      SELECT jsonb_build_object(
        'id', s.id,
        'name', s.name,
        'created_at', s.created_at,
        'student_count', (
          SELECT count(*)::int FROM public.school_members m
          WHERE m.school_id = s.id AND m.role = 'student'
        ),
        'teacher_count', (
          SELECT count(*)::int FROM public.school_members m
          WHERE m.school_id = s.id AND m.role IN ('teacher', 'admin')
        ),
        'class_count', (
          SELECT count(*)::int FROM public.classes c WHERE c.school_id = s.id
        ),
        'weekly_xp', COALESCE((
          SELECT sum(cl.xp_reward)::int
          FROM public.school_members m
          JOIN public.lesson_results lr ON lr.user_id = m.user_id
          JOIN public.course_lessons cl ON cl.id = lr.lesson_id
          WHERE m.school_id = s.id
            AND m.role = 'student'
            AND lr.completed_at >= v_week_start
        ), 0),
        'last_activity', (
          SELECT max(p.last_activity_date)
          FROM public.school_members m
          JOIN public.user_profiles p ON p.user_id = m.user_id
          WHERE m.school_id = s.id
        )
      ) AS row_data
      FROM public.schools s
    ) rows
  ), '[]'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_school_detail(p_school_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_school public.schools%ROWTYPE;
  v_week_start TIMESTAMPTZ := date_trunc('week', NOW());
BEGIN
  PERFORM private.require_platform_admin();

  SELECT * INTO v_school FROM public.schools WHERE id = p_school_id;
  IF v_school.id IS NULL THEN
    RAISE EXCEPTION 'SCHOOL_NOT_FOUND';
  END IF;

  RETURN jsonb_build_object(
    'id', v_school.id,
    'name', v_school.name,
    'created_at', v_school.created_at,
    'classes', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', c.id,
        'name', c.name,
        'join_code', c.join_code,
        'teacher_id', c.teacher_id,
        'teacher_name', COALESCE(tp.display_name, 'Unassigned'),
        'member_count', (
          SELECT count(*)::int FROM public.class_members cm
          WHERE cm.class_id = c.id
        )
      ) ORDER BY c.name)
      FROM public.classes c
      LEFT JOIN public.user_profiles tp ON tp.user_id = c.teacher_id
      WHERE c.school_id = p_school_id
    ), '[]'::jsonb),
    'staff', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'user_id', m.user_id,
        'display_name', COALESCE(p.display_name, 'Member'),
        'email', u.email,
        'role', m.role,
        'avatar_emoji', COALESCE(p.avatar_emoji, '👤')
      ) ORDER BY
        CASE m.role WHEN 'admin' THEN 0 WHEN 'teacher' THEN 1 ELSE 2 END,
        p.display_name
      )
      FROM public.school_members m
      JOIN public.user_profiles p ON p.user_id = m.user_id
      LEFT JOIN auth.users u ON u.id = m.user_id
      WHERE m.school_id = p_school_id
        AND m.role IN ('admin', 'teacher')
    ), '[]'::jsonb),
    'top_learners', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'user_id', ranked.user_id,
        'display_name', ranked.display_name,
        'avatar_emoji', ranked.avatar_emoji,
        'weekly_xp', ranked.weekly_xp,
        'lessons_completed', ranked.lessons_completed
      ))
      FROM (
        SELECT
          m.user_id,
          COALESCE(p.display_name, 'Learner') AS display_name,
          COALESCE(p.avatar_emoji, '🙂') AS avatar_emoji,
          COALESCE((
            SELECT sum(cl.xp_reward)::int
            FROM public.lesson_results lr
            JOIN public.course_lessons cl ON cl.id = lr.lesson_id
            WHERE lr.user_id = m.user_id AND lr.completed_at >= v_week_start
          ), 0) AS weekly_xp,
          COALESCE(p.lessons_completed, 0) AS lessons_completed
        FROM public.school_members m
        JOIN public.user_profiles p ON p.user_id = m.user_id
        WHERE m.school_id = p_school_id AND m.role = 'student'
        ORDER BY 4 DESC, 5 DESC
        LIMIT 10
      ) ranked
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_list_users(
  p_role TEXT DEFAULT NULL,
  p_school_id UUID DEFAULT NULL,
  p_search TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 50,
  p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_limit INTEGER := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 200);
  v_offset INTEGER := GREATEST(COALESCE(p_offset, 0), 0);
  v_search TEXT := NULLIF(trim(COALESCE(p_search, '')), '');
BEGIN
  PERFORM private.require_platform_admin();

  RETURN jsonb_build_object(
    'total', (
      SELECT count(*)::int
      FROM public.user_profiles p
      LEFT JOIN auth.users u ON u.id = p.user_id
      WHERE (p_role IS NULL OR p.role = p_role)
        AND (
          p_school_id IS NULL
          OR EXISTS (
            SELECT 1 FROM public.school_members m
            WHERE m.user_id = p.user_id AND m.school_id = p_school_id
          )
        )
        AND (
          v_search IS NULL
          OR p.display_name ILIKE '%' || v_search || '%'
          OR u.email ILIKE '%' || v_search || '%'
        )
    ),
    'users', COALESCE((
      SELECT jsonb_agg(row_data)
      FROM (
        SELECT jsonb_build_object(
          'user_id', p.user_id,
          'display_name', COALESCE(p.display_name, 'User'),
          'email', u.email,
          'role', p.role,
          'avatar_emoji', COALESCE(p.avatar_emoji, '🙂'),
          'xp', COALESCE(p.xp, 0),
          'lessons_completed', COALESCE(p.lessons_completed, 0),
          'streak_days', COALESCE(p.streak_days, 0),
          'last_activity', p.last_activity_date,
          'active', private.account_is_active(p.preferences),
          'schools', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
              'id', s.id,
              'name', s.name,
              'role', m.role
            ) ORDER BY s.name)
            FROM public.school_members m
            JOIN public.schools s ON s.id = m.school_id
            WHERE m.user_id = p.user_id
          ), '[]'::jsonb)
        ) AS row_data
        FROM public.user_profiles p
        LEFT JOIN auth.users u ON u.id = p.user_id
        WHERE (p_role IS NULL OR p.role = p_role)
          AND (
            p_school_id IS NULL
            OR EXISTS (
              SELECT 1 FROM public.school_members m
              WHERE m.user_id = p.user_id AND m.school_id = p_school_id
            )
          )
          AND (
            v_search IS NULL
            OR p.display_name ILIKE '%' || v_search || '%'
            OR u.email ILIKE '%' || v_search || '%'
          )
        ORDER BY p.last_activity_date DESC NULLS LAST, p.display_name
        LIMIT v_limit OFFSET v_offset
      ) q
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_user_performance(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_profile public.user_profiles%ROWTYPE;
  v_email TEXT;
  v_week_start TIMESTAMPTZ := date_trunc('week', NOW());
BEGIN
  PERFORM private.require_platform_admin();

  SELECT * INTO v_profile FROM public.user_profiles WHERE user_id = p_user_id;
  IF v_profile.user_id IS NULL THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;

  SELECT email INTO v_email FROM auth.users WHERE id = p_user_id;

  RETURN jsonb_build_object(
    'user_id', v_profile.user_id,
    'display_name', COALESCE(v_profile.display_name, 'User'),
    'email', v_email,
    'role', v_profile.role,
    'avatar_emoji', COALESCE(v_profile.avatar_emoji, '🙂'),
    'xp', COALESCE(v_profile.xp, 0),
    'level', COALESCE(v_profile.level, 1),
    'streak_days', COALESCE(v_profile.streak_days, 0),
    'minutes_learned', COALESCE(v_profile.minutes_learned, 0),
    'lessons_completed', COALESCE(v_profile.lessons_completed, 0),
    'last_activity', v_profile.last_activity_date,
    'active', private.account_is_active(v_profile.preferences),
    'foundation_completed', (
      SELECT count(*)::int FROM public.lesson_results WHERE user_id = p_user_id
    ),
    'foundation_avg_score', COALESCE((
      SELECT round(avg(score)::numeric, 1)
      FROM public.lesson_results WHERE user_id = p_user_id
    ), 0),
    'lessons_this_week', (
      SELECT count(*)::int FROM public.lesson_results
      WHERE user_id = p_user_id AND completed_at >= v_week_start
    ),
    'completed_lesson_ids', COALESCE((
      SELECT jsonb_agg(lesson_id ORDER BY completed_at)
      FROM public.lesson_results WHERE user_id = p_user_id
    ), '[]'::jsonb),
    'exam_attempts', (
      SELECT count(*)::int FROM public.exam_attempts WHERE user_id = p_user_id
    ),
    'exam_avg_score', COALESCE((
      SELECT round(avg(
        CASE WHEN total > 0 THEN (correct::numeric / total) * 100 ELSE 0 END
      )::numeric, 1)
      FROM public.exam_attempts WHERE user_id = p_user_id
    ), 0),
    'maths_attempts', (
      SELECT count(*)::int FROM public.maths_results WHERE user_id = p_user_id
    ),
    'maths_avg_score', COALESCE((
      SELECT round(avg(
        CASE WHEN total > 0 THEN (correct::numeric / total) * 100 ELSE 0 END
      )::numeric, 1)
      FROM public.maths_results WHERE user_id = p_user_id
    ), 0),
    'weekly_activity', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('day', d.day, 'count', d.cnt) ORDER BY d.day)
      FROM (
        SELECT date_trunc('day', completed_at)::date AS day, count(*)::int AS cnt
        FROM public.lesson_results
        WHERE user_id = p_user_id
          AND completed_at >= (CURRENT_DATE - 13)
        GROUP BY 1
      ) d
    ), '[]'::jsonb),
    'schools', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', s.id,
        'name', s.name,
        'role', m.role
      ) ORDER BY s.name)
      FROM public.school_members m
      JOIN public.schools s ON s.id = m.school_id
      WHERE m.user_id = p_user_id
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_create_school(
  p_name TEXT,
  p_admin_email TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_name TEXT := trim(COALESCE(p_name, ''));
  v_email TEXT := lower(trim(COALESCE(p_admin_email, '')));
  v_school UUID;
  v_admin UUID;
BEGIN
  PERFORM private.require_platform_admin();

  IF char_length(v_name) < 2 OR char_length(v_name) > 80 THEN
    RAISE EXCEPTION 'INVALID_NAME';
  END IF;

  INSERT INTO public.schools (name) VALUES (v_name) RETURNING id INTO v_school;

  IF v_email <> '' THEN
    SELECT id INTO v_admin FROM auth.users WHERE lower(email) = v_email LIMIT 1;
    IF v_admin IS NULL THEN
      RAISE EXCEPTION 'ADMIN_USER_NOT_FOUND';
    END IF;

    UPDATE public.user_profiles
    SET
      role = CASE
        WHEN role IN ('student', 'teacher') OR role IS NULL THEN 'teacher'
        ELSE role
      END,
      onboarding_complete = TRUE,
      updated_at = NOW()
    WHERE user_id = v_admin;

    INSERT INTO public.school_members (school_id, user_id, role)
    VALUES (v_school, v_admin, 'admin')
    ON CONFLICT (school_id, user_id) DO UPDATE SET role = 'admin';
  END IF;

  RETURN jsonb_build_object(
    'id', v_school,
    'name', v_name,
    'admin_user_id', v_admin
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_assign_school_admin(
  p_school_id UUID,
  p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
BEGIN
  PERFORM private.require_platform_admin();

  IF NOT EXISTS (SELECT 1 FROM public.schools WHERE id = p_school_id) THEN
    RAISE EXCEPTION 'SCHOOL_NOT_FOUND';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_user_id) THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;

  UPDATE public.user_profiles
  SET
    role = CASE
      WHEN role IN ('student', 'teacher') OR role IS NULL THEN 'teacher'
      ELSE role
    END,
    onboarding_complete = TRUE,
    updated_at = NOW()
  WHERE user_id = p_user_id;

  INSERT INTO public.school_members (school_id, user_id, role)
  VALUES (p_school_id, p_user_id, 'admin')
  ON CONFLICT (school_id, user_id) DO UPDATE SET role = 'admin';

  RETURN jsonb_build_object(
    'school_id', p_school_id,
    'user_id', p_user_id,
    'role', 'admin'
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_user_active(
  p_user_id UUID,
  p_active BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_prefs JSONB;
BEGIN
  PERFORM private.require_platform_admin();

  IF p_user_id = auth.uid() THEN
    RAISE EXCEPTION 'CANNOT_DEACTIVATE_SELF';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.platform_admin_accounts
    WHERE user_id = p_user_id AND active
  ) THEN
    RAISE EXCEPTION 'CANNOT_DEACTIVATE_PLATFORM_ADMIN';
  END IF;

  SELECT preferences INTO v_prefs
  FROM public.user_profiles WHERE user_id = p_user_id;
  IF v_prefs IS NULL AND NOT FOUND THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;

  UPDATE public.user_profiles
  SET
    preferences = COALESCE(preferences, '{}'::jsonb)
      || jsonb_build_object('account_active', COALESCE(p_active, TRUE)),
    updated_at = NOW()
  WHERE user_id = p_user_id;

  RETURN jsonb_build_object(
    'user_id', p_user_id,
    'active', COALESCE(p_active, TRUE)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_platform_overview() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_list_schools() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_school_detail(UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_list_users(TEXT, UUID, TEXT, INTEGER, INTEGER) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_user_performance(UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_create_school(TEXT, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_assign_school_admin(UUID, UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_set_user_active(UUID, BOOLEAN) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.admin_platform_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_schools() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_school_detail(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_users(TEXT, UUID, TEXT, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_user_performance(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_create_school(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_assign_school_admin(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_user_active(UUID, BOOLEAN) TO authenticated;

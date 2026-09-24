-- Opt-in class board. No new tables — ranks Foundation XP / lessons
-- for the caller's class. Students only see classmates who opted in.
-- Teachers see everyone, with an opted_in flag.

CREATE OR REPLACE FUNCTION private.fetch_class_board(p_user_id UUID)
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

  SELECT COUNT(*)
  INTO v_member_count
  FROM public.class_members
  WHERE class_id = v_class_id;

  SELECT COUNT(*)
  INTO v_hidden_count
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
              ORDER BY
                ranked.weekly_xp DESC,
                ranked.weekly_lessons DESC,
                ranked.total_xp DESC,
                ranked.display_name ASC
            )
          ) AS entry,
          ROW_NUMBER() OVER (
            ORDER BY
              ranked.weekly_xp DESC,
              ranked.weekly_lessons DESC,
              ranked.total_xp DESC,
              ranked.display_name ASC
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
          JOIN public.user_profiles profile
            ON profile.user_id = membership.user_id
          LEFT JOIN (
            SELECT
              result.user_id,
              COUNT(*)::int AS weekly_lessons,
              COALESCE(SUM(lesson.xp_reward), 0)::int AS weekly_xp
            FROM public.lesson_results result
            JOIN public.course_lessons lesson ON lesson.id = result.lesson_id
            WHERE result.completed_at >= v_week_start
            GROUP BY result.user_id
          ) weekly ON weekly.user_id = profile.user_id
          LEFT JOIN (
            SELECT
              result.user_id,
              COUNT(*)::int AS total_lessons
            FROM public.lesson_results result
            GROUP BY result.user_id
          ) totals ON totals.user_id = profile.user_id
          WHERE membership.class_id = v_class_id
            AND (v_is_teacher OR COALESCE((profile.preferences->>'class_leaderboard')::boolean, false))
        ) ranked
      ) numbered
    ),
    '[]'::jsonb
  )
  INTO v_entries;

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

CREATE OR REPLACE FUNCTION public.fetch_class_board()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
BEGIN
  RETURN private.fetch_class_board(auth.uid());
END;
$$;

REVOKE ALL ON FUNCTION private.fetch_class_board(UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fetch_class_board() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fetch_class_board() TO authenticated;

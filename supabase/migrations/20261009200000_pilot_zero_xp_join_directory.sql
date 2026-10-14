-- Pearls Garden pilot: school learners start at zero XP, and joining a
-- teacher's class with a code is the way students land in that class.

UPDATE public.user_profiles p
SET
  xp = 0,
  level = 1,
  streak_days = 0,
  lessons_completed = 0,
  minutes_learned = 0,
  updated_at = now()
WHERE p.user_id IN (
  SELECT m.user_id FROM public.school_members m WHERE m.role = 'student'
);

DELETE FROM public.lesson_results
WHERE user_id IN (
  SELECT m.user_id FROM public.school_members m WHERE m.role = 'student'
);

DELETE FROM public.exam_attempts
WHERE user_id IN (
  SELECT m.user_id FROM public.school_members m WHERE m.role = 'student'
);

DELETE FROM public.maths_results
WHERE user_id IN (
  SELECT m.user_id FROM public.school_members m WHERE m.role = 'student'
);

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

  IF v_school_id IS NOT NULL THEN
    DELETE FROM public.class_members cm
    USING public.classes c
    WHERE cm.user_id = p_user_id
      AND cm.class_id = c.id
      AND c.school_id = v_school_id
      AND cm.class_id <> v_class_id;

    INSERT INTO public.school_members (school_id, user_id, role)
    VALUES (v_school_id, p_user_id, 'student')
    ON CONFLICT (school_id, user_id) DO NOTHING;
  END IF;

  INSERT INTO public.class_members(class_id, user_id)
  VALUES (v_class_id, p_user_id)
  ON CONFLICT (class_id, user_id) DO NOTHING;

  RETURN QUERY SELECT v_class_id, v_class_name;
END;
$$;

CREATE OR REPLACE FUNCTION public.fetch_school_directory(
  p_school_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_school UUID;
  v_role TEXT;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  SELECT school_id, member_role INTO v_school, v_role
  FROM private.caller_school(v_user, p_school_id);

  IF v_school IS NULL OR v_role <> 'admin' THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  RETURN jsonb_build_object(
    'teachers', COALESCE(
      (
        SELECT jsonb_agg(person ORDER BY person->>'display_name')
        FROM (
          SELECT jsonb_build_object(
            'user_id', m.user_id,
            'display_name', COALESCE(NULLIF(trim(p.display_name), ''), 'Teacher'),
            'email', u.email,
            'role', m.role,
            'class_ids', COALESCE((
              SELECT jsonb_agg(c.id)
              FROM public.classes c
              WHERE c.school_id = v_school AND c.teacher_id = m.user_id
            ), '[]'::jsonb)
          ) AS person
          FROM public.school_members m
          JOIN public.user_profiles p ON p.user_id = m.user_id
          JOIN auth.users u ON u.id = m.user_id
          WHERE m.school_id = v_school AND m.role = 'teacher'
        ) listed
      ),
      '[]'::jsonb
    ),
    'students', COALESCE(
      (
        SELECT jsonb_agg(person ORDER BY person->>'display_name')
        FROM (
          SELECT jsonb_build_object(
            'user_id', m.user_id,
            'display_name', COALESCE(NULLIF(trim(p.display_name), ''), 'Learner'),
            'email', u.email,
            'role', m.role,
            'class_ids', COALESCE((
              SELECT jsonb_agg(cm.class_id)
              FROM public.class_members cm
              JOIN public.classes c ON c.id = cm.class_id
              WHERE cm.user_id = m.user_id AND c.school_id = v_school
            ), '[]'::jsonb)
          ) AS person
          FROM public.school_members m
          JOIN public.user_profiles p ON p.user_id = m.user_id
          JOIN auth.users u ON u.id = m.user_id
          WHERE m.school_id = v_school AND m.role = 'student'
        ) listed
      ),
      '[]'::jsonb
    ),
    'people', COALESCE(
      (
        SELECT jsonb_agg(person ORDER BY person->>'role', person->>'display_name')
        FROM (
          SELECT jsonb_build_object(
            'user_id', m.user_id,
            'display_name', COALESCE(NULLIF(trim(p.display_name), ''), split_part(u.email, '@', 1)),
            'email', u.email,
            'role', m.role,
            'class_ids', COALESCE((
              SELECT jsonb_agg(cid)
              FROM (
                SELECT c.id AS cid
                FROM public.classes c
                WHERE c.school_id = v_school AND c.teacher_id = m.user_id
                UNION
                SELECT cm.class_id AS cid
                FROM public.class_members cm
                JOIN public.classes c ON c.id = cm.class_id
                WHERE cm.user_id = m.user_id AND c.school_id = v_school
              ) ids
            ), '[]'::jsonb)
          ) AS person
          FROM public.school_members m
          JOIN public.user_profiles p ON p.user_id = m.user_id
          JOIN auth.users u ON u.id = m.user_id
          WHERE m.school_id = v_school
        ) listed
      ),
      '[]'::jsonb
    )
  );
END;
$$;

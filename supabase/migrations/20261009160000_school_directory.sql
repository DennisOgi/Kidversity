-- School admin can pick teachers and students already in the school,
-- and remove a learner from a class.

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

  IF v_school IS NULL OR v_role NOT IN ('admin', 'teacher') THEN
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
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.remove_class_student(
  p_class_id UUID,
  p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_school UUID;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  SELECT school_id INTO v_school FROM public.classes WHERE id = p_class_id;
  IF v_school IS NULL THEN
    RAISE EXCEPTION 'NOT_FOUND';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.school_members m
    WHERE m.school_id = v_school AND m.user_id = v_user AND m.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  DELETE FROM public.class_members
  WHERE class_id = p_class_id AND user_id = p_user_id;

  RETURN jsonb_build_object('class_id', p_class_id, 'user_id', p_user_id);
END;
$$;

REVOKE ALL ON FUNCTION public.fetch_school_directory(UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.remove_class_student(UUID, UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fetch_school_directory(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_class_student(UUID, UUID) TO authenticated;

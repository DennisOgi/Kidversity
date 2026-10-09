-- School admins create classes and assign teachers and students.
-- Adding a teacher no longer creates a class. A class can be created
-- without a teacher, then a teacher is assigned later.

ALTER TABLE public.classes
  ALTER COLUMN teacher_id DROP NOT NULL;

CREATE OR REPLACE FUNCTION private.is_school_admin_of_class(p_class_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, private
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.classes c
    JOIN public.school_members m ON m.school_id = c.school_id
    WHERE c.id = p_class_id
      AND m.user_id = auth.uid()
      AND m.role = 'admin'
  );
$$;

REVOKE ALL ON FUNCTION private.is_school_admin_of_class(UUID)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.is_school_admin_of_class(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION private.is_class_teacher(p_class_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, private
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.classes
    WHERE id = p_class_id AND teacher_id = auth.uid()
  )
  OR private.is_school_admin_of_class(p_class_id);
$$;

DROP POLICY IF EXISTS "Teachers manage own classes" ON public.classes;
CREATE POLICY "Teachers manage own classes"
  ON public.classes FOR ALL TO authenticated
  USING (
    auth.uid() = teacher_id
    OR private.is_school_admin_of_class(id)
  )
  WITH CHECK (
    auth.uid() = teacher_id
    OR private.is_school_admin_of_class(id)
    OR EXISTS (
      SELECT 1 FROM public.school_members m
      WHERE m.school_id = classes.school_id
        AND m.user_id = auth.uid()
        AND m.role = 'admin'
    )
  );

-- Admin-owned classes: teacher_id is the assigned teacher, not the creator.
CREATE OR REPLACE FUNCTION public.create_school_class(
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

  IF v_school IS NULL OR v_role <> 'admin' THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  IF char_length(v_name) < 2 OR char_length(v_name) > 60 THEN
    RAISE EXCEPTION 'INVALID_NAME';
  END IF;

  INSERT INTO public.classes (name, teacher_id, school_id, description)
  VALUES (v_name, NULL, v_school, 'Class in the school')
  RETURNING * INTO v_row;

  RETURN jsonb_build_object(
    'id', v_row.id,
    'name', v_row.name,
    'join_code', v_row.join_code,
    'teacher_id', v_row.teacher_id
  );
END;
$$;

-- Teachers join the school only. No class is created for them.
CREATE OR REPLACE FUNCTION public.add_school_teacher(
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

CREATE OR REPLACE FUNCTION public.assign_class_teacher(
  p_class_id UUID,
  p_email TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_school UUID;
  v_email TEXT := lower(trim(COALESCE(p_email, '')));
  v_teacher UUID;
  v_teacher_name TEXT;
  v_class_name TEXT;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  SELECT c.school_id, c.name INTO v_school, v_class_name
  FROM public.classes c
  WHERE c.id = p_class_id;

  IF v_school IS NULL THEN
    RAISE EXCEPTION 'NOT_FOUND';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.school_members m
    WHERE m.school_id = v_school AND m.user_id = v_user AND m.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  SELECT id INTO v_teacher FROM auth.users WHERE lower(email) = v_email;
  IF v_teacher IS NULL THEN
    RAISE EXCEPTION 'NOT_FOUND';
  END IF;

  INSERT INTO public.school_members (school_id, user_id, role)
  VALUES (v_school, v_teacher, 'teacher')
  ON CONFLICT (school_id, user_id) DO UPDATE
  SET role = CASE
    WHEN public.school_members.role = 'admin' THEN 'admin'
    ELSE 'teacher'
  END;

  UPDATE public.user_profiles
  SET role = 'teacher',
      onboarding_complete = true,
      updated_at = now()
  WHERE user_id = v_teacher
    AND (role IS DISTINCT FROM 'teacher' AND role IS DISTINCT FROM 'reviewer');

  UPDATE public.classes
  SET teacher_id = v_teacher, updated_at = now()
  WHERE id = p_class_id;

  SELECT COALESCE(NULLIF(trim(display_name), ''), v_email)
  INTO v_teacher_name
  FROM public.user_profiles
  WHERE user_id = v_teacher;

  RETURN jsonb_build_object(
    'class_id', p_class_id,
    'class_name', v_class_name,
    'teacher_id', v_teacher,
    'display_name', COALESCE(v_teacher_name, v_email)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.assign_class_student(
  p_class_id UUID,
  p_email TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_school UUID;
  v_email TEXT := lower(trim(COALESCE(p_email, '')));
  v_student UUID;
  v_student_name TEXT;
  v_class_name TEXT;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  SELECT c.school_id, c.name INTO v_school, v_class_name
  FROM public.classes c
  WHERE c.id = p_class_id;

  IF v_school IS NULL THEN
    RAISE EXCEPTION 'NOT_FOUND';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.school_members m
    WHERE m.school_id = v_school AND m.user_id = v_user AND m.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  SELECT id INTO v_student FROM auth.users WHERE lower(email) = v_email;
  IF v_student IS NULL THEN
    RAISE EXCEPTION 'NOT_FOUND';
  END IF;

  INSERT INTO public.school_members (school_id, user_id, role)
  VALUES (v_school, v_student, 'student')
  ON CONFLICT (school_id, user_id) DO NOTHING;

  INSERT INTO public.class_members (class_id, user_id)
  VALUES (p_class_id, v_student)
  ON CONFLICT (class_id, user_id) DO NOTHING;

  SELECT COALESCE(NULLIF(trim(display_name), ''), v_email)
  INTO v_student_name
  FROM public.user_profiles
  WHERE user_id = v_student;

  RETURN jsonb_build_object(
    'class_id', p_class_id,
    'class_name', v_class_name,
    'user_id', v_student,
    'display_name', COALESCE(v_student_name, v_email)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.list_school_teachers(p_school_id UUID DEFAULT NULL)
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

  RETURN COALESCE(
    (
      SELECT jsonb_agg(
        jsonb_build_object(
          'user_id', m.user_id,
          'display_name', COALESCE(NULLIF(trim(p.display_name), ''), 'Teacher'),
          'email', u.email
        )
        ORDER BY COALESCE(NULLIF(trim(p.display_name), ''), 'Teacher')
      )
      FROM public.school_members m
      JOIN public.user_profiles p ON p.user_id = m.user_id
      JOIN auth.users u ON u.id = m.user_id
      WHERE m.school_id = v_school AND m.role = 'teacher'
    ),
    '[]'::jsonb
  );
END;
$$;

REVOKE ALL ON FUNCTION public.assign_class_teacher(UUID, TEXT)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assign_class_student(UUID, TEXT)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.list_school_teachers(UUID)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.assign_class_teacher(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.assign_class_student(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_school_teachers(UUID) TO authenticated;

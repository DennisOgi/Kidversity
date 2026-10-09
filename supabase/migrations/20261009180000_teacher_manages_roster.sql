-- Assigned class teachers can add and remove learners in their own class.
-- School admins keep the same rights for every class.

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
  v_teacher UUID;
  v_email TEXT := lower(trim(COALESCE(p_email, '')));
  v_student UUID;
  v_student_name TEXT;
  v_class_name TEXT;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  SELECT c.school_id, c.name, c.teacher_id
  INTO v_school, v_class_name, v_teacher
  FROM public.classes c
  WHERE c.id = p_class_id;

  IF v_school IS NULL THEN
    RAISE EXCEPTION 'NOT_FOUND';
  END IF;

  IF NOT (
    EXISTS (
      SELECT 1 FROM public.school_members m
      WHERE m.school_id = v_school AND m.user_id = v_user AND m.role = 'admin'
    )
    OR v_teacher = v_user
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
  v_teacher UUID;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  SELECT school_id, teacher_id INTO v_school, v_teacher
  FROM public.classes
  WHERE id = p_class_id;

  IF v_school IS NULL THEN
    RAISE EXCEPTION 'NOT_FOUND';
  END IF;

  IF NOT (
    EXISTS (
      SELECT 1 FROM public.school_members m
      WHERE m.school_id = v_school AND m.user_id = v_user AND m.role = 'admin'
    )
    OR v_teacher = v_user
  ) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  DELETE FROM public.class_members
  WHERE class_id = p_class_id AND user_id = p_user_id;

  RETURN jsonb_build_object('class_id', p_class_id, 'user_id', p_user_id);
END;
$$;

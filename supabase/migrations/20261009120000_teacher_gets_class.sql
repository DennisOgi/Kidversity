-- When a school admin assigns a teacher, that teacher gets a class
-- in the school so they land on Class with something to manage.

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
  v_class public.classes%ROWTYPE;
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

  SELECT * INTO v_class
  FROM public.classes
  WHERE teacher_id = v_teacher AND school_id = v_school
  ORDER BY created_at
  LIMIT 1;

  IF v_class.id IS NULL THEN
    INSERT INTO public.classes (name, teacher_id, school_id, description)
    VALUES (
      COALESCE(NULLIF(v_teacher_name, ''), 'Teacher') || '''s class',
      v_teacher,
      v_school,
      'Class in the school'
    )
    RETURNING * INTO v_class;
  END IF;

  UPDATE public.classes
  SET school_id = v_school, updated_at = now()
  WHERE teacher_id = v_teacher AND school_id IS NULL;

  RETURN jsonb_build_object(
    'user_id', v_teacher,
    'display_name', COALESCE(v_teacher_name, v_email),
    'class_id', v_class.id,
    'class_name', v_class.name
  );
END;
$$;

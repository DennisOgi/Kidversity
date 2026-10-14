-- School teachers can create their own class. They become the teacher and
-- share the join code with students. Admins can still create unassigned
-- classes and assign a teacher later.

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
  v_teacher UUID;
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

  -- Teachers own the class they create. Admin-created classes stay
  -- unassigned until a teacher is picked.
  IF v_role = 'teacher' THEN
    v_teacher := v_user;
  ELSE
    v_teacher := NULL;
  END IF;

  INSERT INTO public.classes (name, teacher_id, school_id, description)
  VALUES (v_name, v_teacher, v_school, 'Class in the school')
  RETURNING * INTO v_row;

  RETURN jsonb_build_object(
    'id', v_row.id,
    'name', v_row.name,
    'join_code', v_row.join_code,
    'teacher_id', v_row.teacher_id
  );
END;
$$;

-- RETURNS TABLE(class_id, ...) makes bare class_id ambiguous in INSERT
-- target lists, which broke student join-by-code.
CREATE OR REPLACE FUNCTION private.join_class_with_code(
  p_user_id UUID,
  p_code TEXT
)
RETURNS TABLE(class_id UUID, class_name TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
#variable_conflict use_column
DECLARE
  v_class_id UUID;
  v_class_name TEXT;
  v_school_id UUID;
BEGIN
  SELECT c.id, c.name, c.school_id
  INTO v_class_id, v_class_name, v_school_id
  FROM public.classes c
  WHERE c.join_code = upper(trim(p_code));

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

    INSERT INTO public.school_members AS sm (school_id, user_id, role)
    VALUES (v_school_id, p_user_id, 'student')
    ON CONFLICT (school_id, user_id) DO NOTHING;
  END IF;

  INSERT INTO public.class_members AS cm (class_id, user_id)
  VALUES (v_class_id, p_user_id)
  ON CONFLICT (class_id, user_id) DO NOTHING;

  RETURN QUERY SELECT v_class_id, v_class_name;
END;
$$;

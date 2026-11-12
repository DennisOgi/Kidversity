-- School onboarding: a staff code teachers use to join a school, email
-- invites for teachers who do not have an account yet, and the admin tools a
-- school needs to run itself (place students, manage staff, settings).

-- 1. Staff code ---------------------------------------------------------------

ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS staff_code TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS schools_staff_code_key
  ON public.schools (staff_code) WHERE staff_code IS NOT NULL;

-- Eight characters as XXXX-XXXX from an alphabet without 0/O/1/I/L.
CREATE OR REPLACE FUNCTION private.school_new_staff_code()
RETURNS TEXT
LANGUAGE plpgsql
VOLATILE
SET search_path = public, private
AS $$
DECLARE
  v_alphabet CONSTANT TEXT := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_code TEXT;
BEGIN
  LOOP
    v_code := '';
    FOR i IN 1..8 LOOP
      v_code := v_code || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
      IF i = 4 THEN v_code := v_code || '-'; END IF;
    END LOOP;
    EXIT WHEN NOT EXISTS (SELECT 1 FROM public.schools WHERE staff_code = v_code);
  END LOOP;
  RETURN v_code;
END;
$$;

UPDATE public.schools SET staff_code = private.school_new_staff_code()
WHERE staff_code IS NULL;

CREATE OR REPLACE FUNCTION private.schools_set_staff_code()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, private
AS $$
BEGIN
  IF NEW.staff_code IS NULL THEN
    NEW.staff_code := private.school_new_staff_code();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS schools_set_staff_code ON public.schools;
CREATE TRIGGER schools_set_staff_code
  BEFORE INSERT ON public.schools
  FOR EACH ROW EXECUTE FUNCTION private.schools_set_staff_code();

-- 2. Email invites -------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.school_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES public.schools (id) ON DELETE CASCADE,
  email TEXT NOT NULL CHECK (email = lower(trim(email)) AND position('@' IN email) > 1),
  role TEXT NOT NULL DEFAULT 'teacher' CHECK (role IN ('teacher', 'admin')),
  invited_by UUID REFERENCES auth.users (id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  accepted_at TIMESTAMPTZ,
  accepted_by UUID REFERENCES auth.users (id) ON DELETE SET NULL,
  UNIQUE (school_id, email)
);

CREATE INDEX IF NOT EXISTS school_invites_email_open_idx
  ON public.school_invites (email) WHERE accepted_at IS NULL;
CREATE INDEX IF NOT EXISTS school_invites_invited_by_idx
  ON public.school_invites (invited_by);
CREATE INDEX IF NOT EXISTS school_invites_accepted_by_idx
  ON public.school_invites (accepted_by);

-- Read and written only through the functions below.
ALTER TABLE public.school_invites ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.school_invites FROM anon, authenticated;

-- New accounts pick up any open invite for their email.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email TEXT := lower(trim(COALESCE(NEW.email, '')));
  v_invited BOOLEAN := FALSE;
BEGIN
  INSERT INTO public.user_profiles (user_id, display_name, avatar_emoji, onboarding_complete)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'avatar_emoji', '🦊'),
    false
  )
  ON CONFLICT (user_id) DO NOTHING;

  -- Never let invite bookkeeping block a sign-up.
  IF v_email <> '' THEN
    BEGIN
      INSERT INTO public.school_members (school_id, user_id, role)
      SELECT i.school_id, NEW.id, i.role
      FROM public.school_invites i
      WHERE i.email = v_email AND i.accepted_at IS NULL
      ON CONFLICT (school_id, user_id) DO NOTHING;

      UPDATE public.school_invites
      SET accepted_at = now(), accepted_by = NEW.id
      WHERE email = v_email AND accepted_at IS NULL;
      v_invited := FOUND;

      -- Invited staff start onboarding with Teacher already chosen.
      IF v_invited THEN
        UPDATE public.user_profiles SET role = 'teacher'
        WHERE user_id = NEW.id AND role IS NULL;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'school invite claim failed for %: %', NEW.id, SQLERRM;
    END;
  END IF;

  RETURN NEW;
END;
$$;

-- 3. Helpers ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION private.require_school_admin(p_school_id UUID)
RETURNS UUID
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
  IF v_user IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  SELECT school_id, member_role INTO v_school, v_role
  FROM private.caller_school(v_user, p_school_id);
  IF v_school IS NULL OR v_role <> 'admin' THEN RAISE EXCEPTION 'NOT_AUTHORIZED'; END IF;
  RETURN v_school;
END;
$$;

-- 4. Admin RPCs --------------------------------------------------------------------

-- Everything the school admin space needs beyond the overview: the staff code,
-- open invites, and staff with their classes.
CREATE OR REPLACE FUNCTION public.fetch_school_admin(p_school_id UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_school UUID := private.require_school_admin(p_school_id);
BEGIN
  RETURN (
    SELECT jsonb_build_object(
      'school_id', s.id,
      'school_name', s.name,
      'staff_code', s.staff_code,
      'created_at', s.created_at,
      'invites', COALESCE((
        SELECT jsonb_agg(jsonb_build_object(
          'id', i.id, 'email', i.email, 'role', i.role, 'created_at', i.created_at
        ) ORDER BY i.created_at DESC)
        FROM public.school_invites i
        WHERE i.school_id = s.id AND i.accepted_at IS NULL
      ), '[]'::jsonb),
      'staff', COALESCE((
        SELECT jsonb_agg(staff ORDER BY staff->>'role', staff->>'display_name')
        FROM (
          SELECT jsonb_build_object(
            'user_id', m.user_id,
            'display_name', COALESCE(NULLIF(trim(p.display_name), ''), split_part(u.email, '@', 1)),
            'email', u.email,
            'role', m.role,
            'joined_at', m.created_at,
            'last_active', p.last_activity_date,
            'classes', COALESCE((
              SELECT jsonb_agg(jsonb_build_object('id', c.id, 'name', c.name) ORDER BY c.name)
              FROM public.classes c
              WHERE c.school_id = s.id AND c.teacher_id = m.user_id
            ), '[]'::jsonb)
          ) AS staff
          FROM public.school_members m
          JOIN public.user_profiles p ON p.user_id = m.user_id
          JOIN auth.users u ON u.id = m.user_id
          WHERE m.school_id = s.id AND m.role IN ('admin', 'teacher')
        ) listed
      ), '[]'::jsonb)
    )
    FROM public.schools s
    WHERE s.id = v_school
  );
END;
$$;

-- Adds an existing account straight away, otherwise keeps an invite that is
-- applied when someone signs up with that email.
CREATE OR REPLACE FUNCTION public.invite_school_staff(
  p_email TEXT,
  p_role TEXT DEFAULT 'teacher',
  p_school_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_school UUID := private.require_school_admin(p_school_id);
  v_email TEXT := lower(trim(COALESCE(p_email, '')));
  v_role TEXT := CASE WHEN p_role = 'admin' THEN 'admin' ELSE 'teacher' END;
  v_target UUID;
  v_profile_role TEXT;
  v_name TEXT;
BEGIN
  IF v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' THEN RAISE EXCEPTION 'INVALID_EMAIL'; END IF;

  SELECT id INTO v_target FROM auth.users WHERE lower(email) = v_email;

  IF v_target IS NULL THEN
    INSERT INTO public.school_invites (school_id, email, role, invited_by)
    VALUES (v_school, v_email, v_role, auth.uid())
    ON CONFLICT (school_id, email) DO UPDATE
      SET role = EXCLUDED.role, invited_by = EXCLUDED.invited_by,
          created_at = now(), accepted_at = NULL, accepted_by = NULL;
    RETURN jsonb_build_object('status', 'invited', 'email', v_email);
  END IF;

  SELECT role, COALESCE(NULLIF(trim(display_name), ''), v_email)
  INTO v_profile_role, v_name
  FROM public.user_profiles WHERE user_id = v_target;

  IF v_profile_role IN ('student', 'parent') THEN RAISE EXCEPTION 'NOT_STAFF_ACCOUNT'; END IF;
  IF v_profile_role IS NULL THEN
    UPDATE public.user_profiles SET role = 'teacher', updated_at = now() WHERE user_id = v_target;
  END IF;

  INSERT INTO public.school_members (school_id, user_id, role)
  VALUES (v_school, v_target, v_role)
  ON CONFLICT (school_id, user_id) DO UPDATE
    SET role = CASE
      WHEN public.school_members.role = 'admin' OR EXCLUDED.role = 'admin' THEN 'admin'
      ELSE 'teacher'
    END;

  RETURN jsonb_build_object('status', 'added', 'email', v_email, 'display_name', v_name);
END;
$$;

CREATE OR REPLACE FUNCTION public.revoke_school_invite(p_invite_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_school UUID;
BEGIN
  SELECT school_id INTO v_school FROM public.school_invites WHERE id = p_invite_id;
  IF v_school IS NULL THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  PERFORM private.require_school_admin(v_school);
  DELETE FROM public.school_invites WHERE id = p_invite_id AND accepted_at IS NULL;
END;
$$;

-- A teacher joins the school with the code the admin shares.
CREATE OR REPLACE FUNCTION public.join_school_with_staff_code(p_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_code TEXT := upper(regexp_replace(COALESCE(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
  v_school UUID;
  v_name TEXT;
  v_profile_role TEXT;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  IF length(v_code) <> 8 THEN RAISE EXCEPTION 'INVALID_CODE'; END IF;

  SELECT id, name INTO v_school, v_name FROM public.schools
  WHERE replace(staff_code, '-', '') = v_code;
  IF v_school IS NULL THEN RAISE EXCEPTION 'INVALID_CODE'; END IF;

  SELECT role INTO v_profile_role FROM public.user_profiles WHERE user_id = v_user;
  IF v_profile_role IN ('student', 'parent') THEN RAISE EXCEPTION 'NOT_STAFF_ACCOUNT'; END IF;
  IF v_profile_role IS NULL THEN
    UPDATE public.user_profiles SET role = 'teacher', updated_at = now() WHERE user_id = v_user;
  END IF;

  INSERT INTO public.school_members (school_id, user_id, role)
  VALUES (v_school, v_user, 'teacher')
  ON CONFLICT (school_id, user_id) DO UPDATE
    SET role = CASE WHEN public.school_members.role = 'admin' THEN 'admin' ELSE 'teacher' END;

  -- A class the teacher made before joining moves into the school.
  UPDATE public.classes SET school_id = v_school, updated_at = now()
  WHERE teacher_id = v_user AND school_id IS NULL;

  RETURN jsonb_build_object('id', v_school, 'name', v_name);
END;
$$;

CREATE OR REPLACE FUNCTION public.regenerate_school_staff_code(p_school_id UUID DEFAULT NULL)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_school UUID := private.require_school_admin(p_school_id);
  v_code TEXT := private.school_new_staff_code();
BEGIN
  UPDATE public.schools SET staff_code = v_code WHERE id = v_school;
  RETURN v_code;
END;
$$;

CREATE OR REPLACE FUNCTION public.rename_school(p_name TEXT, p_school_id UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_school UUID := private.require_school_admin(p_school_id);
  v_name TEXT := trim(COALESCE(p_name, ''));
BEGIN
  IF char_length(v_name) < 2 OR char_length(v_name) > 80 THEN RAISE EXCEPTION 'INVALID_NAME'; END IF;
  UPDATE public.schools SET name = v_name WHERE id = v_school;
  RETURN jsonb_build_object('id', v_school, 'name', v_name);
END;
$$;

-- Moves a student who is already in the school into a class (one class per
-- school, the same rule as joining with a class code).
CREATE OR REPLACE FUNCTION public.place_school_student(p_class_id UUID, p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_school UUID;
  v_teacher UUID;
  v_class_name TEXT;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  SELECT school_id, teacher_id, name INTO v_school, v_teacher, v_class_name
  FROM public.classes WHERE id = p_class_id;
  IF v_school IS NULL THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;

  IF NOT (
    EXISTS (SELECT 1 FROM public.school_members
            WHERE school_id = v_school AND user_id = v_user AND role = 'admin')
    OR v_teacher = v_user
  ) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.school_members
                 WHERE school_id = v_school AND user_id = p_user_id AND role = 'student') THEN
    RAISE EXCEPTION 'NOT_FOUND';
  END IF;

  DELETE FROM public.class_members cm
  USING public.classes c
  WHERE cm.user_id = p_user_id AND cm.class_id = c.id
    AND c.school_id = v_school AND cm.class_id <> p_class_id;

  INSERT INTO public.class_members (class_id, user_id)
  VALUES (p_class_id, p_user_id)
  ON CONFLICT (class_id, user_id) DO NOTHING;

  RETURN jsonb_build_object('class_id', p_class_id, 'class_name', v_class_name);
END;
$$;

-- Removes someone from the school. Their classes lose them; their account stays.
CREATE OR REPLACE FUNCTION public.remove_school_member(p_user_id UUID, p_school_id UUID DEFAULT NULL)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_school UUID := private.require_school_admin(p_school_id);
  v_role TEXT;
BEGIN
  IF p_user_id = auth.uid() THEN RAISE EXCEPTION 'CANNOT_REMOVE_SELF'; END IF;
  SELECT role INTO v_role FROM public.school_members
  WHERE school_id = v_school AND user_id = p_user_id;
  IF v_role IS NULL THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;

  UPDATE public.classes SET teacher_id = NULL, updated_at = now()
  WHERE school_id = v_school AND teacher_id = p_user_id;

  DELETE FROM public.class_members cm
  USING public.classes c
  WHERE cm.user_id = p_user_id AND cm.class_id = c.id AND c.school_id = v_school;

  DELETE FROM public.school_members WHERE school_id = v_school AND user_id = p_user_id;
END;
$$;

-- Makes a teacher a co-admin, or an admin a teacher. A school keeps at least
-- one admin.
CREATE OR REPLACE FUNCTION public.set_school_staff_role(
  p_user_id UUID,
  p_role TEXT,
  p_school_id UUID DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_school UUID := private.require_school_admin(p_school_id);
  v_current TEXT;
BEGIN
  IF p_role NOT IN ('admin', 'teacher') THEN RAISE EXCEPTION 'INVALID_ROLE'; END IF;
  SELECT role INTO v_current FROM public.school_members
  WHERE school_id = v_school AND user_id = p_user_id;
  IF v_current IS NULL OR v_current = 'student' THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;

  IF v_current = 'admin' AND p_role = 'teacher' AND (
    SELECT count(*) FROM public.school_members WHERE school_id = v_school AND role = 'admin'
  ) <= 1 THEN
    RAISE EXCEPTION 'LAST_ADMIN';
  END IF;

  UPDATE public.school_members SET role = p_role
  WHERE school_id = v_school AND user_id = p_user_id;
END;
$$;

-- 5. Grants -------------------------------------------------------------------------

REVOKE ALL ON FUNCTION private.school_new_staff_code() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.schools_set_staff_code() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.require_school_admin(UUID) FROM PUBLIC, anon, authenticated;

DO $$
DECLARE
  v_fn TEXT;
BEGIN
  FOREACH v_fn IN ARRAY ARRAY[
    'public.fetch_school_admin(uuid)',
    'public.invite_school_staff(text, text, uuid)',
    'public.revoke_school_invite(uuid)',
    'public.join_school_with_staff_code(text)',
    'public.regenerate_school_staff_code(uuid)',
    'public.rename_school(text, uuid)',
    'public.place_school_student(uuid, uuid)',
    'public.remove_school_member(uuid, uuid)',
    'public.set_school_staff_role(uuid, text, uuid)'
  ] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon', v_fn);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', v_fn);
  END LOOP;
END;
$$;

-- 6. Staff safety ------------------------------------------------------------------
-- Assigning or adding a teacher used to turn any account into a teacher,
-- including a student's or a parent's. Only staff accounts (or accounts that
-- have not picked a role yet) can be made teachers now.

CREATE OR REPLACE FUNCTION public.add_school_teacher(p_email text, p_school_id uuid DEFAULT NULL::uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'private'
AS $function$
DECLARE v_user UUID := auth.uid(); v_school UUID; v_role TEXT; v_email TEXT := lower(trim(COALESCE(p_email, ''))); v_teacher UUID; v_teacher_name TEXT; v_profile_role TEXT;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  SELECT school_id, member_role INTO v_school, v_role FROM private.caller_school(v_user, p_school_id);
  IF v_school IS NULL OR v_role <> 'admin' THEN RAISE EXCEPTION 'NOT_AUTHORIZED'; END IF;
  SELECT id INTO v_teacher FROM auth.users WHERE lower(email) = v_email;
  IF v_teacher IS NULL THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  SELECT role INTO v_profile_role FROM public.user_profiles WHERE user_id = v_teacher;
  IF v_profile_role IN ('student', 'parent') THEN RAISE EXCEPTION 'NOT_STAFF_ACCOUNT'; END IF;
  IF v_profile_role IS NULL THEN
    UPDATE public.user_profiles SET role = 'teacher', updated_at = now() WHERE user_id = v_teacher;
  END IF;
  INSERT INTO public.school_members (school_id, user_id, role) VALUES (v_school, v_teacher, 'teacher')
  ON CONFLICT (school_id, user_id) DO UPDATE SET role = CASE WHEN public.school_members.role = 'admin' THEN 'admin' ELSE 'teacher' END;
  SELECT COALESCE(NULLIF(trim(display_name), ''), v_email) INTO v_teacher_name FROM public.user_profiles WHERE user_id = v_teacher;
  RETURN jsonb_build_object('user_id', v_teacher, 'display_name', COALESCE(v_teacher_name, v_email));
END;
$function$;

CREATE OR REPLACE FUNCTION public.assign_class_teacher(p_class_id uuid, p_email text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'private'
AS $function$
DECLARE v_user UUID := auth.uid(); v_school UUID; v_email TEXT := lower(trim(COALESCE(p_email, ''))); v_teacher UUID; v_teacher_name TEXT; v_class_name TEXT; v_profile_role TEXT;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  SELECT c.school_id, c.name INTO v_school, v_class_name FROM public.classes c WHERE c.id = p_class_id;
  IF v_school IS NULL THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.school_members m WHERE m.school_id = v_school AND m.user_id = v_user AND m.role = 'admin') THEN RAISE EXCEPTION 'NOT_AUTHORIZED'; END IF;
  SELECT id INTO v_teacher FROM auth.users WHERE lower(email) = v_email;
  IF v_teacher IS NULL THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  SELECT role INTO v_profile_role FROM public.user_profiles WHERE user_id = v_teacher;
  IF v_profile_role IN ('student', 'parent') THEN RAISE EXCEPTION 'NOT_STAFF_ACCOUNT'; END IF;
  IF v_profile_role IS NULL THEN
    UPDATE public.user_profiles SET role = 'teacher', updated_at = now() WHERE user_id = v_teacher;
  END IF;
  INSERT INTO public.school_members (school_id, user_id, role) VALUES (v_school, v_teacher, 'teacher')
  ON CONFLICT (school_id, user_id) DO UPDATE SET role = CASE WHEN public.school_members.role = 'admin' THEN 'admin' ELSE 'teacher' END;
  UPDATE public.classes SET teacher_id = v_teacher, updated_at = now() WHERE id = p_class_id;
  SELECT COALESCE(NULLIF(trim(display_name), ''), v_email) INTO v_teacher_name FROM public.user_profiles WHERE user_id = v_teacher;
  RETURN jsonb_build_object('class_id', p_class_id, 'class_name', v_class_name, 'teacher_id', v_teacher, 'display_name', COALESCE(v_teacher_name, v_email));
END;
$function$;

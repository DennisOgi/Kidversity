-- Class onboarding: shareable join codes + student self-enrollment + scoped assignments.
-- Lets a teacher share a code so students can join their class themselves, and
-- ensures teacher-created lessons are only visible to the students they're assigned to.

-- ----------------------------------------------------------------- Join codes
ALTER TABLE classes ADD COLUMN IF NOT EXISTS join_code TEXT UNIQUE;

-- Generates a random, unambiguous 6-character code (no 0/O/1/I to avoid confusion).
CREATE OR REPLACE FUNCTION public.generate_class_code()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  v_alphabet TEXT := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_code TEXT;
  v_exists BOOLEAN;
BEGIN
  LOOP
    v_code := '';
    FOR i IN 1..6 LOOP
      v_code := v_code || substr(v_alphabet, floor(random() * length(v_alphabet) + 1)::int, 1);
    END LOOP;
    SELECT EXISTS(SELECT 1 FROM classes WHERE join_code = v_code) INTO v_exists;
    EXIT WHEN NOT v_exists;
  END LOOP;
  RETURN v_code;
END;
$$;

-- Backfill any existing classes that predate join codes.
UPDATE classes SET join_code = public.generate_class_code() WHERE join_code IS NULL;

-- New classes get a code automatically.
CREATE OR REPLACE FUNCTION public.set_class_join_code()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.join_code IS NULL THEN
    NEW.join_code := public.generate_class_code();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_class_join_code ON classes;
CREATE TRIGGER trg_set_class_join_code
  BEFORE INSERT ON classes
  FOR EACH ROW EXECUTE FUNCTION public.set_class_join_code();

-- ------------------------------------------------------- Student self-enrollment
-- SECURITY DEFINER so a student can enroll themselves by code without a broad
-- INSERT policy on class_members. Only ever enrolls the calling user (auth.uid()).
CREATE OR REPLACE FUNCTION public.join_class_with_code(p_code TEXT)
RETURNS TABLE(class_id UUID, class_name TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_class_id UUID;
  v_class_name TEXT;
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  SELECT id, name INTO v_class_id, v_class_name
  FROM classes
  WHERE join_code = upper(trim(p_code));

  IF v_class_id IS NULL THEN
    RAISE EXCEPTION 'INVALID_CODE';
  END IF;

  INSERT INTO class_members (class_id, user_id)
  VALUES (v_class_id, v_uid)
  ON CONFLICT (class_id, user_id) DO NOTHING;

  RETURN QUERY SELECT v_class_id, v_class_name;
END;
$$;

GRANT EXECUTE ON FUNCTION public.join_class_with_code(TEXT) TO authenticated;

-- Teacher can rotate their class code (e.g. after a term).
CREATE OR REPLACE FUNCTION public.regenerate_class_code(p_class_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_code TEXT;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM classes WHERE id = p_class_id AND teacher_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  v_code := public.generate_class_code();
  UPDATE classes SET join_code = v_code, updated_at = NOW() WHERE id = p_class_id;
  RETURN v_code;
END;
$$;

GRANT EXECUTE ON FUNCTION public.regenerate_class_code(UUID) TO authenticated;

-- --------------------------------------------------------- Scoped lesson access
-- Assigned (non-public) lessons remain readable only by the students they were
-- assigned to. Combined with keeping teacher lessons at status 'assigned', this
-- keeps class content out of the global catalog while the seed catalog stays
-- browsable in Explore.
DROP POLICY IF EXISTS "Students can view assigned lessons" ON lessons;
CREATE POLICY "Students can view assigned lessons"
  ON lessons FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM lesson_assignments la
      WHERE la.lesson_id = lessons.id
        AND la.user_id = auth.uid()
    )
  );

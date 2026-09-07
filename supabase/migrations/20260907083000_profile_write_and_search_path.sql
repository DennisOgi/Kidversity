-- Keep the remote MCP cutover in the local chain:
-- profile write policies, live-test class scoping, and pinned search_path.

DROP POLICY IF EXISTS "Users insert own profile" ON public.user_profiles;
CREATE POLICY "Users insert own profile"
  ON public.user_profiles FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid() AND role IS DISTINCT FROM 'reviewer');

DROP POLICY IF EXISTS "Users can view own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Users view own profile" ON public.user_profiles;
CREATE POLICY "Users view own profile"
  ON public.user_profiles FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Teachers can view class learner profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Teachers view class learner profiles" ON public.user_profiles;
CREATE POLICY "Teachers view class learner profiles"
  ON public.user_profiles FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.class_members membership
      WHERE membership.user_id = user_profiles.user_id
        AND private.is_class_teacher(membership.class_id)
    )
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
  );

DROP POLICY IF EXISTS "Students read live tests for their class" ON public.live_tests;
DROP POLICY IF EXISTS "Teachers manage own live tests" ON public.live_tests;
CREATE POLICY "Teachers manage own live tests"
  ON public.live_tests FOR ALL TO authenticated
  USING (teacher_id = auth.uid())
  WITH CHECK (
    teacher_id = auth.uid()
    AND (class_id IS NULL OR private.is_class_teacher(class_id))
  );
CREATE POLICY "Students read class live tests"
  ON public.live_tests FOR SELECT TO authenticated
  USING (
    teacher_id = auth.uid()
    OR (
      status IN ('live', 'ended')
      AND class_id IS NOT NULL
      AND private.is_enrolled_in_class(class_id)
    )
  );

CREATE OR REPLACE FUNCTION public.generate_class_code()
RETURNS TEXT
LANGUAGE plpgsql
SET search_path = public
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

CREATE OR REPLACE FUNCTION public.set_class_join_code()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.join_code IS NULL THEN
    NEW.join_code := public.generate_class_code();
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.generate_class_code() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.set_class_join_code() FROM PUBLIC, anon, authenticated;

-- Fix infinite recursion between classes ↔ class_members RLS policies.
-- SECURITY DEFINER helpers bypass RLS when checking cross-table membership.

CREATE OR REPLACE FUNCTION public.is_class_teacher(p_class_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.classes
    WHERE id = p_class_id
      AND teacher_id = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION public.is_enrolled_in_class(p_class_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.class_members
    WHERE class_id = p_class_id
      AND user_id = auth.uid()
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_class_teacher(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_enrolled_in_class(UUID) TO authenticated;

-- classes
DROP POLICY IF EXISTS "Teachers manage own classes" ON classes;
DROP POLICY IF EXISTS "Students view enrolled classes" ON classes;

CREATE POLICY "Teachers manage own classes"
  ON classes FOR ALL
  USING (auth.uid() = teacher_id)
  WITH CHECK (auth.uid() = teacher_id);

CREATE POLICY "Students view enrolled classes"
  ON classes FOR SELECT
  USING (public.is_enrolled_in_class(id));

-- class_members
DROP POLICY IF EXISTS "Teachers manage class members" ON class_members;
DROP POLICY IF EXISTS "Members view own class membership" ON class_members;

CREATE POLICY "Teachers manage class members"
  ON class_members FOR ALL
  USING (public.is_class_teacher(class_id))
  WITH CHECK (public.is_class_teacher(class_id));

CREATE POLICY "Members view own class membership"
  ON class_members FOR SELECT
  USING (auth.uid() = user_id OR public.is_class_teacher(class_id));

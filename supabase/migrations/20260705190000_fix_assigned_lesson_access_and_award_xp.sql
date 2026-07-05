-- Students must read lesson rows they were assigned (status may be 'assigned', not only 'published').
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

-- award_xp was in schema.sql but never migrated; lesson completion depends on it.
CREATE OR REPLACE FUNCTION public.award_xp(
  p_user_id UUID,
  p_amount INTEGER,
  p_reason TEXT DEFAULT NULL,
  p_lesson_id UUID DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new_xp INTEGER;
  v_new_level INTEGER;
BEGIN
  UPDATE user_profiles
  SET xp = xp + p_amount
  WHERE user_id = p_user_id
  RETURNING xp INTO v_new_xp;

  INSERT INTO xp_logs (user_id, amount, reason, lesson_id)
  VALUES (p_user_id, p_amount, p_reason, p_lesson_id);

  v_new_level := FLOOR(v_new_xp / 500.0) + 1;

  UPDATE user_profiles
  SET level = v_new_level
  WHERE user_id = p_user_id AND level < v_new_level;
END;
$$;

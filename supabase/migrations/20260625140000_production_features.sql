-- Production features: RLS gaps, classes, assignments, streaks, badges, demo class

-- Badges readable by all authenticated users
DROP POLICY IF EXISTS "Badges are viewable by everyone" ON badges;
CREATE POLICY "Badges are viewable by everyone"
  ON badges FOR SELECT USING (true);

-- Teachers can manage their classes
DROP POLICY IF EXISTS "Teachers manage own classes" ON classes;
CREATE POLICY "Teachers manage own classes"
  ON classes FOR ALL
  USING (auth.uid() = teacher_id)
  WITH CHECK (auth.uid() = teacher_id);

DROP POLICY IF EXISTS "Students view enrolled classes" ON classes;
CREATE POLICY "Students view enrolled classes"
  ON classes FOR SELECT
  USING (
    auth.uid() = teacher_id OR EXISTS (
      SELECT 1 FROM class_members cm
      WHERE cm.class_id = classes.id AND cm.user_id = auth.uid()
    )
  );

-- Class membership
DROP POLICY IF EXISTS "Teachers manage class members" ON class_members;
CREATE POLICY "Teachers manage class members"
  ON class_members FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM classes c
      WHERE c.id = class_members.class_id AND c.teacher_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM classes c
      WHERE c.id = class_members.class_id AND c.teacher_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Members view own class membership" ON class_members;
CREATE POLICY "Members view own class membership"
  ON class_members FOR SELECT
  USING (auth.uid() = user_id);

-- Lesson assignments
DROP POLICY IF EXISTS "Teachers can create assignments" ON lesson_assignments;
CREATE POLICY "Teachers can create assignments"
  ON lesson_assignments FOR INSERT
  WITH CHECK (
    auth.uid() = assigned_by AND EXISTS (
      SELECT 1 FROM lessons l
      WHERE l.id = lesson_id AND l.author_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Teachers view assignments they created" ON lesson_assignments;
CREATE POLICY "Teachers view assignments they created"
  ON lesson_assignments FOR SELECT
  USING (auth.uid() = user_id OR auth.uid() = assigned_by);

-- Teachers can read progress for students in their classes
DROP POLICY IF EXISTS "Teachers view class student progress" ON lesson_progress;
CREATE POLICY "Teachers view class student progress"
  ON lesson_progress FOR SELECT
  USING (
    auth.uid() = user_id OR EXISTS (
      SELECT 1 FROM class_members cm
      JOIN classes c ON c.id = cm.class_id
      WHERE cm.user_id = lesson_progress.user_id
        AND c.teacher_id = auth.uid()
    )
  );

-- Badge unlock helper (security definer)
CREATE OR REPLACE FUNCTION public.unlock_user_badge(p_user_id UUID, p_badge_name TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_badge_id UUID;
BEGIN
  SELECT id INTO v_badge_id FROM badges WHERE name = p_badge_name;
  IF v_badge_id IS NULL THEN RETURN; END IF;

  INSERT INTO user_badges (user_id, badge_id, progress, unlocked_at)
  VALUES (p_user_id, v_badge_id, 1, NOW())
  ON CONFLICT (user_id, badge_id) DO UPDATE
  SET progress = 1,
      unlocked_at = COALESCE(user_badges.unlocked_at, EXCLUDED.unlocked_at);
END;
$$;

-- Update streak on activity (called from app after lesson activity)
CREATE OR REPLACE FUNCTION public.update_user_streak(p_user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_streak INTEGER;
  v_last DATE;
  v_today DATE := CURRENT_DATE;
BEGIN
  SELECT streak_days, last_activity_date::date
  INTO v_streak, v_last
  FROM user_profiles
  WHERE user_id = p_user_id;

  IF v_last IS NULL THEN
    v_streak := 1;
  ELSIF v_last = v_today THEN
    v_streak := COALESCE(v_streak, 0);
  ELSIF v_last = v_today - 1 THEN
    v_streak := COALESCE(v_streak, 0) + 1;
  ELSE
    v_streak := 1;
  END IF;

  UPDATE user_profiles
  SET streak_days = v_streak,
      last_activity_date = v_today,
      updated_at = NOW()
  WHERE user_id = p_user_id;

  IF v_streak >= 7 THEN
    PERFORM unlock_user_badge(p_user_id, '7-Day Streak');
  END IF;

  RETURN v_streak;
END;
$$;

-- Seed demo class linking teacher + student demo accounts
DO $$
DECLARE
  v_teacher_id UUID;
  v_student_id UUID;
  v_class_id UUID;
BEGIN
  SELECT id INTO v_teacher_id FROM auth.users WHERE email = 'teacher@kidversity.demo';
  SELECT id INTO v_student_id FROM auth.users WHERE email = 'student@kidversity.demo';

  IF v_teacher_id IS NULL THEN RETURN; END IF;

  SELECT id INTO v_class_id FROM classes WHERE teacher_id = v_teacher_id LIMIT 1;

  IF v_class_id IS NULL THEN
    INSERT INTO classes (name, teacher_id, description, grade_level)
    VALUES ('Grade 4 Mandarin', v_teacher_id, 'Demo class for Kidversity', 4)
    RETURNING id INTO v_class_id;
  END IF;

  IF v_student_id IS NOT NULL THEN
    INSERT INTO class_members (class_id, user_id)
    VALUES (v_class_id, v_student_id)
    ON CONFLICT (class_id, user_id) DO NOTHING;
  END IF;
END $$;

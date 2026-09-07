-- Keep learner data private and expose only RPCs intended for app clients.

DROP POLICY IF EXISTS "Public profiles are viewable by everyone"
  ON public.user_profiles;
DROP POLICY IF EXISTS "Users can view own profile"
  ON public.user_profiles;
DROP POLICY IF EXISTS "Teachers can view class learner profiles"
  ON public.user_profiles;

CREATE POLICY "Users can view own profile"
  ON public.user_profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Teachers can view class learner profiles"
  ON public.user_profiles
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.class_members AS membership
      JOIN public.classes AS class
        ON class.id = membership.class_id
      WHERE membership.user_id = user_profiles.user_id
        AND class.teacher_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users manage own Foundation results"
  ON public.lesson_results;
DROP POLICY IF EXISTS "Users view own Foundation results"
  ON public.lesson_results;

CREATE POLICY "Users view own Foundation results"
  ON public.lesson_results
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

REVOKE ALL ON FUNCTION public.award_xp(UUID, INTEGER, TEXT, UUID)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.unlock_user_badge(UUID, TEXT)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.update_user_streak(UUID)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.handle_new_user()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.auto_confirm_new_user()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.generate_class_code()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.set_class_join_code()
  FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.is_class_teacher(UUID)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_class_teacher(UUID) TO authenticated;

REVOKE ALL ON FUNCTION public.is_enrolled_in_class(UUID)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_enrolled_in_class(UUID) TO authenticated;

REVOKE ALL ON FUNCTION public.join_class_with_code(TEXT)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.join_class_with_code(TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.regenerate_class_code(UUID)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.regenerate_class_code(UUID) TO authenticated;

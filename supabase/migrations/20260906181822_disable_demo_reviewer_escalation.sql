-- Demo accounts may preview the reviewer UI but must never receive reviewer privileges.

DROP FUNCTION IF EXISTS public.activate_demo_reviewer();

UPDATE public.reviewer_accounts AS reviewer
SET active = FALSE
FROM auth.users AS app_user
WHERE reviewer.user_id = app_user.id
  AND app_user.email = 'reviewer@kidversity.demo';

UPDATE public.user_profiles AS profile
SET role = 'student',
    updated_at = NOW()
FROM auth.users AS app_user
WHERE profile.user_id = app_user.id
  AND app_user.email = 'reviewer@kidversity.demo'
  AND profile.role = 'reviewer';

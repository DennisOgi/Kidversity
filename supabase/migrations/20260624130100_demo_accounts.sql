-- Run AFTER creating auth users via sign-up (student@kidversity.demo / teacher@kidversity.demo)
-- Dashboard → Authentication → disable "Confirm email" for easier local dev, or run:

UPDATE auth.users
SET email_confirmed_at = COALESCE(email_confirmed_at, now()),
    updated_at = now()
WHERE email IN ('student@kidversity.demo', 'teacher@kidversity.demo');

UPDATE public.user_profiles up
SET
  display_name = 'Chioma',
  avatar_emoji = '🦊',
  role = 'student',
  onboarding_complete = true,
  level = 7,
  xp = 1840,
  streak_days = 12,
  lessons_completed = 23,
  minutes_learned = 540,
  updated_at = now()
FROM auth.users u
WHERE up.user_id = u.id AND u.email = 'student@kidversity.demo';

UPDATE public.user_profiles up
SET
  display_name = 'Ms. Adebayo',
  avatar_emoji = '👩‍🏫',
  role = 'teacher',
  onboarding_complete = true,
  updated_at = now()
FROM auth.users u
WHERE up.user_id = u.id AND u.email = 'teacher@kidversity.demo';

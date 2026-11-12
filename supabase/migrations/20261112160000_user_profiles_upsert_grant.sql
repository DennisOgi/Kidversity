-- Sign-up failed with "permission denied for table user_profiles".
-- The app saves profiles with a PostgREST upsert (on_conflict=user_id), which
-- runs INSERT ... ON CONFLICT (user_id) DO UPDATE SET user_id = EXCLUDED.user_id,
-- so it needs UPDATE on user_id. The "Users update own profile" policy still
-- pins user_id to auth.uid(), so no one can move a profile to another account.
GRANT UPDATE (user_id) ON public.user_profiles TO authenticated;

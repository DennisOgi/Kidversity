-- Parents are a first-class role for RLS helpers.
CREATE OR REPLACE FUNCTION public.current_user_role()
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  SELECT CASE
    WHEN profile.role = 'platform_admin' AND EXISTS (
      SELECT 1 FROM public.platform_admin_accounts admin
      WHERE admin.user_id = auth.uid() AND admin.active
    ) THEN 'platform_admin'
    WHEN profile.role = 'reviewer' AND EXISTS (
      SELECT 1 FROM public.reviewer_accounts reviewer
      WHERE reviewer.user_id = auth.uid() AND reviewer.active
    ) THEN 'reviewer'
    WHEN profile.role IN ('student', 'teacher', 'parent') THEN profile.role
    ELSE NULL
  END
  FROM public.user_profiles profile
  WHERE profile.user_id = (SELECT auth.uid());
$function$;

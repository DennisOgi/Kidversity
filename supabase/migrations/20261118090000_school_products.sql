-- Per-school products. Schools buy products one at a time (Mandarin, Mental
-- maths, Science labs) and their staff, students and parents only see what
-- the school has. Exam practice (WAEC, UTME, NECO) has moved to ACE, so it is
-- not a Kidversity product and Rope Pull no longer builds exam decks.
--
-- Learners with no school (independent sign-ups) get the products listed in
-- private.app_settings.independent_products.

CREATE TABLE IF NOT EXISTS public.school_products (
  school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  product TEXT NOT NULL CHECK (product IN ('mandarin', 'maths', 'labs')),
  granted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (school_id, product)
);

ALTER TABLE public.school_products ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.school_products FROM PUBLIC, anon, authenticated;
-- Read and written only through the functions below.

INSERT INTO private.app_settings (key, value)
VALUES ('independent_products', '["mandarin", "maths", "labs"]'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- Existing schools keep what they have today until an admin changes it.
INSERT INTO public.school_products (school_id, product)
SELECT s.id, p.product
FROM public.schools s
CROSS JOIN (VALUES ('mandarin'), ('maths'), ('labs')) AS p(product)
ON CONFLICT DO NOTHING;

-- What a user can see --------------------------------------------------------

CREATE OR REPLACE FUNCTION private.user_products(p_user UUID)
RETURNS TEXT[]
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_role TEXT;
  v_all CONSTANT TEXT[] := ARRAY['mandarin', 'maths', 'labs'];
  v_independent TEXT[];
  v_result TEXT[] := ARRAY[]::TEXT[];
  v_learners UUID[];
  v_learner UUID;
BEGIN
  IF p_user IS NULL THEN
    RETURN ARRAY[]::TEXT[];
  END IF;

  SELECT role INTO v_role FROM public.user_profiles WHERE user_id = p_user;
  IF v_role IN ('platform_admin', 'reviewer') THEN
    RETURN v_all;
  END IF;

  SELECT COALESCE(array_agg(x), ARRAY[]::TEXT[]) INTO v_independent
  FROM jsonb_array_elements_text(
    COALESCE(
      (SELECT value FROM private.app_settings WHERE key = 'independent_products'),
      '[]'::jsonb
    )
  ) AS x;

  -- Parents see what their children's schools have.
  IF v_role = 'parent' THEN
    SELECT COALESCE(array_agg(DISTINCT l.user_id), ARRAY[]::UUID[]) INTO v_learners
    FROM public.payment_family_members g
    JOIN public.payment_family_members l
      ON l.family_id = g.family_id AND l.member_role = 'learner'
    WHERE g.user_id = p_user AND g.member_role IN ('owner', 'guardian');
    -- No linked child yet: treat the parent like an independent learner.
    IF cardinality(v_learners) = 0 THEN
      v_learners := ARRAY[p_user];
    END IF;
  ELSE
    v_learners := ARRAY[p_user];
  END IF;

  FOREACH v_learner IN ARRAY v_learners LOOP
    IF EXISTS (SELECT 1 FROM public.school_members m WHERE m.user_id = v_learner) THEN
      v_result := v_result || ARRAY(
        SELECT sp.product
        FROM public.school_members m
        JOIN public.school_products sp ON sp.school_id = m.school_id
        WHERE m.user_id = v_learner
      );
    ELSE
      v_result := v_result || v_independent;
    END IF;
  END LOOP;

  RETURN ARRAY(
    SELECT DISTINCT p FROM unnest(v_result) AS p
    WHERE p = ANY (v_all)
    ORDER BY p
  );
END;
$$;
REVOKE ALL ON FUNCTION private.user_products(UUID) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.user_has_product(p_user UUID, p_product TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, private
AS $$
  SELECT p_product = ANY (private.user_products(p_user));
$$;
REVOKE ALL ON FUNCTION private.user_has_product(UUID, TEXT) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.my_products()
RETURNS TEXT[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, private
AS $$
  SELECT private.user_products(auth.uid());
$$;
REVOKE ALL ON FUNCTION public.my_products() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.my_products() TO authenticated;

-- Lessons: a product the learner's school does not have stays closed ---------

CREATE OR REPLACE FUNCTION private.user_has_lesson_access(p_user_id uuid, p_subject_id text, p_sequence integer)
RETURNS boolean
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'private'
AS $function$
BEGIN
  IF p_sequence IS NULL OR p_sequence < 1 THEN
    RETURN FALSE;
  END IF;
  IF NOT private.user_has_product(p_user_id, p_subject_id) THEN
    RETURN FALSE;
  END IF;
  IF NOT private.payments_enabled() THEN
    RETURN TRUE;
  END IF;
  IF p_sequence <= 2 THEN
    RETURN TRUE;
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.payment_entitlements e
    WHERE e.learner_user_id = p_user_id
      AND e.subject_id = p_subject_id
      AND p_sequence BETWEEN e.start_sequence AND e.end_sequence
  ) THEN
    RETURN TRUE;
  END IF;
  RETURN EXISTS (
    SELECT 1 FROM private.learner_completed_sequences(p_user_id, p_subject_id) s
    WHERE s.sequence = p_sequence
  );
END;
$function$;

-- Rope Pull: decks only from the host's products; no exam decks --------------

CREATE OR REPLACE FUNCTION private.rope_pull_build_deck(p_user UUID, p_bank TEXT, p_options JSONB)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_count INTEGER := LEAST(40, GREATEST(4, COALESCE((p_options->>'count')::int, 10)));
  v_deck JSONB;
BEGIN
  IF p_bank = 'maths' THEN
    IF NOT private.user_has_product(p_user, 'maths') THEN
      RAISE EXCEPTION 'PRODUCT_NOT_AVAILABLE';
    END IF;
    SELECT jsonb_agg(private.rope_pull_maths_question(i)) INTO v_deck
    FROM generate_series(0, v_count - 1) AS i;
    RETURN private.rope_pull_pack_split(v_deck, 'maths');
  ELSIF p_bank IN ('lessons_1_5', 'module_1', 'daily_review') THEN
    IF NOT private.user_has_product(p_user, 'mandarin') THEN
      RAISE EXCEPTION 'PRODUCT_NOT_AVAILABLE';
    END IF;
    RETURN private.rope_pull_word_deck(p_user, p_bank, LEAST(v_count, 10));
  ELSIF p_bank = 'past_questions' THEN
    -- Exam practice lives in ACE now.
    RAISE EXCEPTION 'PRODUCT_NOT_AVAILABLE';
  END IF;
  RAISE EXCEPTION 'INVALID_BANK';
END;
$$;
REVOKE ALL ON FUNCTION private.rope_pull_build_deck(UUID, TEXT, JSONB) FROM PUBLIC, anon, authenticated;

-- Platform admin: see and set a school's products ----------------------------

CREATE OR REPLACE FUNCTION public.admin_school_products()
RETURNS TABLE (school_id UUID, products TEXT[])
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, private
AS $$
BEGIN
  PERFORM private.require_platform_admin();
  RETURN QUERY
  SELECT s.id,
         COALESCE(array_agg(sp.product ORDER BY sp.product)
                  FILTER (WHERE sp.product IS NOT NULL), ARRAY[]::TEXT[])
  FROM public.schools s
  LEFT JOIN public.school_products sp ON sp.school_id = s.id
  GROUP BY s.id;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_school_products() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_school_products() TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_set_school_products(p_school_id UUID, p_products TEXT[])
RETURNS TEXT[]
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_admin UUID := private.require_platform_admin();
  v_clean TEXT[];
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.schools WHERE id = p_school_id) THEN
    RAISE EXCEPTION 'SCHOOL_NOT_FOUND';
  END IF;
  v_clean := ARRAY(
    SELECT DISTINCT p FROM unnest(COALESCE(p_products, ARRAY[]::TEXT[])) AS p
    WHERE p IN ('mandarin', 'maths', 'labs')
    ORDER BY p
  );
  DELETE FROM public.school_products
  WHERE school_id = p_school_id AND product <> ALL (v_clean);
  INSERT INTO public.school_products (school_id, product, granted_by)
  SELECT p_school_id, p, v_admin FROM unnest(v_clean) AS p
  ON CONFLICT DO NOTHING;
  RETURN v_clean;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_set_school_products(UUID, TEXT[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_school_products(UUID, TEXT[]) TO authenticated;

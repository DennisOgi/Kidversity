-- Parents, family linking, maths pack tracking, and family purchase analytics.
--
-- Pricing rules (unchanged, enforced here and in 20261030140000):
--   * Lessons 1–2 of every subject are free.
--   * ₦2,500 unlocks the next 10 lessons of one subject (a pack).
--   * ₦6,500 buys 3 pack credits, usable in any subject.
--   * No subscription. Purchases never expire.
--   * Lessons open one after another; each pack ends at a milestone.
--   * At lesson 8 of a paid pack the parent is prompted to buy the next pack
--     or use a credit.

------------------------------------------------------------------------------
-- 1. Parent role
------------------------------------------------------------------------------
ALTER TABLE public.user_profiles DROP CONSTRAINT IF EXISTS user_profiles_role_check;
ALTER TABLE public.user_profiles
  ADD CONSTRAINT user_profiles_role_check
  CHECK (role = ANY (ARRAY['student', 'teacher', 'parent', 'reviewer', 'platform_admin']));

-- Progress columns are server-owned (XP, streaks, counters). Clients may only
-- write identity and preference columns.
REVOKE INSERT, UPDATE ON public.user_profiles FROM authenticated;
GRANT INSERT (user_id, display_name, avatar_emoji, role, onboarding_complete,
              preferences, age, gender, guardian_email, parental_consent_at,
              terms_accepted_at, updated_at)
  ON public.user_profiles TO authenticated;
GRANT UPDATE (display_name, avatar_emoji, role, onboarding_complete,
              preferences, age, gender, guardian_email, parental_consent_at,
              terms_accepted_at, updated_at)
  ON public.user_profiles TO authenticated;

------------------------------------------------------------------------------
-- 2. Family link codes
------------------------------------------------------------------------------
ALTER TABLE public.payment_families
  ADD COLUMN IF NOT EXISTS link_code TEXT UNIQUE;

CREATE OR REPLACE FUNCTION private.family_new_code()
RETURNS TEXT
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  alphabet CONSTANT TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_code TEXT;
BEGIN
  LOOP
    v_code := 'FAM-';
    FOR i IN 1..5 LOOP
      v_code := v_code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    END LOOP;
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM public.payment_families WHERE link_code = v_code
    );
  END LOOP;
  RETURN v_code;
END;
$$;

-- Parent: get (or create) the family code a child types in.
CREATE OR REPLACE FUNCTION public.family_my_code()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_family UUID;
  v_code TEXT;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  IF public.current_user_role() IS DISTINCT FROM 'parent' THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  -- An account that was linked as a learner starts its own family as a parent.
  DELETE FROM public.payment_family_members
  WHERE user_id = v_user AND member_role = 'learner';

  v_family := private.ensure_payment_family(v_user);

  SELECT link_code INTO v_code FROM public.payment_families WHERE id = v_family;
  IF v_code IS NULL THEN
    v_code := private.family_new_code();
    UPDATE public.payment_families SET link_code = v_code WHERE id = v_family;
  END IF;

  RETURN jsonb_build_object('family_id', v_family, 'code', v_code);
END;
$$;

-- Child: join a parent's family with the code.
-- If the child already had a family of their own (they bought before a parent
-- linked), its purchases, credits and entitlements move with them.
CREATE OR REPLACE FUNCTION public.family_join(p_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_target UUID;
  v_target_label TEXT;
  v_old UUID;
  v_old_members INTEGER;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  IF public.current_user_role() IS DISTINCT FROM 'student' THEN
    RAISE EXCEPTION 'ONLY_LEARNERS_JOIN';
  END IF;

  SELECT id, label INTO v_target, v_target_label
  FROM public.payment_families
  WHERE link_code = upper(btrim(COALESCE(p_code, '')));
  IF v_target IS NULL THEN RAISE EXCEPTION 'FAMILY_NOT_FOUND'; END IF;

  SELECT family_id INTO v_old
  FROM public.payment_family_members WHERE user_id = v_user;

  IF v_old = v_target THEN
    RETURN jsonb_build_object('ok', TRUE, 'family_id', v_target, 'label', v_target_label);
  END IF;

  IF v_old IS NOT NULL THEN
    SELECT count(*) INTO v_old_members
    FROM public.payment_family_members WHERE family_id = v_old;

    DELETE FROM public.payment_family_members
    WHERE family_id = v_old AND user_id = v_user;

    UPDATE public.payment_entitlements SET family_id = v_target
    WHERE family_id = v_old AND learner_user_id = v_user;

    IF v_old_members <= 1 THEN
      -- The learner was alone: everything the old family owns comes along.
      UPDATE public.payment_purchases SET family_id = v_target WHERE family_id = v_old;
      UPDATE public.payment_pack_credits SET family_id = v_target WHERE family_id = v_old;
      UPDATE public.payment_entitlements SET family_id = v_target WHERE family_id = v_old;
      UPDATE public.payment_events SET family_id = v_target WHERE family_id = v_old;
      DELETE FROM public.payment_families WHERE id = v_old;
    END IF;
  END IF;

  INSERT INTO public.payment_family_members (family_id, user_id, member_role)
  VALUES (v_target, v_user, 'learner');

  PERFORM private.record_payment_event(
    v_target, v_user, 'learner_linked', NULL, NULL, NULL,
    jsonb_build_object('merged_from', v_old)
  );

  RETURN jsonb_build_object('ok', TRUE, 'family_id', v_target, 'label', v_target_label);
END;
$$;

-- Parent: remove a child from the family (entitlements stay with the child).
CREATE OR REPLACE FUNCTION public.family_remove_learner(p_learner_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_family UUID;
  v_new UUID;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  SELECT family_id INTO v_family FROM public.payment_family_members
  WHERE user_id = auth.uid() AND member_role IN ('owner', 'guardian');
  IF v_family IS NULL THEN RAISE EXCEPTION 'NOT_AUTHORIZED'; END IF;

  DELETE FROM public.payment_family_members
  WHERE family_id = v_family AND user_id = p_learner_user_id AND member_role = 'learner';
  IF NOT FOUND THEN RAISE EXCEPTION 'LEARNER_NOT_IN_FAMILY'; END IF;

  v_new := private.ensure_payment_family(p_learner_user_id);
  UPDATE public.payment_entitlements SET family_id = v_new
  WHERE learner_user_id = p_learner_user_id AND family_id = v_family;
END;
$$;

------------------------------------------------------------------------------
-- 3. Learner progress per subject
------------------------------------------------------------------------------
-- Completed sequences for a learner in a subject.
--   mandarin: lesson_results joined to course_lessons.sequence
--   maths:    maths_results rows that cleared the level (70% right)
CREATE OR REPLACE FUNCTION private.learner_completed_sequences(
  p_user_id UUID,
  p_subject_id TEXT
)
RETURNS TABLE (sequence INTEGER)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT DISTINCT cl.sequence
  FROM public.lesson_results lr
  JOIN public.course_lessons cl ON cl.id = lr.lesson_id
  WHERE p_subject_id = 'mandarin'
    AND lr.user_id = p_user_id
    AND cl.course_id = 'mandarin_foundation_v1'
  UNION
  SELECT DISTINCT mr.level
  FROM public.maths_results mr
  WHERE p_subject_id = 'maths'
    AND mr.user_id = p_user_id
    AND mr.total > 0
    AND mr.correct >= ceil(mr.total * 0.7);
$$;

CREATE OR REPLACE FUNCTION private.learner_subject_status(
  p_user_id UUID,
  p_subject_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_done INTEGER[];
  v_next INTEGER;
  v_current public.payment_packs%ROWTYPE;
  v_following public.payment_packs%ROWTYPE;
  v_done_in_current INTEGER := 0;
  v_owns_current BOOLEAN := FALSE;
  v_owns_following BOOLEAN := FALSE;
  v_total INTEGER;
BEGIN
  SELECT COALESCE(array_agg(s.sequence ORDER BY s.sequence), ARRAY[]::INTEGER[])
  INTO v_done
  FROM private.learner_completed_sequences(p_user_id, p_subject_id) s;

  SELECT lesson_count INTO v_total FROM public.payment_subjects WHERE id = p_subject_id;

  -- Next lesson to open = first gap in the sequence.
  v_next := 1;
  WHILE v_next = ANY (v_done) LOOP
    v_next := v_next + 1;
  END LOOP;

  -- The pack the learner is working in (or about to enter).
  SELECT * INTO v_current FROM public.payment_packs
  WHERE subject_id = p_subject_id
    AND LEAST(v_next, COALESCE(v_total, v_next)) BETWEEN start_sequence AND end_sequence;

  IF v_current.id IS NOT NULL THEN
    SELECT count(*) INTO v_done_in_current
    FROM unnest(v_done) d WHERE d BETWEEN v_current.start_sequence AND v_current.end_sequence;
    v_owns_current := EXISTS (
      SELECT 1 FROM public.payment_entitlements
      WHERE learner_user_id = p_user_id AND pack_id = v_current.id
    );
    SELECT * INTO v_following FROM public.payment_packs
    WHERE subject_id = p_subject_id AND pack_index = v_current.pack_index + 1;
    IF v_following.id IS NOT NULL THEN
      v_owns_following := EXISTS (
        SELECT 1 FROM public.payment_entitlements
        WHERE learner_user_id = p_user_id AND pack_id = v_following.id
      );
    END IF;
  ELSE
    -- Still in the free lessons: the first pack is what comes next.
    SELECT * INTO v_following FROM public.payment_packs
    WHERE subject_id = p_subject_id AND pack_index = 1;
    IF v_following.id IS NOT NULL THEN
      v_owns_following := EXISTS (
        SELECT 1 FROM public.payment_entitlements
        WHERE learner_user_id = p_user_id AND pack_id = v_following.id
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'subject_id', p_subject_id,
    'lessons_total', v_total,
    'lessons_completed', COALESCE(array_length(v_done, 1), 0),
    'next_sequence', CASE WHEN v_total IS NOT NULL AND v_next > v_total THEN NULL ELSE v_next END,
    'finished', v_total IS NOT NULL AND v_next > v_total,
    'needs_pack', v_next > 2
      AND (v_total IS NULL OR v_next <= v_total)
      AND v_current.id IS NOT NULL
      AND NOT v_owns_current
      AND NOT private.user_has_lesson_access(p_user_id, p_subject_id, v_next),
    'current_pack_id', v_current.id,
    'current_pack_title', v_current.title,
    'current_pack_owned', v_owns_current,
    'completed_in_current_pack', v_done_in_current,
    'current_pack_size', v_current.lesson_count,
    'next_pack_id', v_following.id,
    'next_pack_title', v_following.title,
    'next_pack_price_kobo', v_following.price_kobo,
    'next_pack_owned', v_owns_following,
    -- Lesson 8 of a paid pack reached and the next pack is still closed.
    'renew_prompt_due', v_owns_current
      AND v_done_in_current >= 8
      AND v_following.id IS NOT NULL
      AND NOT v_owns_following,
    'owned_pack_ids', COALESCE((
      SELECT jsonb_agg(pack_id ORDER BY start_sequence)
      FROM public.payment_entitlements
      WHERE learner_user_id = p_user_id AND subject_id = p_subject_id
    ), '[]'::jsonb)
  );
END;
$$;

------------------------------------------------------------------------------
-- 4. Lesson access: maths revision keeps levels already cleared
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.user_has_lesson_access(
  p_user_id UUID,
  p_subject_id TEXT,
  p_sequence INTEGER
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, private
AS $$
BEGIN
  IF p_sequence IS NULL OR p_sequence < 1 THEN
    RETURN FALSE;
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

  -- Revision: anything completed before packs shipped stays open.
  RETURN EXISTS (
    SELECT 1 FROM private.learner_completed_sequences(p_user_id, p_subject_id) s
    WHERE s.sequence = p_sequence
  );
END;
$$;

------------------------------------------------------------------------------
-- 5. Maths: enforce packs and record pack progress like Mandarin
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.maths_results_guard()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
BEGIN
  IF NEW.level IS NULL OR NEW.level < 1 OR NEW.level > 20 THEN
    RAISE EXCEPTION 'INVALID_LEVEL';
  END IF;
  IF NEW.total IS NULL OR NEW.total < 1 OR NEW.correct < 0 OR NEW.correct > NEW.total THEN
    RAISE EXCEPTION 'INVALID_SCORE';
  END IF;
  IF NOT private.user_has_lesson_access(NEW.user_id, 'maths', NEW.level) THEN
    RAISE EXCEPTION 'PACK_PURCHASE_REQUIRED';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.maths_results_progress()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_pack public.payment_packs%ROWTYPE;
  v_family UUID;
  v_done INTEGER;
BEGIN
  -- Only the first time a level is cleared counts.
  IF NEW.correct < ceil(NEW.total * 0.7) THEN RETURN NEW; END IF;
  IF EXISTS (
    SELECT 1 FROM public.maths_results
    WHERE user_id = NEW.user_id AND level = NEW.level AND id <> NEW.id
      AND total > 0 AND correct >= ceil(total * 0.7)
  ) THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_pack FROM public.payment_packs
  WHERE subject_id = 'maths' AND NEW.level BETWEEN start_sequence AND end_sequence;
  IF v_pack.id IS NULL THEN RETURN NEW; END IF;

  v_family := private.ensure_payment_family(NEW.user_id);
  SELECT count(*) INTO v_done
  FROM private.learner_completed_sequences(NEW.user_id, 'maths') s
  WHERE s.sequence BETWEEN v_pack.start_sequence AND v_pack.end_sequence;

  IF v_done = 8 THEN
    PERFORM private.record_payment_event(
      v_family, NEW.user_id, 'pack_renew_prompt', 'maths', v_pack.id, NULL,
      jsonb_build_object('completed_in_pack', v_done, 'sequence', NEW.level)
    );
  END IF;
  IF v_done = v_pack.lesson_count THEN
    PERFORM private.record_payment_event(
      v_family, NEW.user_id, 'pack_completed', 'maths', v_pack.id, NULL,
      jsonb_build_object('completed_in_pack', v_done)
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS maths_results_guard ON public.maths_results;
CREATE TRIGGER maths_results_guard
  BEFORE INSERT ON public.maths_results
  FOR EACH ROW EXECUTE FUNCTION private.maths_results_guard();

DROP TRIGGER IF EXISTS maths_results_progress ON public.maths_results;
CREATE TRIGGER maths_results_progress
  AFTER INSERT ON public.maths_results
  FOR EACH ROW EXECUTE FUNCTION private.maths_results_progress();

------------------------------------------------------------------------------
-- 6. Checkout: a parent can only buy for a child already in the family
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.payment_create_checkout(
  p_buyer_user_id UUID,
  p_product_type TEXT,
  p_pack_id TEXT DEFAULT NULL,
  p_learner_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_learner UUID;
  v_family UUID;
  v_pack public.payment_packs%ROWTYPE;
  v_amount INTEGER;
  v_reference TEXT;
  v_id UUID;
  v_prior_paid INTEGER;
BEGIN
  IF p_buyer_user_id IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  IF p_product_type NOT IN ('subject_pack', 'bundle_3') THEN
    RAISE EXCEPTION 'INVALID_PRODUCT';
  END IF;

  v_family := private.ensure_payment_family(p_buyer_user_id);
  v_learner := COALESCE(p_learner_user_id, p_buyer_user_id);

  IF v_learner <> p_buyer_user_id AND NOT EXISTS (
    SELECT 1 FROM public.payment_family_members
    WHERE family_id = v_family AND user_id = v_learner
  ) THEN
    RAISE EXCEPTION 'LEARNER_NOT_IN_FAMILY';
  END IF;

  IF p_product_type = 'subject_pack' THEN
    SELECT * INTO v_pack FROM public.payment_packs WHERE id = p_pack_id;
    IF v_pack.id IS NULL THEN RAISE EXCEPTION 'PACK_NOT_FOUND'; END IF;
    IF EXISTS (
      SELECT 1 FROM public.payment_entitlements
      WHERE learner_user_id = v_learner AND pack_id = v_pack.id
    ) THEN
      RAISE EXCEPTION 'PACK_ALREADY_OWNED';
    END IF;
    v_amount := v_pack.price_kobo;
  ELSE
    v_amount := 650000;
  END IF;

  SELECT count(*) INTO v_prior_paid FROM public.payment_purchases
  WHERE family_id = v_family AND status = 'paid';

  v_reference := 'kv_' || replace(gen_random_uuid()::text, '-', '');

  INSERT INTO public.payment_purchases (
    family_id, buyer_user_id, product_type, subject_id, pack_id,
    amount_kobo, paystack_reference, metadata
  ) VALUES (
    v_family, p_buyer_user_id, p_product_type, v_pack.subject_id, v_pack.id,
    v_amount, v_reference,
    jsonb_build_object('learner_user_id', v_learner, 'prior_paid_purchases', v_prior_paid)
  )
  RETURNING id INTO v_id;

  PERFORM private.record_payment_event(
    v_family, p_buyer_user_id, 'purchase_started',
    v_pack.subject_id, v_pack.id, v_id,
    jsonb_build_object('product_type', p_product_type, 'learner_user_id', v_learner)
  );

  RETURN jsonb_build_object(
    'purchase_id', v_id,
    'reference', v_reference,
    'amount_kobo', v_amount,
    'currency', 'NGN',
    'product_type', p_product_type,
    'pack_id', v_pack.id,
    'subject_id', v_pack.subject_id,
    'learner_user_id', v_learner,
    'family_id', v_family
  );
END;
$$;

-- Repeat purchases: any paid purchase after the family's first one.
CREATE OR REPLACE FUNCTION private.fulfill_paid_purchase(p_reference TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_purchase public.payment_purchases%ROWTYPE;
  v_credit_id UUID;
  v_learner UUID;
  v_prior INTEGER;
BEGIN
  SELECT * INTO v_purchase FROM public.payment_purchases
  WHERE paystack_reference = p_reference FOR UPDATE;

  IF v_purchase.id IS NULL THEN RAISE EXCEPTION 'PURCHASE_NOT_FOUND'; END IF;
  IF v_purchase.status = 'paid' THEN
    RETURN jsonb_build_object('ok', TRUE, 'already_paid', TRUE, 'id', v_purchase.id);
  END IF;

  SELECT count(*) INTO v_prior FROM public.payment_purchases
  WHERE family_id = v_purchase.family_id AND status = 'paid';

  UPDATE public.payment_purchases SET status = 'paid', paid_at = NOW()
  WHERE id = v_purchase.id;

  v_learner := COALESCE(
    NULLIF(v_purchase.metadata->>'learner_user_id', '')::uuid,
    v_purchase.buyer_user_id
  );

  IF v_purchase.product_type = 'subject_pack' THEN
    PERFORM private.grant_pack_entitlement(
      v_purchase.family_id, v_learner, v_purchase.pack_id, v_purchase.id, NULL
    );
  ELSE
    INSERT INTO public.payment_pack_credits (family_id, purchase_id, remaining)
    VALUES (v_purchase.family_id, v_purchase.id, 3)
    RETURNING id INTO v_credit_id;
    PERFORM private.record_payment_event(
      v_purchase.family_id, v_purchase.buyer_user_id, 'bundle_credits_granted',
      NULL, NULL, v_purchase.id,
      jsonb_build_object('credits', 3, 'credit_id', v_credit_id)
    );
  END IF;

  PERFORM private.record_payment_event(
    v_purchase.family_id, v_purchase.buyer_user_id, 'purchase_paid',
    v_purchase.subject_id, v_purchase.pack_id, v_purchase.id,
    jsonb_build_object(
      'product_type', v_purchase.product_type,
      'learner_user_id', v_learner,
      'amount_kobo', v_purchase.amount_kobo,
      'repeat', v_prior > 0
    )
  );

  IF v_prior > 0 THEN
    PERFORM private.record_payment_event(
      v_purchase.family_id, v_purchase.buyer_user_id, 'repeat_purchase',
      v_purchase.subject_id, v_purchase.pack_id, v_purchase.id,
      jsonb_build_object('purchase_number', v_prior + 1)
    );
  END IF;

  RETURN jsonb_build_object('ok', TRUE, 'id', v_purchase.id);
END;
$$;

------------------------------------------------------------------------------
-- 7. Credits can be used for any child in the family
------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.payment_redeem_credit(TEXT);

CREATE OR REPLACE FUNCTION public.payment_redeem_credit(
  p_pack_id TEXT,
  p_learner_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_learner UUID;
  v_family UUID;
  v_credit public.payment_pack_credits%ROWTYPE;
  v_pack public.payment_packs%ROWTYPE;
  v_entitlement UUID;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;

  SELECT * INTO v_pack FROM public.payment_packs WHERE id = p_pack_id;
  IF v_pack.id IS NULL THEN RAISE EXCEPTION 'PACK_NOT_FOUND'; END IF;

  v_family := private.ensure_payment_family(v_user);
  v_learner := COALESCE(p_learner_user_id, v_user);

  IF v_learner <> v_user AND NOT EXISTS (
    SELECT 1 FROM public.payment_family_members
    WHERE family_id = v_family AND user_id = v_learner
  ) THEN
    RAISE EXCEPTION 'LEARNER_NOT_IN_FAMILY';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.payment_entitlements
    WHERE learner_user_id = v_learner AND pack_id = p_pack_id
  ) THEN
    RAISE EXCEPTION 'PACK_ALREADY_OWNED';
  END IF;

  SELECT * INTO v_credit FROM public.payment_pack_credits
  WHERE family_id = v_family AND remaining > 0
  ORDER BY created_at LIMIT 1 FOR UPDATE;
  IF v_credit.id IS NULL THEN RAISE EXCEPTION 'NO_CREDITS'; END IF;

  UPDATE public.payment_pack_credits SET remaining = remaining - 1 WHERE id = v_credit.id;

  v_entitlement := private.grant_pack_entitlement(
    v_family, v_learner, p_pack_id, v_credit.purchase_id, v_credit.id
  );

  PERFORM private.record_payment_event(
    v_family, v_user, 'credit_redeemed', v_pack.subject_id, p_pack_id, v_credit.purchase_id,
    jsonb_build_object('credit_id', v_credit.id, 'entitlement_id', v_entitlement,
                       'learner_user_id', v_learner)
  );

  RETURN jsonb_build_object(
    'ok', TRUE,
    'entitlement_id', v_entitlement,
    'credits_remaining', (
      SELECT COALESCE(sum(remaining), 0)::int FROM public.payment_pack_credits
      WHERE family_id = v_family
    )
  );
END;
$$;

------------------------------------------------------------------------------
-- 8. What a learner and a parent see
------------------------------------------------------------------------------
-- Learner view now includes per-subject pathway status.
CREATE OR REPLACE FUNCTION public.payment_my_access()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_family UUID;
  v_role TEXT;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;

  v_family := private.ensure_payment_family(v_user);
  SELECT member_role INTO v_role FROM public.payment_family_members
  WHERE family_id = v_family AND user_id = v_user;

  RETURN jsonb_build_object(
    'family_id', v_family,
    'family_role', v_role,
    'has_guardian', EXISTS (
      SELECT 1 FROM public.payment_family_members
      WHERE family_id = v_family AND member_role IN ('owner', 'guardian') AND user_id <> v_user
    ),
    'credits_remaining', COALESCE((
      SELECT sum(remaining)::int FROM public.payment_pack_credits WHERE family_id = v_family
    ), 0),
    'entitlements', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', e.id, 'subject_id', e.subject_id, 'pack_id', e.pack_id,
        'start_sequence', e.start_sequence, 'end_sequence', e.end_sequence,
        'granted_at', e.granted_at
      ) ORDER BY e.granted_at)
      FROM public.payment_entitlements e WHERE e.learner_user_id = v_user
    ), '[]'::jsonb),
    'subjects', COALESCE((
      SELECT jsonb_agg(private.learner_subject_status(v_user, s.id) ORDER BY s.sort_order)
      FROM public.payment_subjects s WHERE s.active
    ), '[]'::jsonb),
    'purchases', COALESCE((
      SELECT jsonb_agg(row ORDER BY (row->>'created_at') DESC) FROM (
        SELECT jsonb_build_object(
          'id', p.id, 'product_type', p.product_type, 'subject_id', p.subject_id,
          'pack_id', p.pack_id, 'amount_kobo', p.amount_kobo, 'status', p.status,
          'created_at', p.created_at, 'paid_at', p.paid_at
        ) AS row
        FROM public.payment_purchases p
        WHERE p.family_id = v_family
        ORDER BY p.created_at DESC
        LIMIT 50
      ) recent
    ), '[]'::jsonb),
    'stats', private.family_stats(v_family)
  );
END;
$$;

CREATE OR REPLACE FUNCTION private.family_stats(p_family_id UUID)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT jsonb_build_object(
    'paid_purchases', (SELECT count(*)::int FROM public.payment_purchases
                       WHERE family_id = p_family_id AND status = 'paid'),
    'amount_paid_kobo', (SELECT COALESCE(sum(amount_kobo), 0)::bigint FROM public.payment_purchases
                         WHERE family_id = p_family_id AND status = 'paid'),
    'bundles_bought', (SELECT count(*)::int FROM public.payment_purchases
                       WHERE family_id = p_family_id AND status = 'paid' AND product_type = 'bundle_3'),
    'packs_owned', (SELECT count(*)::int FROM public.payment_entitlements WHERE family_id = p_family_id),
    'packs_completed', (SELECT count(DISTINCT (user_id, pack_id))::int FROM public.payment_events
                        WHERE family_id = p_family_id AND event_type = 'pack_completed'),
    'repeat_purchases', (SELECT GREATEST(count(*) - 1, 0)::int FROM public.payment_purchases
                         WHERE family_id = p_family_id AND status = 'paid'),
    'subjects_purchased', (SELECT count(DISTINCT subject_id)::int FROM public.payment_entitlements
                           WHERE family_id = p_family_id),
    'cross_subject', (SELECT count(DISTINCT subject_id) > 1 FROM public.payment_entitlements
                      WHERE family_id = p_family_id),
    'credits_remaining', (SELECT COALESCE(sum(remaining), 0)::int FROM public.payment_pack_credits
                          WHERE family_id = p_family_id),
    'learners', (SELECT count(*)::int FROM public.payment_family_members
                 WHERE family_id = p_family_id AND member_role = 'learner'),
    'first_paid_at', (SELECT min(paid_at) FROM public.payment_purchases
                      WHERE family_id = p_family_id AND status = 'paid'),
    'last_paid_at', (SELECT max(paid_at) FROM public.payment_purchases
                     WHERE family_id = p_family_id AND status = 'paid')
  );
$$;

-- Parent dashboard: every child, where they are, and what is due.
CREATE OR REPLACE FUNCTION public.family_overview()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_family UUID;
  v_role TEXT;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  v_family := private.ensure_payment_family(v_user);
  SELECT member_role INTO v_role FROM public.payment_family_members
  WHERE family_id = v_family AND user_id = v_user;
  IF v_role NOT IN ('owner', 'guardian') THEN RAISE EXCEPTION 'NOT_AUTHORIZED'; END IF;

  RETURN jsonb_build_object(
    'family_id', v_family,
    'label', (SELECT label FROM public.payment_families WHERE id = v_family),
    'link_code', (SELECT link_code FROM public.payment_families WHERE id = v_family),
    'stats', private.family_stats(v_family),
    'learners', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'user_id', m.user_id,
        'display_name', COALESCE(p.display_name, 'Learner'),
        'avatar_emoji', COALESCE(p.avatar_emoji, '🦊'),
        'xp', COALESCE(p.xp, 0),
        'streak_days', COALESCE(p.streak_days, 0),
        'last_activity_date', p.last_activity_date,
        'minutes_learned', COALESCE(p.minutes_learned, 0),
        'subjects', (
          SELECT jsonb_agg(private.learner_subject_status(m.user_id, s.id) ORDER BY s.sort_order)
          FROM public.payment_subjects s WHERE s.active
        )
      ) ORDER BY m.joined_at)
      FROM public.payment_family_members m
      LEFT JOIN public.user_profiles p ON p.user_id = m.user_id
      WHERE m.family_id = v_family AND m.member_role = 'learner'
    ), '[]'::jsonb),
    'purchases', COALESCE((
      SELECT jsonb_agg(row ORDER BY (row->>'created_at') DESC) FROM (
        SELECT jsonb_build_object(
          'id', pu.id, 'product_type', pu.product_type, 'subject_id', pu.subject_id,
          'pack_id', pu.pack_id, 'amount_kobo', pu.amount_kobo, 'status', pu.status,
          'learner_user_id', pu.metadata->>'learner_user_id',
          'created_at', pu.created_at, 'paid_at', pu.paid_at
        ) AS row
        FROM public.payment_purchases pu
        WHERE pu.family_id = v_family AND pu.status <> 'pending'
        ORDER BY pu.created_at DESC LIMIT 50
      ) recent
    ), '[]'::jsonb)
  );
END;
$$;

------------------------------------------------------------------------------
-- 9. Platform admin: purchases, completion, repeat and cross-subject per family
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_payment_analytics()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
BEGIN
  PERFORM private.require_platform_admin();

  RETURN jsonb_build_object(
    'totals', jsonb_build_object(
      'families_paying', (SELECT count(DISTINCT family_id)::int FROM public.payment_purchases WHERE status = 'paid'),
      'paid_purchases', (SELECT count(*)::int FROM public.payment_purchases WHERE status = 'paid'),
      'revenue_kobo', (SELECT COALESCE(sum(amount_kobo), 0)::bigint FROM public.payment_purchases WHERE status = 'paid'),
      'packs_sold', (SELECT count(*)::int FROM public.payment_purchases WHERE status = 'paid' AND product_type = 'subject_pack'),
      'bundles_sold', (SELECT count(*)::int FROM public.payment_purchases WHERE status = 'paid' AND product_type = 'bundle_3'),
      'credits_redeemed', (SELECT count(*)::int FROM public.payment_events WHERE event_type = 'credit_redeemed'),
      'packs_completed', (SELECT count(DISTINCT (user_id, pack_id))::int FROM public.payment_events WHERE event_type = 'pack_completed'),
      'renew_prompts', (SELECT count(*)::int FROM public.payment_events WHERE event_type = 'pack_renew_prompt'),
      'repeat_families', (
        SELECT count(*)::int FROM (
          SELECT family_id FROM public.payment_purchases WHERE status = 'paid'
          GROUP BY family_id HAVING count(*) > 1
        ) f
      ),
      'cross_subject_families', (
        SELECT count(*)::int FROM (
          SELECT family_id FROM public.payment_entitlements
          GROUP BY family_id HAVING count(DISTINCT subject_id) > 1
        ) f
      ),
      'checkouts_abandoned', (SELECT count(*)::int FROM public.payment_purchases
                              WHERE status = 'pending' AND created_at < now() - interval '1 day')
    ),
    'by_subject', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'subject_id', s.id,
        'title', s.title,
        'packs_owned', (SELECT count(*)::int FROM public.payment_entitlements e WHERE e.subject_id = s.id),
        'packs_completed', (SELECT count(DISTINCT (user_id, pack_id))::int FROM public.payment_events ev
                            WHERE ev.subject_id = s.id AND ev.event_type = 'pack_completed'),
        'revenue_kobo', (SELECT COALESCE(sum(amount_kobo), 0)::bigint FROM public.payment_purchases pu
                         WHERE pu.subject_id = s.id AND pu.status = 'paid')
      ) ORDER BY s.sort_order)
      FROM public.payment_subjects s
    ), '[]'::jsonb),
    'families', COALESCE((
      SELECT jsonb_agg(row ORDER BY (row->'stats'->>'last_paid_at') DESC NULLS LAST)
      FROM (
        SELECT jsonb_build_object(
          'family_id', f.id,
          'label', f.label,
          'stats', private.family_stats(f.id),
          'subjects', (
            SELECT COALESCE(jsonb_agg(DISTINCT e.subject_id), '[]'::jsonb)
            FROM public.payment_entitlements e WHERE e.family_id = f.id
          )
        ) AS row
        FROM public.payment_families f
        WHERE EXISTS (SELECT 1 FROM public.payment_purchases p WHERE p.family_id = f.id)
           OR EXISTS (SELECT 1 FROM public.payment_entitlements e WHERE e.family_id = f.id)
        LIMIT 500
      ) fam
    ), '[]'::jsonb)
  );
END;
$$;

------------------------------------------------------------------------------
-- 10. Grants
------------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.family_my_code() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.family_join(TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.family_remove_learner(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.family_overview() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.payment_redeem_credit(TEXT, UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.payment_my_access() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_payment_analytics() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.family_my_code() TO authenticated;
GRANT EXECUTE ON FUNCTION public.family_join(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.family_remove_learner(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.family_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION public.payment_redeem_credit(TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.payment_my_access() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_payment_analytics() TO authenticated;

REVOKE ALL ON FUNCTION private.family_new_code() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.learner_completed_sequences(UUID, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.learner_subject_status(UUID, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.family_stats(UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.maths_results_guard() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.maths_results_progress() FROM PUBLIC, anon, authenticated;

-- Indexes the advisor flagged on payment tables.
CREATE INDEX IF NOT EXISTS payment_entitlements_family_idx ON public.payment_entitlements (family_id);
CREATE INDEX IF NOT EXISTS payment_entitlements_pack_idx ON public.payment_entitlements (pack_id);
CREATE INDEX IF NOT EXISTS payment_entitlements_purchase_idx ON public.payment_entitlements (purchase_id);
CREATE INDEX IF NOT EXISTS payment_entitlements_credit_idx ON public.payment_entitlements (credit_id);
CREATE INDEX IF NOT EXISTS payment_entitlements_subject_idx ON public.payment_entitlements (subject_id);
CREATE INDEX IF NOT EXISTS payment_events_user_idx ON public.payment_events (user_id);
CREATE INDEX IF NOT EXISTS payment_events_type_idx ON public.payment_events (event_type, family_id);
CREATE INDEX IF NOT EXISTS payment_pack_credits_family_idx ON public.payment_pack_credits (family_id);
CREATE INDEX IF NOT EXISTS payment_pack_credits_purchase_idx ON public.payment_pack_credits (purchase_id);
CREATE INDEX IF NOT EXISTS payment_purchases_buyer_idx ON public.payment_purchases (buyer_user_id);
CREATE INDEX IF NOT EXISTS payment_purchases_pack_idx ON public.payment_purchases (pack_id);
CREATE INDEX IF NOT EXISTS payment_purchases_subject_idx ON public.payment_purchases (subject_id);
CREATE INDEX IF NOT EXISTS maths_results_user_level_idx ON public.maths_results (user_id, level);

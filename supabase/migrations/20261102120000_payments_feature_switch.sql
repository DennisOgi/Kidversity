-- Payments switch (pilot). With payments_enabled = false every lesson is open
-- (still one at a time) and checkout refuses. Turn on together with the app's
-- PAYMENTS_ENABLED build flag:
--   UPDATE private.app_settings SET value = 'true', updated_at = now()
--   WHERE key = 'payments_enabled';
CREATE TABLE IF NOT EXISTS private.app_settings (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
REVOKE ALL ON private.app_settings FROM PUBLIC, anon, authenticated;

INSERT INTO private.app_settings (key, value)
VALUES ('payments_enabled', 'false'::jsonb)
ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION private.payments_enabled()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT COALESCE(
    (SELECT (value)::text::boolean FROM private.app_settings WHERE key = 'payments_enabled'),
    FALSE
  );
$$;
REVOKE ALL ON FUNCTION private.payments_enabled() FROM PUBLIC, anon, authenticated;

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

  -- Revision: anything completed before packs shipped stays open.
  RETURN EXISTS (
    SELECT 1 FROM private.learner_completed_sequences(p_user_id, p_subject_id) s
    WHERE s.sequence = p_sequence
  );
END;
$$;

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
  IF NOT private.payments_enabled() THEN RAISE EXCEPTION 'PAYMENTS_DISABLED'; END IF;
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

CREATE OR REPLACE FUNCTION public.payment_create_checkout(
  p_product_type TEXT,
  p_pack_id TEXT DEFAULT NULL,
  p_learner_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  IF NOT private.payments_enabled() THEN RAISE EXCEPTION 'PAYMENTS_DISABLED'; END IF;
  RETURN private.payment_create_checkout(auth.uid(), p_product_type, p_pack_id, p_learner_user_id);
END;
$$;

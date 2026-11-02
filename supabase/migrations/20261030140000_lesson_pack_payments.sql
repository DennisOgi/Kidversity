-- Kidversity lesson-pack payments (Paystack, NGN).
-- Free: first 2 lessons per subject. Pack: next 10. Bundle: 3 pack credits.
-- No subscriptions. Purchases never expire.

CREATE TABLE IF NOT EXISTS public.payment_subjects (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  lesson_count INTEGER NOT NULL CHECK (lesson_count > 0),
  sort_order INTEGER NOT NULL DEFAULT 0,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.payment_packs (
  id TEXT PRIMARY KEY,
  subject_id TEXT NOT NULL REFERENCES public.payment_subjects(id) ON DELETE CASCADE,
  pack_index INTEGER NOT NULL CHECK (pack_index >= 1),
  title TEXT NOT NULL,
  milestone_label TEXT NOT NULL,
  start_sequence INTEGER NOT NULL CHECK (start_sequence >= 1),
  end_sequence INTEGER NOT NULL CHECK (end_sequence >= start_sequence),
  lesson_count INTEGER NOT NULL CHECK (lesson_count > 0),
  price_kobo INTEGER NOT NULL CHECK (price_kobo > 0),
  UNIQUE (subject_id, pack_index)
);

CREATE TABLE IF NOT EXISTS public.payment_families (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  label TEXT NOT NULL DEFAULT 'Family',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.payment_family_members (
  family_id UUID NOT NULL REFERENCES public.payment_families(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  member_role TEXT NOT NULL CHECK (member_role IN ('owner', 'learner', 'guardian')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (family_id, user_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS payment_family_members_user_uidx
  ON public.payment_family_members (user_id);

CREATE TABLE IF NOT EXISTS public.payment_purchases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID NOT NULL REFERENCES public.payment_families(id) ON DELETE CASCADE,
  buyer_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  product_type TEXT NOT NULL CHECK (product_type IN ('subject_pack', 'bundle_3')),
  subject_id TEXT REFERENCES public.payment_subjects(id),
  pack_id TEXT REFERENCES public.payment_packs(id),
  amount_kobo INTEGER NOT NULL CHECK (amount_kobo > 0),
  currency TEXT NOT NULL DEFAULT 'NGN',
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'paid', 'failed', 'refunded')),
  paystack_reference TEXT NOT NULL UNIQUE,
  paystack_access_code TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  paid_at TIMESTAMPTZ,
  CONSTRAINT payment_purchases_pack_shape CHECK (
    (product_type = 'bundle_3' AND pack_id IS NULL)
    OR (product_type = 'subject_pack' AND pack_id IS NOT NULL AND subject_id IS NOT NULL)
  )
);

CREATE TABLE IF NOT EXISTS public.payment_pack_credits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID NOT NULL REFERENCES public.payment_families(id) ON DELETE CASCADE,
  purchase_id UUID NOT NULL REFERENCES public.payment_purchases(id) ON DELETE CASCADE,
  remaining INTEGER NOT NULL CHECK (remaining >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.payment_entitlements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID NOT NULL REFERENCES public.payment_families(id) ON DELETE CASCADE,
  learner_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  subject_id TEXT NOT NULL REFERENCES public.payment_subjects(id),
  pack_id TEXT NOT NULL REFERENCES public.payment_packs(id),
  purchase_id UUID REFERENCES public.payment_purchases(id) ON DELETE SET NULL,
  credit_id UUID REFERENCES public.payment_pack_credits(id) ON DELETE SET NULL,
  start_sequence INTEGER NOT NULL,
  end_sequence INTEGER NOT NULL,
  granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (learner_user_id, pack_id)
);

CREATE TABLE IF NOT EXISTS public.payment_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID REFERENCES public.payment_families(id) ON DELETE SET NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  event_type TEXT NOT NULL,
  subject_id TEXT,
  pack_id TEXT,
  purchase_id UUID,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS payment_entitlements_learner_idx
  ON public.payment_entitlements (learner_user_id, subject_id);
CREATE INDEX IF NOT EXISTS payment_purchases_family_idx
  ON public.payment_purchases (family_id, status);
CREATE INDEX IF NOT EXISTS payment_events_family_idx
  ON public.payment_events (family_id, created_at DESC);

ALTER TABLE public.payment_subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_packs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_families ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_family_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_pack_credits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_entitlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone reads payment subjects" ON public.payment_subjects;
CREATE POLICY "Anyone reads payment subjects"
  ON public.payment_subjects FOR SELECT TO authenticated
  USING (active);

DROP POLICY IF EXISTS "Anyone reads payment packs" ON public.payment_packs;
CREATE POLICY "Anyone reads payment packs"
  ON public.payment_packs FOR SELECT TO authenticated
  USING (TRUE);

DROP POLICY IF EXISTS "Members read own family" ON public.payment_families;
CREATE POLICY "Members read own family"
  ON public.payment_families FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.payment_family_members m
      WHERE m.family_id = payment_families.id AND m.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Members read family members" ON public.payment_family_members;
CREATE POLICY "Members read family members"
  ON public.payment_family_members FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.payment_family_members mine
      WHERE mine.family_id = payment_family_members.family_id
        AND mine.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Members read family purchases" ON public.payment_purchases;
CREATE POLICY "Members read family purchases"
  ON public.payment_purchases FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.payment_family_members m
      WHERE m.family_id = payment_purchases.family_id AND m.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Members read family credits" ON public.payment_pack_credits;
CREATE POLICY "Members read family credits"
  ON public.payment_pack_credits FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.payment_family_members m
      WHERE m.family_id = payment_pack_credits.family_id AND m.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Members read family entitlements" ON public.payment_entitlements;
CREATE POLICY "Members read family entitlements"
  ON public.payment_entitlements FOR SELECT TO authenticated
  USING (
    learner_user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.payment_family_members m
      WHERE m.family_id = payment_entitlements.family_id AND m.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Members read family payment events" ON public.payment_events;
CREATE POLICY "Members read family payment events"
  ON public.payment_events FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR (
      family_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.payment_family_members m
        WHERE m.family_id = payment_events.family_id AND m.user_id = auth.uid()
      )
    )
  );

INSERT INTO public.payment_subjects (id, title, description, lesson_count, sort_order)
VALUES
  (
    'mandarin',
    'Mandarin Foundation',
    'Speak, listen, and write your way through 30 sequenced Mandarin lessons.',
    30,
    1
  ),
  (
    'maths',
    'Mental Maths',
    'Twenty levels from number facts to simple algebra.',
    20,
    2
  )
ON CONFLICT (id) DO UPDATE
SET title = EXCLUDED.title,
    description = EXCLUDED.description,
    lesson_count = EXCLUDED.lesson_count,
    sort_order = EXCLUDED.sort_order;

INSERT INTO public.payment_packs (
  id, subject_id, pack_index, title, milestone_label,
  start_sequence, end_sequence, lesson_count, price_kobo
) VALUES
  (
    'mandarin_pack_1', 'mandarin', 1,
    'Pack 1 · Lessons 3–12',
    'Finish First Contact and step into My World',
    3, 12, 10, 250000
  ),
  (
    'mandarin_pack_2', 'mandarin', 2,
    'Pack 2 · Lessons 13–22',
    'Master My World and begin Everyday Mandarin',
    13, 22, 10, 250000
  ),
  (
    'mandarin_pack_3', 'mandarin', 3,
    'Pack 3 · Lessons 23–30',
    'Complete Everyday Mandarin',
    23, 30, 8, 250000
  ),
  (
    'maths_pack_1', 'maths', 1,
    'Pack 1 · Levels 3–12',
    'Secure number facts through early operations',
    3, 12, 10, 250000
  ),
  (
    'maths_pack_2', 'maths', 2,
    'Pack 2 · Levels 13–20',
    'Finish the mental maths pathway',
    13, 20, 8, 250000
  )
ON CONFLICT (id) DO UPDATE
SET title = EXCLUDED.title,
    milestone_label = EXCLUDED.milestone_label,
    start_sequence = EXCLUDED.start_sequence,
    end_sequence = EXCLUDED.end_sequence,
    lesson_count = EXCLUDED.lesson_count,
    price_kobo = EXCLUDED.price_kobo;

CREATE OR REPLACE FUNCTION private.ensure_payment_family(p_user_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_family UUID;
  v_label TEXT;
BEGIN
  SELECT family_id INTO v_family
  FROM public.payment_family_members
  WHERE user_id = p_user_id
  LIMIT 1;

  IF v_family IS NOT NULL THEN
    RETURN v_family;
  END IF;

  SELECT COALESCE(NULLIF(trim(display_name), ''), 'Family')
  INTO v_label
  FROM public.user_profiles
  WHERE user_id = p_user_id;

  INSERT INTO public.payment_families (label)
  VALUES (COALESCE(v_label, 'Family') || '''s family')
  RETURNING id INTO v_family;

  INSERT INTO public.payment_family_members (family_id, user_id, member_role)
  VALUES (v_family, p_user_id, 'owner');

  RETURN v_family;
END;
$$;

CREATE OR REPLACE FUNCTION private.record_payment_event(
  p_family_id UUID,
  p_user_id UUID,
  p_event_type TEXT,
  p_subject_id TEXT DEFAULT NULL,
  p_pack_id TEXT DEFAULT NULL,
  p_purchase_id UUID DEFAULT NULL,
  p_payload JSONB DEFAULT '{}'::jsonb
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
BEGIN
  INSERT INTO public.payment_events (
    family_id, user_id, event_type, subject_id, pack_id, purchase_id, payload
  ) VALUES (
    p_family_id, p_user_id, p_event_type, p_subject_id, p_pack_id, p_purchase_id,
    COALESCE(p_payload, '{}'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION private.user_has_lesson_access(
  p_user_id UUID,
  p_subject_id TEXT,
  p_sequence INTEGER
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
STABLE
AS $$
BEGIN
  IF p_sequence IS NULL OR p_sequence < 1 THEN
    RETURN FALSE;
  END IF;

  -- First two lessons in every subject are free.
  IF p_sequence <= 2 THEN
    RETURN TRUE;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM public.payment_entitlements e
    WHERE e.learner_user_id = p_user_id
      AND e.subject_id = p_subject_id
      AND p_sequence BETWEEN e.start_sequence AND e.end_sequence
  );
END;
$$;

CREATE OR REPLACE FUNCTION private.grant_pack_entitlement(
  p_family_id UUID,
  p_learner_user_id UUID,
  p_pack_id TEXT,
  p_purchase_id UUID DEFAULT NULL,
  p_credit_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_pack public.payment_packs%ROWTYPE;
  v_id UUID;
  v_subjects_before INTEGER;
  v_subjects_after INTEGER;
BEGIN
  SELECT * INTO v_pack FROM public.payment_packs WHERE id = p_pack_id;
  IF v_pack.id IS NULL THEN
    RAISE EXCEPTION 'PACK_NOT_FOUND';
  END IF;

  SELECT count(DISTINCT subject_id) INTO v_subjects_before
  FROM public.payment_entitlements
  WHERE family_id = p_family_id;

  INSERT INTO public.payment_entitlements (
    family_id, learner_user_id, subject_id, pack_id,
    purchase_id, credit_id, start_sequence, end_sequence
  ) VALUES (
    p_family_id, p_learner_user_id, v_pack.subject_id, v_pack.id,
    p_purchase_id, p_credit_id, v_pack.start_sequence, v_pack.end_sequence
  )
  ON CONFLICT (learner_user_id, pack_id) DO UPDATE
    SET granted_at = NOW()
  RETURNING id INTO v_id;

  SELECT count(DISTINCT subject_id) INTO v_subjects_after
  FROM public.payment_entitlements
  WHERE family_id = p_family_id;

  PERFORM private.record_payment_event(
    p_family_id,
    p_learner_user_id,
    CASE
      WHEN EXISTS (
        SELECT 1 FROM public.payment_entitlements
        WHERE family_id = p_family_id
          AND subject_id = v_pack.subject_id
          AND pack_id <> p_pack_id
          AND id <> v_id
      ) THEN 'repeat_subject_purchase'
      ELSE 'pack_granted'
    END,
    v_pack.subject_id,
    p_pack_id,
    p_purchase_id,
    jsonb_build_object('credit_id', p_credit_id)
  );

  IF v_subjects_after > v_subjects_before AND v_subjects_after > 1 THEN
    PERFORM private.record_payment_event(
      p_family_id,
      p_learner_user_id,
      'cross_subject_purchase',
      v_pack.subject_id,
      p_pack_id,
      p_purchase_id,
      jsonb_build_object('subject_count', v_subjects_after)
    );
  END IF;

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION private.fulfill_paid_purchase(p_reference TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_purchase public.payment_purchases%ROWTYPE;
  v_credit_id UUID;
BEGIN
  SELECT * INTO v_purchase
  FROM public.payment_purchases
  WHERE paystack_reference = p_reference
  FOR UPDATE;

  IF v_purchase.id IS NULL THEN
    RAISE EXCEPTION 'PURCHASE_NOT_FOUND';
  END IF;

  IF v_purchase.status = 'paid' THEN
    RETURN jsonb_build_object('ok', TRUE, 'already_paid', TRUE, 'id', v_purchase.id);
  END IF;

  UPDATE public.payment_purchases
  SET status = 'paid', paid_at = NOW()
  WHERE id = v_purchase.id;

  IF v_purchase.product_type = 'subject_pack' THEN
    PERFORM private.grant_pack_entitlement(
      v_purchase.family_id,
      v_purchase.buyer_user_id,
      v_purchase.pack_id,
      v_purchase.id,
      NULL
    );
  ELSIF v_purchase.product_type = 'bundle_3' THEN
    INSERT INTO public.payment_pack_credits (family_id, purchase_id, remaining)
    VALUES (v_purchase.family_id, v_purchase.id, 3)
    RETURNING id INTO v_credit_id;

    PERFORM private.record_payment_event(
      v_purchase.family_id,
      v_purchase.buyer_user_id,
      'bundle_credits_granted',
      NULL,
      NULL,
      v_purchase.id,
      jsonb_build_object('credits', 3, 'credit_id', v_credit_id)
    );
  END IF;

  PERFORM private.record_payment_event(
    v_purchase.family_id,
    v_purchase.buyer_user_id,
    'purchase_paid',
    v_purchase.subject_id,
    v_purchase.pack_id,
    v_purchase.id,
    jsonb_build_object('product_type', v_purchase.product_type)
  );

  RETURN jsonb_build_object('ok', TRUE, 'id', v_purchase.id);
END;
$$;

-- Patch foundation completion to require pack entitlement.
CREATE OR REPLACE FUNCTION private.complete_foundation_lesson(
  p_user_id UUID,
  p_lesson_id TEXT,
  p_score INTEGER,
  p_answers JSONB,
  p_minutes INTEGER DEFAULT 10
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_inserted INTEGER;
  v_sequence INTEGER;
  v_reward INTEGER;
  v_pack public.payment_packs%ROWTYPE;
  v_family UUID;
  v_completed_in_pack INTEGER;
BEGIN
  SELECT sequence, xp_reward
  INTO v_sequence, v_reward
  FROM public.course_lessons
  WHERE id = p_lesson_id AND status = 'approved';

  IF v_sequence IS NULL THEN
    RAISE EXCEPTION 'LESSON_NOT_APPROVED';
  END IF;

  IF NOT private.user_has_lesson_access(p_user_id, 'mandarin', v_sequence) THEN
    RAISE EXCEPTION 'PACK_PURCHASE_REQUIRED';
  END IF;

  IF v_sequence > 1 AND NOT EXISTS (
    SELECT 1
    FROM public.course_lessons previous
    JOIN public.lesson_results result
      ON result.lesson_id = previous.id
     AND result.user_id = p_user_id
    WHERE previous.course_id = 'mandarin_foundation_v1'
      AND previous.sequence = v_sequence - 1
  ) THEN
    RAISE EXCEPTION 'PREVIOUS_LESSON_REQUIRED';
  END IF;

  INSERT INTO public.lesson_results(user_id, lesson_id, score, answers)
  VALUES (
    p_user_id,
    p_lesson_id,
    greatest(0, least(100, p_score)),
    COALESCE(p_answers, '[]'::jsonb)
  )
  ON CONFLICT(user_id, lesson_id) DO NOTHING;
  GET DIAGNOSTICS v_inserted = ROW_COUNT;

  IF v_inserted = 1 THEN
    UPDATE public.user_profiles
    SET xp = xp + greatest(0, v_reward),
        level = floor((xp + greatest(0, v_reward)) / 500.0) + 1,
        streak_days = CASE
          WHEN last_activity_date = CURRENT_DATE THEN streak_days
          WHEN last_activity_date = CURRENT_DATE - 1 THEN streak_days + 1
          ELSE 1
        END,
        last_activity_date = CURRENT_DATE,
        lessons_completed = lessons_completed + 1,
        minutes_learned = minutes_learned + greatest(1, p_minutes),
        updated_at = NOW()
    WHERE user_id = p_user_id;

    SELECT * INTO v_pack
    FROM public.payment_packs
    WHERE subject_id = 'mandarin'
      AND v_sequence BETWEEN start_sequence AND end_sequence
    LIMIT 1;

    IF v_pack.id IS NOT NULL THEN
      v_family := private.ensure_payment_family(p_user_id);
      SELECT count(*)::int INTO v_completed_in_pack
      FROM public.lesson_results lr
      JOIN public.course_lessons cl ON cl.id = lr.lesson_id
      WHERE lr.user_id = p_user_id
        AND cl.course_id = 'mandarin_foundation_v1'
        AND cl.sequence BETWEEN v_pack.start_sequence AND v_pack.end_sequence;

      IF v_completed_in_pack = 8 THEN
        PERFORM private.record_payment_event(
          v_family,
          p_user_id,
          'pack_renew_prompt',
          'mandarin',
          v_pack.id,
          NULL,
          jsonb_build_object(
            'completed_in_pack', v_completed_in_pack,
            'pack_lesson_count', v_pack.lesson_count,
            'sequence', v_sequence
          )
        );
      END IF;

      IF v_completed_in_pack >= v_pack.lesson_count THEN
        PERFORM private.record_payment_event(
          v_family,
          p_user_id,
          'pack_completed',
          'mandarin',
          v_pack.id,
          NULL,
          jsonb_build_object('completed_in_pack', v_completed_in_pack)
        );
      END IF;
    END IF;
  ELSE
    UPDATE public.lesson_results
    SET score = greatest(score, greatest(0, least(100, p_score))),
        answers = CASE
          WHEN p_score >= score THEN COALESCE(p_answers, answers)
          ELSE answers
        END,
        completed_at = NOW()
    WHERE user_id = p_user_id AND lesson_id = p_lesson_id;
  END IF;

  RETURN v_inserted = 1;
END;
$$;

-- Public RPCs for the app
CREATE OR REPLACE FUNCTION public.payment_catalog()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  RETURN jsonb_build_object(
    'free_lessons', 2,
    'pack_price_kobo', 250000,
    'bundle_price_kobo', 650000,
    'bundle_credits', 3,
    'currency', 'NGN',
    'subjects', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', s.id,
        'title', s.title,
        'description', s.description,
        'lesson_count', s.lesson_count,
        'packs', COALESCE((
          SELECT jsonb_agg(jsonb_build_object(
            'id', p.id,
            'pack_index', p.pack_index,
            'title', p.title,
            'milestone_label', p.milestone_label,
            'start_sequence', p.start_sequence,
            'end_sequence', p.end_sequence,
            'lesson_count', p.lesson_count,
            'price_kobo', p.price_kobo
          ) ORDER BY p.pack_index)
          FROM public.payment_packs p
          WHERE p.subject_id = s.id
        ), '[]'::jsonb)
      ) ORDER BY s.sort_order)
      FROM public.payment_subjects s
      WHERE s.active
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.payment_my_access()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_family UUID;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  v_family := private.ensure_payment_family(v_user);

  RETURN jsonb_build_object(
    'family_id', v_family,
    'credits_remaining', COALESCE((
      SELECT sum(remaining)::int FROM public.payment_pack_credits
      WHERE family_id = v_family
    ), 0),
    'entitlements', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', e.id,
        'subject_id', e.subject_id,
        'pack_id', e.pack_id,
        'start_sequence', e.start_sequence,
        'end_sequence', e.end_sequence,
        'granted_at', e.granted_at
      ) ORDER BY e.granted_at)
      FROM public.payment_entitlements e
      WHERE e.learner_user_id = v_user
    ), '[]'::jsonb),
    'purchases', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', p.id,
        'product_type', p.product_type,
        'subject_id', p.subject_id,
        'pack_id', p.pack_id,
        'amount_kobo', p.amount_kobo,
        'status', p.status,
        'created_at', p.created_at,
        'paid_at', p.paid_at
      ) ORDER BY p.created_at DESC)
      FROM public.payment_purchases p
      WHERE p.family_id = v_family
      LIMIT 50
    ), '[]'::jsonb),
    'stats', jsonb_build_object(
      'paid_purchases', (
        SELECT count(*)::int FROM public.payment_purchases
        WHERE family_id = v_family AND status = 'paid'
      ),
      'packs_owned', (
        SELECT count(*)::int FROM public.payment_entitlements
        WHERE family_id = v_family
      ),
      'packs_completed', (
        SELECT count(*)::int FROM public.payment_events
        WHERE family_id = v_family AND event_type = 'pack_completed'
      ),
      'repeat_purchases', (
        SELECT count(*)::int FROM public.payment_events
        WHERE family_id = v_family AND event_type = 'repeat_subject_purchase'
      ),
      'cross_subject_purchases', (
        SELECT count(*)::int FROM public.payment_events
        WHERE family_id = v_family AND event_type = 'cross_subject_purchase'
      ),
      'subjects_purchased', (
        SELECT count(DISTINCT subject_id)::int FROM public.payment_entitlements
        WHERE family_id = v_family
      )
    )
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
BEGIN
  IF p_buyer_user_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  IF p_product_type NOT IN ('subject_pack', 'bundle_3') THEN
    RAISE EXCEPTION 'INVALID_PRODUCT';
  END IF;

  v_learner := COALESCE(p_learner_user_id, p_buyer_user_id);
  v_family := private.ensure_payment_family(p_buyer_user_id);

  IF v_learner <> p_buyer_user_id AND NOT EXISTS (
    SELECT 1 FROM public.payment_family_members
    WHERE family_id = v_family AND user_id = v_learner
  ) THEN
    INSERT INTO public.payment_family_members (family_id, user_id, member_role)
    VALUES (v_family, v_learner, 'learner')
    ON CONFLICT DO NOTHING;
  END IF;

  IF p_product_type = 'subject_pack' THEN
    SELECT * INTO v_pack FROM public.payment_packs WHERE id = p_pack_id;
    IF v_pack.id IS NULL THEN
      RAISE EXCEPTION 'PACK_NOT_FOUND';
    END IF;
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

  v_reference := 'kv_' || replace(gen_random_uuid()::text, '-', '');

  INSERT INTO public.payment_purchases (
    family_id, buyer_user_id, product_type, subject_id, pack_id,
    amount_kobo, paystack_reference, metadata
  ) VALUES (
    v_family,
    p_buyer_user_id,
    p_product_type,
    v_pack.subject_id,
    v_pack.id,
    v_amount,
    v_reference,
    jsonb_build_object('learner_user_id', v_learner)
  )
  RETURNING id INTO v_id;

  PERFORM private.record_payment_event(
    v_family, p_buyer_user_id, 'purchase_started',
    v_pack.subject_id, v_pack.id, v_id,
    jsonb_build_object('product_type', p_product_type)
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
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;
  RETURN private.payment_create_checkout(
    auth.uid(), p_product_type, p_pack_id, p_learner_user_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.payment_redeem_credit(p_pack_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_family UUID;
  v_credit public.payment_pack_credits%ROWTYPE;
  v_pack public.payment_packs%ROWTYPE;
  v_entitlement UUID;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  SELECT * INTO v_pack FROM public.payment_packs WHERE id = p_pack_id;
  IF v_pack.id IS NULL THEN
    RAISE EXCEPTION 'PACK_NOT_FOUND';
  END IF;

  v_family := private.ensure_payment_family(v_user);

  IF EXISTS (
    SELECT 1 FROM public.payment_entitlements
    WHERE learner_user_id = v_user AND pack_id = p_pack_id
  ) THEN
    RAISE EXCEPTION 'PACK_ALREADY_OWNED';
  END IF;

  SELECT * INTO v_credit
  FROM public.payment_pack_credits
  WHERE family_id = v_family AND remaining > 0
  ORDER BY created_at
  LIMIT 1
  FOR UPDATE;

  IF v_credit.id IS NULL THEN
    RAISE EXCEPTION 'NO_CREDITS';
  END IF;

  UPDATE public.payment_pack_credits
  SET remaining = remaining - 1
  WHERE id = v_credit.id;

  v_entitlement := private.grant_pack_entitlement(
    v_family, v_user, p_pack_id, v_credit.purchase_id, v_credit.id
  );

  PERFORM private.record_payment_event(
    v_family, v_user, 'credit_redeemed',
    v_pack.subject_id, p_pack_id, v_credit.purchase_id,
    jsonb_build_object('credit_id', v_credit.id, 'entitlement_id', v_entitlement)
  );

  RETURN jsonb_build_object(
    'ok', TRUE,
    'entitlement_id', v_entitlement,
    'credits_remaining', (
      SELECT COALESCE(sum(remaining), 0)::int
      FROM public.payment_pack_credits
      WHERE family_id = v_family
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.payment_mark_prompt_seen(p_pack_id TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_family UUID;
  v_pack public.payment_packs%ROWTYPE;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;
  SELECT * INTO v_pack FROM public.payment_packs WHERE id = p_pack_id;
  v_family := private.ensure_payment_family(v_user);
  PERFORM private.record_payment_event(
    v_family, v_user, 'renew_prompt_shown',
    v_pack.subject_id, p_pack_id, NULL, '{}'::jsonb
  );
END;
$$;

REVOKE ALL ON FUNCTION public.payment_catalog() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.payment_my_access() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.payment_create_checkout(TEXT, TEXT, UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.payment_redeem_credit(TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.payment_mark_prompt_seen(TEXT) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.payment_catalog() TO authenticated;
GRANT EXECUTE ON FUNCTION public.payment_my_access() TO authenticated;
GRANT EXECUTE ON FUNCTION public.payment_create_checkout(TEXT, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.payment_redeem_credit(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.payment_mark_prompt_seen(TEXT) TO authenticated;

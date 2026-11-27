-- Support actions on pupil profiles, bulk score upload batches, and the
-- Communication Book (class announcements, private guardian updates, with
-- separate viewed / acknowledged receipts and replies).
--
-- Access follows the results model: teachers of the pupil's class and school
-- admins manage; the pupil and linked guardians read what is shared with them.

-- Support actions ------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.pupil_support_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  subject_id UUID REFERENCES public.school_subjects(id) ON DELETE SET NULL,
  action TEXT NOT NULL CHECK (char_length(btrim(action)) BETWEEN 3 AND 500),
  owner_label TEXT CHECK (char_length(owner_label) <= 80),
  due_on DATE,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'done', 'cancelled')),
  outcome TEXT CHECK (char_length(outcome) <= 500),
  shared_with_family BOOLEAN NOT NULL DEFAULT TRUE,
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  closed_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS pupil_support_student_idx ON public.pupil_support_actions (student_id, status);
CREATE INDEX IF NOT EXISTS pupil_support_subject_idx ON public.pupil_support_actions (subject_id);
CREATE INDEX IF NOT EXISTS pupil_support_creator_idx ON public.pupil_support_actions (created_by);

-- Score upload batches ---------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.result_batches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id UUID REFERENCES public.classes(id) ON DELETE SET NULL,
  term_id UUID REFERENCES public.school_terms(id) ON DELETE SET NULL,
  kind TEXT NOT NULL CHECK (kind IN ('baseline', 'test', 'exam')),
  title TEXT NOT NULL DEFAULT '' CHECK (char_length(title) <= 80),
  assessed_on DATE NOT NULL DEFAULT current_date,
  row_count INT NOT NULL DEFAULT 0,
  file_name TEXT CHECK (char_length(file_name) <= 200),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  undone_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS result_batches_class_idx ON public.result_batches (class_id, created_at DESC);
CREATE INDEX IF NOT EXISTS result_batches_term_idx ON public.result_batches (term_id);
CREATE INDEX IF NOT EXISTS result_batches_creator_idx ON public.result_batches (created_by);

ALTER TABLE public.pupil_results
  ADD COLUMN IF NOT EXISTS batch_id UUID REFERENCES public.result_batches(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS pupil_results_batch_idx ON public.pupil_results (batch_id);

-- Communication Book -----------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.comm_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  student_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN ('announcement', 'private')),
  subject TEXT NOT NULL CHECK (char_length(btrim(subject)) BETWEEN 2 AND 120),
  body TEXT NOT NULL CHECK (char_length(btrim(body)) BETWEEN 1 AND 5000),
  needs_ack BOOLEAN NOT NULL DEFAULT FALSE,
  author_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT comm_private_has_student CHECK ((kind = 'private') = (student_id IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS comm_messages_class_idx ON public.comm_messages (class_id, created_at DESC);
CREATE INDEX IF NOT EXISTS comm_messages_student_idx ON public.comm_messages (student_id);
CREATE INDEX IF NOT EXISTS comm_messages_author_idx ON public.comm_messages (author_id);

CREATE TABLE IF NOT EXISTS public.comm_receipts (
  message_id UUID NOT NULL REFERENCES public.comm_messages(id) ON DELETE CASCADE,
  guardian_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  viewed_at TIMESTAMPTZ,
  acknowledged_at TIMESTAMPTZ,
  PRIMARY KEY (message_id, guardian_id)
);
CREATE INDEX IF NOT EXISTS comm_receipts_guardian_idx ON public.comm_receipts (guardian_id);

CREATE TABLE IF NOT EXISTS public.comm_replies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES public.comm_messages(id) ON DELETE CASCADE,
  author_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  body TEXT NOT NULL CHECK (char_length(btrim(body)) BETWEEN 1 AND 2000),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS comm_replies_message_idx ON public.comm_replies (message_id, created_at);
CREATE INDEX IF NOT EXISTS comm_replies_author_idx ON public.comm_replies (author_id);

ALTER TABLE public.pupil_support_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.result_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comm_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comm_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comm_replies ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.pupil_support_actions, public.result_batches, public.comm_messages,
  public.comm_receipts, public.comm_replies FROM PUBLIC, anon, authenticated;

-- Support action functions -------------------------------------------------------

CREATE OR REPLACE FUNCTION public.support_actions(p_student UUID)
RETURNS JSONB
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_staff BOOLEAN;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  IF NOT private.can_view_pupil(p_student) THEN RAISE EXCEPTION 'NOT_AUTHORIZED'; END IF;
  v_staff := private.can_manage_pupil(p_student);
  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'id', a.id, 'action', a.action, 'subject_id', a.subject_id, 'subject', s.name,
      'owner', a.owner_label, 'due_on', a.due_on, 'status', a.status, 'outcome', a.outcome,
      'shared', a.shared_with_family, 'by', p.display_name, 'created_at', a.created_at,
      'closed_at', a.closed_at
    ) ORDER BY CASE a.status WHEN 'open' THEN 0 ELSE 1 END, a.due_on NULLS LAST, a.created_at DESC)
    FROM public.pupil_support_actions a
    LEFT JOIN public.school_subjects s ON s.id = a.subject_id
    LEFT JOIN public.user_profiles p ON p.user_id = a.created_by
    WHERE a.student_id = p_student AND (v_staff OR a.shared_with_family)
  ), '[]'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION public.save_support_action(
  p_student UUID, p_action TEXT, p_id UUID DEFAULT NULL, p_subject UUID DEFAULT NULL,
  p_owner TEXT DEFAULT NULL, p_due DATE DEFAULT NULL, p_shared BOOLEAN DEFAULT TRUE
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_school UUID := private.pupil_school(p_student);
  v_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  IF NOT private.can_manage_pupil(p_student) THEN RAISE EXCEPTION 'NOT_AUTHORIZED'; END IF;
  IF char_length(btrim(COALESCE(p_action, ''))) < 3 THEN RAISE EXCEPTION 'INVALID_ACTION'; END IF;
  IF p_subject IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.school_subjects WHERE id = p_subject AND school_id = v_school
  ) THEN RAISE EXCEPTION 'INVALID_SUBJECT'; END IF;

  IF p_id IS NULL THEN
    INSERT INTO public.pupil_support_actions
      (student_id, subject_id, action, owner_label, due_on, shared_with_family, created_by)
    VALUES (p_student, p_subject, left(btrim(p_action), 500), NULLIF(left(btrim(COALESCE(p_owner, '')), 80), ''),
      p_due, COALESCE(p_shared, TRUE), auth.uid())
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.pupil_support_actions SET
      subject_id = p_subject, action = left(btrim(p_action), 500),
      owner_label = NULLIF(left(btrim(COALESCE(p_owner, '')), 80), ''), due_on = p_due,
      shared_with_family = COALESCE(p_shared, TRUE), updated_at = now()
    WHERE id = p_id AND student_id = p_student
    RETURNING id INTO v_id;
    IF v_id IS NULL THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  END IF;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_support_status(p_id UUID, p_status TEXT, p_outcome TEXT DEFAULT NULL)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_student UUID;
BEGIN
  SELECT student_id INTO v_student FROM public.pupil_support_actions WHERE id = p_id;
  IF v_student IS NULL THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF NOT private.can_manage_pupil(v_student) THEN RAISE EXCEPTION 'NOT_AUTHORIZED'; END IF;
  IF p_status NOT IN ('open', 'done', 'cancelled') THEN RAISE EXCEPTION 'INVALID_STATUS'; END IF;
  UPDATE public.pupil_support_actions SET
    status = p_status,
    outcome = COALESCE(NULLIF(left(btrim(COALESCE(p_outcome, '')), 500), ''), outcome),
    closed_at = CASE WHEN p_status = 'open' THEN NULL ELSE now() END,
    updated_at = now()
  WHERE id = p_id;
END;
$$;

-- Bulk score upload ------------------------------------------------------------------

-- Save one uploaded sheet: rows [{student_id, subject_id, score}]. Every row is
-- checked; if any row is invalid nothing is saved. A baseline replaces the
-- pupil's existing baseline for that subject and term.
CREATE OR REPLACE FUNCTION public.import_class_scores(
  p_class_id UUID, p_kind TEXT, p_rows JSONB, p_title TEXT DEFAULT '',
  p_assessed_on DATE DEFAULT NULL, p_file_name TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_school UUID;
  v_term UUID;
  v_batch UUID;
  v_bad INT;
  v_count INT;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  IF NOT private.is_class_teacher(p_class_id) THEN RAISE EXCEPTION 'NOT_AUTHORIZED'; END IF;
  IF p_kind NOT IN ('baseline', 'test', 'exam') THEN RAISE EXCEPTION 'INVALID_KIND'; END IF;
  IF p_rows IS NULL OR jsonb_typeof(p_rows) <> 'array' OR jsonb_array_length(p_rows) = 0 THEN
    RAISE EXCEPTION 'NO_ROWS';
  END IF;
  IF jsonb_array_length(p_rows) > 5000 THEN RAISE EXCEPTION 'TOO_MANY_ROWS'; END IF;
  SELECT school_id INTO v_school FROM public.classes WHERE id = p_class_id;
  IF v_school IS NULL THEN RAISE EXCEPTION 'NEEDS_SCHOOL'; END IF;
  v_term := private.current_term(v_school);

  SELECT count(*) INTO v_bad
  FROM jsonb_array_elements(p_rows) r
  WHERE NOT (
    jsonb_typeof(r->'score') = 'number'
    AND (r->>'score')::numeric BETWEEN 0 AND 100
    AND EXISTS (SELECT 1 FROM public.class_members cm
                WHERE cm.class_id = p_class_id AND cm.user_id::text = r->>'student_id')
    AND EXISTS (SELECT 1 FROM public.school_subjects s
                WHERE s.school_id = v_school AND s.id::text = r->>'subject_id')
  );
  IF v_bad > 0 THEN RAISE EXCEPTION 'INVALID_ROWS:%', v_bad; END IF;

  INSERT INTO public.result_batches (class_id, term_id, kind, title, assessed_on, file_name, created_by)
  VALUES (p_class_id, v_term, p_kind, left(btrim(COALESCE(p_title, '')), 80),
    COALESCE(p_assessed_on, current_date), left(p_file_name, 200), auth.uid())
  RETURNING id INTO v_batch;

  IF p_kind = 'baseline' THEN
    DELETE FROM public.pupil_results pr
    USING jsonb_array_elements(p_rows) r
    WHERE pr.term_id = v_term AND pr.kind = 'baseline'
      AND pr.student_id::text = r->>'student_id' AND pr.subject_id::text = r->>'subject_id';
  END IF;

  INSERT INTO public.pupil_results
    (student_id, subject_id, term_id, kind, title, score, assessed_on, recorded_by, batch_id)
  SELECT (r->>'student_id')::uuid, (r->>'subject_id')::uuid, v_term, p_kind,
    left(btrim(COALESCE(p_title, '')), 80), round((r->>'score')::numeric, 2),
    COALESCE(p_assessed_on, current_date), auth.uid(), v_batch
  FROM jsonb_array_elements(p_rows) r;
  GET DIAGNOSTICS v_count = ROW_COUNT;

  UPDATE public.result_batches SET row_count = v_count WHERE id = v_batch;
  RETURN jsonb_build_object('batch_id', v_batch, 'saved', v_count);
END;
$$;

CREATE OR REPLACE FUNCTION public.score_batches(p_class_id UUID)
RETURNS JSONB
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, private
AS $$
BEGIN
  IF NOT private.is_class_teacher(p_class_id) THEN RAISE EXCEPTION 'NOT_AUTHORIZED'; END IF;
  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'id', b.id, 'kind', b.kind, 'title', b.title, 'assessed_on', b.assessed_on,
      'rows', b.row_count, 'file_name', b.file_name, 'by', p.display_name,
      'created_at', b.created_at, 'undone_at', b.undone_at
    ) ORDER BY b.created_at DESC)
    FROM (SELECT * FROM public.result_batches WHERE class_id = p_class_id ORDER BY created_at DESC LIMIT 20) b
    LEFT JOIN public.user_profiles p ON p.user_id = b.created_by
  ), '[]'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION public.undo_score_batch(p_batch UUID)
RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_class UUID;
  v_undone TIMESTAMPTZ;
  v_count INT;
BEGIN
  SELECT class_id, undone_at INTO v_class, v_undone FROM public.result_batches WHERE id = p_batch;
  IF v_class IS NULL THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF NOT private.is_class_teacher(v_class) THEN RAISE EXCEPTION 'NOT_AUTHORIZED'; END IF;
  IF v_undone IS NOT NULL THEN RETURN 0; END IF;
  DELETE FROM public.pupil_results WHERE batch_id = p_batch;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  UPDATE public.result_batches SET undone_at = now() WHERE id = p_batch;
  RETURN v_count;
END;
$$;

-- Communication Book functions -------------------------------------------------------

-- Guardians who should receive a message, with the pupil they are linked to.
CREATE OR REPLACE FUNCTION private.comm_recipients(p_message UUID)
RETURNS TABLE (guardian_id UUID, student_id UUID)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, private
AS $$
  SELECT DISTINCT g.user_id, l.user_id
  FROM public.comm_messages m
  JOIN public.class_members cm ON cm.class_id = m.class_id
    AND (m.kind = 'announcement' OR cm.user_id = m.student_id)
  JOIN public.payment_family_members l ON l.user_id = cm.user_id AND l.member_role = 'learner'
  JOIN public.payment_family_members g ON g.family_id = l.family_id
    AND g.member_role IN ('owner', 'guardian') AND g.user_id <> l.user_id
  WHERE m.id = p_message;
$$;

CREATE OR REPLACE FUNCTION private.comm_is_recipient(p_message UUID)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, private
AS $$
  SELECT EXISTS (SELECT 1 FROM private.comm_recipients(p_message) r WHERE r.guardian_id = auth.uid());
$$;

REVOKE ALL ON FUNCTION private.comm_recipients(UUID), private.comm_is_recipient(UUID)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.comm_post(
  p_class_id UUID, p_kind TEXT, p_subject TEXT, p_body TEXT,
  p_student UUID DEFAULT NULL, p_needs_ack BOOLEAN DEFAULT FALSE
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  IF NOT private.is_class_teacher(p_class_id) THEN RAISE EXCEPTION 'NOT_AUTHORIZED'; END IF;
  IF p_kind NOT IN ('announcement', 'private') THEN RAISE EXCEPTION 'INVALID_KIND'; END IF;
  IF p_kind = 'private' AND NOT EXISTS (
    SELECT 1 FROM public.class_members WHERE class_id = p_class_id AND user_id = p_student
  ) THEN RAISE EXCEPTION 'NOT_IN_CLASS'; END IF;
  IF char_length(btrim(COALESCE(p_subject, ''))) < 2 THEN RAISE EXCEPTION 'INVALID_SUBJECT'; END IF;
  IF char_length(btrim(COALESCE(p_body, ''))) < 1 THEN RAISE EXCEPTION 'EMPTY_MESSAGE'; END IF;
  INSERT INTO public.comm_messages (class_id, student_id, kind, subject, body, needs_ack, author_id)
  VALUES (p_class_id, CASE WHEN p_kind = 'private' THEN p_student END, p_kind,
    left(btrim(p_subject), 120), left(btrim(p_body), 5000), COALESCE(p_needs_ack, FALSE), auth.uid())
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

-- Teacher view: the class's messages with reach and receipt counts.
CREATE OR REPLACE FUNCTION public.comm_class_messages(p_class_id UUID)
RETURNS JSONB
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, private
AS $$
BEGIN
  IF NOT private.is_class_teacher(p_class_id) THEN RAISE EXCEPTION 'NOT_AUTHORIZED'; END IF;
  RETURN jsonb_build_object(
    'guardians_linked', (
      SELECT count(DISTINCT g.user_id) FROM public.class_members cm
      JOIN public.payment_family_members l ON l.user_id = cm.user_id AND l.member_role = 'learner'
      JOIN public.payment_family_members g ON g.family_id = l.family_id
        AND g.member_role IN ('owner', 'guardian') AND g.user_id <> l.user_id
      WHERE cm.class_id = p_class_id
    ),
    'pupils', (SELECT count(*) FROM public.class_members WHERE class_id = p_class_id),
    'messages', COALESCE((
      SELECT jsonb_agg(x ORDER BY (x->>'created_at') DESC) FROM (
        SELECT jsonb_build_object(
          'id', m.id, 'kind', m.kind, 'subject', m.subject, 'body', left(m.body, 240),
          'needs_ack', m.needs_ack, 'created_at', m.created_at,
          'author', ap.display_name, 'student_id', m.student_id, 'student', sp.display_name,
          'recipients', (SELECT count(*) FROM private.comm_recipients(m.id)),
          'viewed', (SELECT count(*) FROM public.comm_receipts r WHERE r.message_id = m.id AND r.viewed_at IS NOT NULL),
          'acknowledged', (SELECT count(*) FROM public.comm_receipts r WHERE r.message_id = m.id AND r.acknowledged_at IS NOT NULL),
          'replies', (SELECT count(*) FROM public.comm_replies r WHERE r.message_id = m.id)
        ) AS x
        FROM public.comm_messages m
        LEFT JOIN public.user_profiles ap ON ap.user_id = m.author_id
        LEFT JOIN public.user_profiles sp ON sp.user_id = m.student_id
        WHERE m.class_id = p_class_id
        ORDER BY m.created_at DESC LIMIT 100
      ) s
    ), '[]'::jsonb)
  );
END;
$$;

-- One message. Teachers also get every recipient's viewed / acknowledged state.
CREATE OR REPLACE FUNCTION public.comm_message(p_message UUID)
RETURNS JSONB
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_m public.comm_messages%ROWTYPE;
  v_teacher BOOLEAN;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  SELECT * INTO v_m FROM public.comm_messages WHERE id = p_message;
  IF v_m.id IS NULL THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  v_teacher := private.is_class_teacher(v_m.class_id);
  IF NOT v_teacher AND NOT private.comm_is_recipient(p_message) THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  RETURN jsonb_build_object(
    'id', v_m.id, 'kind', v_m.kind, 'subject', v_m.subject, 'body', v_m.body,
    'needs_ack', v_m.needs_ack, 'created_at', v_m.created_at, 'can_manage', v_teacher,
    'author', (SELECT display_name FROM public.user_profiles WHERE user_id = v_m.author_id),
    'class_name', (SELECT name FROM public.classes WHERE id = v_m.class_id),
    'student', (SELECT display_name FROM public.user_profiles WHERE user_id = v_m.student_id),
    'mine', (SELECT jsonb_build_object('viewed_at', viewed_at, 'acknowledged_at', acknowledged_at)
             FROM public.comm_receipts WHERE message_id = p_message AND guardian_id = auth.uid()),
    'recipients', CASE WHEN v_teacher THEN COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'guardian_id', r.guardian_id, 'guardian', gp.display_name, 'student', sp.display_name,
        'viewed_at', rc.viewed_at, 'acknowledged_at', rc.acknowledged_at
      ) ORDER BY lower(sp.display_name))
      FROM private.comm_recipients(p_message) r
      LEFT JOIN public.user_profiles gp ON gp.user_id = r.guardian_id
      LEFT JOIN public.user_profiles sp ON sp.user_id = r.student_id
      LEFT JOIN public.comm_receipts rc ON rc.message_id = p_message AND rc.guardian_id = r.guardian_id
    ), '[]'::jsonb) END,
    'replies', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('id', rp.id, 'body', rp.body, 'author', up.display_name,
        'mine', rp.author_id = auth.uid(), 'from_staff', x.staff,
        'created_at', rp.created_at) ORDER BY rp.created_at)
      FROM public.comm_replies rp
      LEFT JOIN public.user_profiles up ON up.user_id = rp.author_id
      CROSS JOIN LATERAL (SELECT (rp.author_id = v_m.author_id OR EXISTS (
        SELECT 1 FROM public.classes c WHERE c.id = v_m.class_id AND c.teacher_id = rp.author_id)) AS staff) x
      WHERE rp.message_id = p_message
        -- Announcement threads: a guardian sees staff replies and their own.
        AND (v_teacher OR v_m.kind = 'private' OR rp.author_id = auth.uid() OR x.staff)
    ), '[]'::jsonb)
  );
END;
$$;

-- Parent inbox: every message sent to the caller as a guardian.
CREATE OR REPLACE FUNCTION public.comm_inbox()
RETURNS JSONB
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, private
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  RETURN COALESCE((
    SELECT jsonb_agg(x ORDER BY (x->>'created_at') DESC) FROM (
      SELECT DISTINCT ON (m.id) jsonb_build_object(
        'id', m.id, 'kind', m.kind, 'subject', m.subject, 'body', left(m.body, 200),
        'needs_ack', m.needs_ack, 'created_at', m.created_at,
        'author', ap.display_name, 'class_name', c.name,
        'student', sp.display_name,
        'viewed_at', rc.viewed_at, 'acknowledged_at', rc.acknowledged_at
      ) AS x
      FROM public.payment_family_members g
      JOIN public.payment_family_members l ON l.family_id = g.family_id AND l.member_role = 'learner'
        AND l.user_id <> g.user_id
      JOIN public.class_members cm ON cm.user_id = l.user_id
      JOIN public.comm_messages m ON m.class_id = cm.class_id
        AND (m.kind = 'announcement' OR m.student_id = l.user_id)
      JOIN public.classes c ON c.id = m.class_id
      LEFT JOIN public.user_profiles ap ON ap.user_id = m.author_id
      LEFT JOIN public.user_profiles sp ON sp.user_id = l.user_id
      LEFT JOIN public.comm_receipts rc ON rc.message_id = m.id AND rc.guardian_id = auth.uid()
      WHERE g.user_id = auth.uid() AND g.member_role IN ('owner', 'guardian')
      ORDER BY m.id
      LIMIT 200
    ) s
  ), '[]'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION public.comm_mark_viewed(p_message UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, private
AS $$
BEGIN
  IF NOT private.comm_is_recipient(p_message) THEN RETURN; END IF;
  INSERT INTO public.comm_receipts (message_id, guardian_id, viewed_at)
  VALUES (p_message, auth.uid(), now())
  ON CONFLICT (message_id, guardian_id)
  DO UPDATE SET viewed_at = COALESCE(public.comm_receipts.viewed_at, EXCLUDED.viewed_at);
END;
$$;

CREATE OR REPLACE FUNCTION public.comm_acknowledge(p_message UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, private
AS $$
BEGIN
  IF NOT private.comm_is_recipient(p_message) THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  INSERT INTO public.comm_receipts (message_id, guardian_id, viewed_at, acknowledged_at)
  VALUES (p_message, auth.uid(), now(), now())
  ON CONFLICT (message_id, guardian_id)
  DO UPDATE SET viewed_at = COALESCE(public.comm_receipts.viewed_at, now()),
                acknowledged_at = COALESCE(public.comm_receipts.acknowledged_at, now());
END;
$$;

-- Replies: guardians on private updates (and to ask about announcements, seen
-- only by staff and themselves); the class teacher on any of the class's
-- messages.
CREATE OR REPLACE FUNCTION public.comm_reply(p_message UUID, p_body TEXT)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_class UUID;
  v_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  SELECT class_id INTO v_class FROM public.comm_messages WHERE id = p_message;
  IF v_class IS NULL THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF NOT private.is_class_teacher(v_class) AND NOT private.comm_is_recipient(p_message) THEN
    RAISE EXCEPTION 'NOT_FOUND';
  END IF;
  IF char_length(btrim(COALESCE(p_body, ''))) < 1 THEN RAISE EXCEPTION 'EMPTY_MESSAGE'; END IF;
  INSERT INTO public.comm_replies (message_id, author_id, body)
  VALUES (p_message, auth.uid(), left(btrim(p_body), 2000))
  RETURNING id INTO v_id;
  IF private.comm_is_recipient(p_message) THEN
    PERFORM public.comm_mark_viewed(p_message);
  END IF;
  RETURN v_id;
END;
$$;

-- Class results: add each pupil's open support actions ------------------------------

CREATE OR REPLACE FUNCTION public.class_results(p_class_id UUID)
RETURNS JSONB
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_school UUID;
  v_term UUID;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  IF NOT private.is_class_teacher(p_class_id) THEN RAISE EXCEPTION 'NOT_AUTHORIZED'; END IF;
  SELECT school_id INTO v_school FROM public.classes WHERE id = p_class_id;
  v_term := private.current_term(v_school);

  RETURN jsonb_build_object(
    'class_name', (SELECT name FROM public.classes WHERE id = p_class_id),
    'term_label', (SELECT label FROM public.school_terms WHERE id = v_term),
    'subjects', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name) ORDER BY lower(s.name))
      FROM public.school_subjects s WHERE s.school_id = v_school
    ), '[]'::jsonb),
    'pupils', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'student_id', cm.user_id,
        'display_name', COALESCE(p.display_name, 'Learner'),
        'avatar_emoji', COALESCE(p.avatar_emoji, '🦊'),
        'open_support', (SELECT count(*) FROM public.pupil_support_actions a
                         WHERE a.student_id = cm.user_id AND a.status = 'open'),
        'scores', COALESCE((
          SELECT jsonb_object_agg(s.id::text, jsonb_build_object(
            'target', t.target,
            'latest', (
              SELECT r.score FROM public.pupil_results r
              WHERE r.student_id = cm.user_id AND r.subject_id = s.id
                AND r.term_id = v_term AND r.kind <> 'baseline'
              ORDER BY r.assessed_on DESC, r.created_at DESC LIMIT 1
            )
          ))
          FROM public.school_subjects s
          LEFT JOIN public.pupil_targets t
            ON t.subject_id = s.id AND t.student_id = cm.user_id AND t.term_id = v_term
          WHERE s.school_id = v_school
        ), '{}'::jsonb)
      ) ORDER BY lower(COALESCE(p.display_name, '')))
      FROM public.class_members cm
      LEFT JOIN public.user_profiles p ON p.user_id = cm.user_id
      WHERE cm.class_id = p_class_id
    ), '[]'::jsonb)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.support_actions(UUID),
  public.save_support_action(UUID, TEXT, UUID, UUID, TEXT, DATE, BOOLEAN),
  public.set_support_status(UUID, TEXT, TEXT),
  public.import_class_scores(UUID, TEXT, JSONB, TEXT, DATE, TEXT),
  public.score_batches(UUID), public.undo_score_batch(UUID),
  public.comm_post(UUID, TEXT, TEXT, TEXT, UUID, BOOLEAN), public.comm_class_messages(UUID),
  public.comm_message(UUID), public.comm_inbox(), public.comm_mark_viewed(UUID),
  public.comm_acknowledge(UUID), public.comm_reply(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.support_actions(UUID),
  public.save_support_action(UUID, TEXT, UUID, UUID, TEXT, DATE, BOOLEAN),
  public.set_support_status(UUID, TEXT, TEXT),
  public.import_class_scores(UUID, TEXT, JSONB, TEXT, DATE, TEXT),
  public.score_batches(UUID), public.undo_score_batch(UUID),
  public.comm_post(UUID, TEXT, TEXT, TEXT, UUID, BOOLEAN), public.comm_class_messages(UUID),
  public.comm_message(UUID), public.comm_inbox(), public.comm_mark_viewed(UUID),
  public.comm_acknowledge(UUID), public.comm_reply(UUID, TEXT) TO authenticated;

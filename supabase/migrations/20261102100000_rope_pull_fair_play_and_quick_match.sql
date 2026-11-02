-- Rope Pull v2: fair play, quick match with classmates, and a weekly ladder.
--
-- 1. Answer keys move out of rope_pull_rooms.questions into a private table,
--    so no player (and no Realtime payload) can read the answer early.
--    A player sees the answer for a round once they have answered it, the
--    round is over, or the match has finished.
-- 2. Other players' picks for the live round stay hidden until you answer.
-- 3. Every answer touches the room row, so Realtime on rope_pull_rooms is
--    enough to keep everyone in sync; rope_pull_answers leaves the publication.
-- 4. Quick match pairs two classmates (same school) without sharing a code
--    and starts the pull as soon as the second player arrives.
-- 5. rope_pull_ladder() ranks this week's winners in the caller's school.

------------------------------------------------------------------------------
-- Schema
------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS private.rope_pull_keys (
  room_id UUID PRIMARY KEY REFERENCES public.rope_pull_rooms(id) ON DELETE CASCADE,
  keys JSONB NOT NULL DEFAULT '[]'::jsonb
);
REVOKE ALL ON private.rope_pull_keys FROM PUBLIC, anon, authenticated;

ALTER TABLE public.rope_pull_rooms
  ADD COLUMN IF NOT EXISTS quick_match BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS max_players INTEGER NOT NULL DEFAULT 12,
  ADD COLUMN IF NOT EXISTS finished_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_rope_pull_rooms_quick
  ON public.rope_pull_rooms (bank, school_id, created_at DESC)
  WHERE quick_match AND status = 'lobby';
CREATE INDEX IF NOT EXISTS idx_rope_pull_rooms_class ON public.rope_pull_rooms (class_id);
CREATE INDEX IF NOT EXISTS idx_rope_pull_answers_user ON public.rope_pull_answers (user_id);
CREATE INDEX IF NOT EXISTS idx_rope_pull_players_user ON public.rope_pull_players (user_id);

------------------------------------------------------------------------------
-- Key helpers
------------------------------------------------------------------------------
-- Split a client deck into (public questions, private keys).
CREATE OR REPLACE FUNCTION private.rope_pull_seal(p_questions JSONB)
RETURNS TABLE (public_questions JSONB, keys JSONB)
LANGUAGE plpgsql
IMMUTABLE
SET search_path = ''
AS $$
DECLARE
  q JSONB;
  pub JSONB := '[]'::jsonb;
  k JSONB := '[]'::jsonb;
  v_answer TEXT;
  v_english TEXT;
BEGIN
  FOR q IN SELECT value FROM jsonb_array_elements(p_questions) LOOP
    IF jsonb_typeof(q->'options') <> 'array'
       OR jsonb_array_length(q->'options') < 2
       OR jsonb_array_length(q->'options') > 6 THEN
      RAISE EXCEPTION 'INVALID_QUESTIONS';
    END IF;
    v_answer := q->>'answer';
    IF v_answer IS NULL OR NOT (q->'options') ? v_answer THEN
      RAISE EXCEPTION 'INVALID_QUESTIONS';
    END IF;
    v_english := q->>'english';
    k := k || jsonb_build_array(jsonb_build_object(
      'answer', v_answer,
      'english', v_english,
      'solution', q->'solution'
    ));
    -- For vocabulary rounds the English meaning *is* the answer.
    pub := pub || jsonb_build_array(
      (q - 'answer' - 'solution')
      || CASE WHEN v_english = v_answer
              THEN jsonb_build_object('english', '')
              ELSE '{}'::jsonb END
    );
  END LOOP;
  RETURN QUERY SELECT pub, k;
END;
$$;

-- Move any existing rooms' answers into the key table.
INSERT INTO private.rope_pull_keys (room_id, keys)
SELECT r.id, s.keys
FROM public.rope_pull_rooms r
CROSS JOIN LATERAL (
  SELECT
    COALESCE(jsonb_agg(jsonb_build_object(
      'answer', q->>'answer', 'english', q->>'english', 'solution', q->'solution'
    ) ORDER BY ord), '[]'::jsonb) AS keys
  FROM jsonb_array_elements(r.questions) WITH ORDINALITY AS e(q, ord)
) s
WHERE NOT EXISTS (SELECT 1 FROM private.rope_pull_keys k WHERE k.room_id = r.id)
  AND jsonb_typeof(r.questions) = 'array';

UPDATE public.rope_pull_rooms r
SET questions = COALESCE((
  SELECT jsonb_agg(
    (q - 'answer' - 'solution')
    || CASE WHEN q->>'english' = q->>'answer'
            THEN jsonb_build_object('english', '') ELSE '{}'::jsonb END
    ORDER BY ord)
  FROM jsonb_array_elements(r.questions) WITH ORDINALITY AS e(q, ord)
), '[]'::jsonb)
WHERE EXISTS (
  SELECT 1 FROM jsonb_array_elements(r.questions) q WHERE q ? 'answer'
);

------------------------------------------------------------------------------
-- Snapshot: per-caller reveal
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.rope_pull_snapshot(p_room_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_room public.rope_pull_rooms%ROWTYPE;
  v_keys JSONB;
  v_split BOOLEAN;
  v_answered_now BOOLEAN;
  v_questions JSONB;
  v_players JSONB;
  v_answers JSONB;
BEGIN
  SELECT * INTO v_room FROM public.rope_pull_rooms WHERE id = p_room_id;
  IF v_room.id IS NULL THEN RAISE EXCEPTION 'ROOM_NOT_FOUND'; END IF;

  SELECT keys INTO v_keys FROM private.rope_pull_keys WHERE room_id = p_room_id;
  v_keys := COALESCE(v_keys, '[]'::jsonb);
  v_split := COALESCE((v_room.questions->0->>'split') = 'true', FALSE)
    AND jsonb_array_length(v_room.questions) >= 4;

  v_answered_now := EXISTS (
    SELECT 1 FROM public.rope_pull_answers
    WHERE room_id = p_room_id AND user_id = v_uid AND round_index = v_room.current_round
  );

  SELECT COALESCE(jsonb_agg(
    CASE
      WHEN v_room.status = 'finished'
        OR (CASE WHEN v_split THEN (ord - 1) / 2 ELSE ord - 1 END) < v_room.current_round
        OR ((CASE WHEN v_split THEN (ord - 1) / 2 ELSE ord - 1 END) = v_room.current_round
            AND v_answered_now)
      THEN q
        || jsonb_build_object('answer', v_keys->(ord::int - 1)->>'answer')
        || CASE WHEN COALESCE(q->>'english', '') = ''
                THEN jsonb_build_object('english', v_keys->(ord::int - 1)->>'english')
                ELSE '{}'::jsonb END
        || CASE WHEN v_keys->(ord::int - 1)->'solution' IS NOT NULL
                 AND jsonb_typeof(v_keys->(ord::int - 1)->'solution') = 'string'
                THEN jsonb_build_object('solution', v_keys->(ord::int - 1)->'solution')
                ELSE '{}'::jsonb END
      ELSE q
    END ORDER BY ord), '[]'::jsonb)
  INTO v_questions
  FROM jsonb_array_elements(v_room.questions) WITH ORDINALITY AS e(q, ord);

  SELECT COALESCE(jsonb_agg(to_jsonb(p) ORDER BY p.joined_at), '[]'::jsonb)
  INTO v_players
  FROM public.rope_pull_players p WHERE p.room_id = p_room_id;

  -- Live round: others' picks stay hidden until you have answered.
  SELECT COALESCE(jsonb_agg(
    CASE
      WHEN v_room.status = 'playing'
        AND a.round_index = v_room.current_round
        AND a.user_id <> v_uid
        AND NOT v_answered_now
      THEN jsonb_build_object(
        'room_id', a.room_id, 'round_index', a.round_index, 'user_id', a.user_id,
        'selected', NULL, 'is_correct', FALSE, 'answered_at', a.answered_at,
        'hidden', TRUE
      )
      ELSE to_jsonb(a)
    END ORDER BY a.answered_at), '[]'::jsonb)
  INTO v_answers
  FROM public.rope_pull_answers a WHERE a.room_id = p_room_id;

  RETURN jsonb_build_object(
    'room', to_jsonb(v_room) || jsonb_build_object('questions', v_questions),
    'players', v_players,
    'answers', v_answers,
    'server_now', now()
  );
END;
$$;

------------------------------------------------------------------------------
-- Create: seal the deck
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.create_rope_pull_room(
  p_user_id UUID, p_bank TEXT, p_questions JSONB, p_host_plays BOOLEAN,
  p_display_name TEXT, p_avatar TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_room_id UUID;
  v_uid UUID := auth.uid();
  v_public JSONB;
  v_keys JSONB;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  IF p_bank NOT IN ('lessons_1_5', 'module_1', 'daily_review', 'past_questions', 'maths') THEN
    RAISE EXCEPTION 'INVALID_BANK';
  END IF;
  IF jsonb_typeof(p_questions) <> 'array'
     OR jsonb_array_length(p_questions) < 4
     OR jsonb_array_length(p_questions) > 40 THEN
    RAISE EXCEPTION 'INVALID_QUESTIONS';
  END IF;

  SELECT s.public_questions, s.keys INTO v_public, v_keys
  FROM private.rope_pull_seal(p_questions) s;

  INSERT INTO public.rope_pull_rooms (host_id, join_code, bank, questions)
  VALUES (v_uid, private.rope_pull_new_code(), p_bank, v_public)
  RETURNING id INTO v_room_id;

  INSERT INTO private.rope_pull_keys (room_id, keys) VALUES (v_room_id, v_keys);

  IF COALESCE(p_host_plays, TRUE) THEN
    INSERT INTO public.rope_pull_players (room_id, user_id, display_name, avatar, team)
    VALUES (
      v_room_id, v_uid,
      left(COALESCE(NULLIF(trim(p_display_name), ''), 'Host'), 40),
      left(COALESCE(NULLIF(trim(p_avatar), ''), '🦊'), 8),
      'blue'
    );
  END IF;

  RETURN private.rope_pull_snapshot(v_room_id);
END;
$$;

------------------------------------------------------------------------------
-- Join: respect room size; quick matches start on the second player
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.join_rope_pull_room(
  p_user_id UUID, p_code TEXT, p_display_name TEXT, p_avatar TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_room public.rope_pull_rooms%ROWTYPE;
  v_blue INTEGER;
  v_red INTEGER;
  v_team TEXT;
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;

  SELECT * INTO v_room FROM public.rope_pull_rooms
  WHERE join_code = upper(trim(p_code)) FOR UPDATE;
  IF v_room.id IS NULL THEN RAISE EXCEPTION 'INVALID_CODE'; END IF;
  IF v_room.status = 'finished' THEN RAISE EXCEPTION 'ROOM_FINISHED'; END IF;

  IF EXISTS (
    SELECT 1 FROM public.rope_pull_players WHERE room_id = v_room.id AND user_id = v_uid
  ) THEN
    RETURN private.rope_pull_snapshot(v_room.id);
  END IF;

  SELECT count(*) FILTER (WHERE team = 'blue'), count(*) FILTER (WHERE team = 'red')
  INTO v_blue, v_red
  FROM public.rope_pull_players WHERE room_id = v_room.id;

  IF v_blue + v_red >= v_room.max_players THEN RAISE EXCEPTION 'ROOM_FULL'; END IF;

  v_team := CASE WHEN v_blue <= v_red THEN 'blue' ELSE 'red' END;

  INSERT INTO public.rope_pull_players (room_id, user_id, display_name, avatar, team)
  VALUES (
    v_room.id, v_uid,
    left(COALESCE(NULLIF(trim(p_display_name), ''), 'Learner'), 40),
    left(COALESCE(NULLIF(trim(p_avatar), ''), '🦊'), 8),
    v_team
  );

  IF v_room.quick_match AND v_room.status = 'lobby' AND v_blue + v_red + 1 >= 2 THEN
    -- Three-second countdown before round one.
    UPDATE public.rope_pull_rooms
    SET status = 'playing', current_round = 0,
        round_started_at = now() + interval '3 seconds',
        rope_score = 0, updated_at = now()
    WHERE id = v_room.id;
  ELSE
    UPDATE public.rope_pull_rooms SET updated_at = now() WHERE id = v_room.id;
  END IF;

  RETURN private.rope_pull_snapshot(v_room.id);
END;
$$;

------------------------------------------------------------------------------
-- Submit: keys come from the private table; every answer pings the room
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.submit_rope_pull_answer(
  p_user_id UUID, p_room_id UUID, p_round INTEGER, p_selected TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_room public.rope_pull_rooms%ROWTYPE;
  v_team TEXT;
  v_answer TEXT;
  v_correct BOOLEAN;
  v_inserted INTEGER;
  v_team_correct INTEGER;
  v_index INTEGER;
  v_cap INTEGER;
  v_split BOOLEAN;
  v_uid UUID := auth.uid();
BEGIN
  SELECT * INTO v_room FROM public.rope_pull_rooms WHERE id = p_room_id FOR UPDATE;
  IF v_room.id IS NULL THEN RAISE EXCEPTION 'ROOM_NOT_FOUND'; END IF;
  IF v_room.status <> 'playing' THEN RAISE EXCEPTION 'NOT_PLAYING'; END IF;
  IF p_round <> v_room.current_round THEN RETURN private.rope_pull_snapshot(p_room_id); END IF;

  SELECT team INTO v_team FROM public.rope_pull_players
  WHERE room_id = p_room_id AND user_id = v_uid;
  IF v_team IS NULL THEN RAISE EXCEPTION 'NOT_A_PLAYER'; END IF;

  v_split := COALESCE((v_room.questions->0->>'split') = 'true', FALSE)
    AND jsonb_array_length(v_room.questions) >= 4;
  v_index := CASE
    WHEN v_split THEN p_round * 2 + CASE WHEN v_team = 'red' THEN 1 ELSE 0 END
    ELSE p_round
  END;
  SELECT keys->v_index->>'answer' INTO v_answer
  FROM private.rope_pull_keys WHERE room_id = p_room_id;
  v_correct := lower(trim(COALESCE(p_selected, ''))) = lower(trim(COALESCE(v_answer, '')))
    AND v_answer IS NOT NULL;
  v_cap := CASE
    WHEN v_split THEN GREATEST(10, LEAST(20, jsonb_array_length(v_room.questions) / 2))
    WHEN jsonb_array_length(v_room.questions) > 10 THEN LEAST(40, jsonb_array_length(v_room.questions))
    ELSE 10
  END;

  INSERT INTO public.rope_pull_answers (room_id, round_index, user_id, selected, is_correct)
  VALUES (p_room_id, p_round, v_uid, left(trim(p_selected), 240), v_correct)
  ON CONFLICT (room_id, round_index, user_id) DO NOTHING;
  GET DIAGNOSTICS v_inserted = ROW_COUNT;

  IF v_inserted > 0 AND v_correct THEN
    SELECT count(*) INTO v_team_correct
    FROM public.rope_pull_answers a
    JOIN public.rope_pull_players p ON p.room_id = a.room_id AND p.user_id = a.user_id
    WHERE a.room_id = p_room_id AND a.round_index = p_round AND a.is_correct AND p.team = v_team;
    IF v_team_correct = 1 THEN
      UPDATE public.rope_pull_rooms
      SET rope_score = GREATEST(-v_cap, LEAST(v_cap,
            rope_score + CASE WHEN v_team = 'red' THEN 1 ELSE -1 END)),
          updated_at = now()
      WHERE id = p_room_id;
    ELSE
      UPDATE public.rope_pull_rooms SET updated_at = now() WHERE id = p_room_id;
    END IF;
  ELSIF v_inserted > 0 THEN
    UPDATE public.rope_pull_rooms SET updated_at = now() WHERE id = p_room_id;
  END IF;

  RETURN private.rope_pull_snapshot(p_room_id);
END;
$$;

-- Advance respects the countdown and stamps finished_at.
CREATE OR REPLACE FUNCTION private.advance_rope_pull_round(p_user_id UUID, p_room_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_room public.rope_pull_rooms%ROWTYPE;
  v_elapsed DOUBLE PRECISION;
  v_all_answered BOOLEAN;
  v_rounds INTEGER;
  v_split BOOLEAN;
  v_limit INTEGER;
BEGIN
  SELECT * INTO v_room FROM public.rope_pull_rooms WHERE id = p_room_id FOR UPDATE;
  IF v_room.id IS NULL THEN RAISE EXCEPTION 'ROOM_NOT_FOUND'; END IF;
  IF v_room.status <> 'playing' THEN RETURN private.rope_pull_snapshot(p_room_id); END IF;
  IF NOT private.is_rope_pull_member(p_room_id) THEN RAISE EXCEPTION 'NOT_AUTHORIZED'; END IF;

  v_elapsed := EXTRACT(EPOCH FROM (now() - COALESCE(v_room.round_started_at, now())));
  SELECT NOT EXISTS (
    SELECT 1 FROM public.rope_pull_players p
    WHERE p.room_id = p_room_id
      AND NOT EXISTS (
        SELECT 1 FROM public.rope_pull_answers a
        WHERE a.room_id = p.room_id AND a.user_id = p.user_id
          AND a.round_index = v_room.current_round
      )
  ) INTO v_all_answered;

  v_limit := CASE
    WHEN v_room.bank = 'maths' OR v_room.questions->0->>'kind' = 'maths' THEN 15
    WHEN v_room.bank = 'past_questions' OR v_room.questions->0->>'kind' = 'exam' THEN 25
    ELSE 10
  END;

  -- Any player may advance once everyone has answered or time is up.
  IF NOT (v_elapsed >= v_limit OR (v_all_answered AND v_elapsed >= 1)) THEN
    RETURN private.rope_pull_snapshot(p_room_id);
  END IF;

  v_split := COALESCE((v_room.questions->0->>'split') = 'true', FALSE)
    AND jsonb_array_length(v_room.questions) >= 4;
  v_rounds := CASE WHEN v_split THEN jsonb_array_length(v_room.questions) / 2
                   ELSE jsonb_array_length(v_room.questions) END;

  IF v_room.current_round >= v_rounds - 1 THEN
    UPDATE public.rope_pull_rooms
    SET status = 'finished', finished_at = now(), updated_at = now()
    WHERE id = p_room_id;
  ELSE
    UPDATE public.rope_pull_rooms
    SET current_round = current_round + 1, round_started_at = now(), updated_at = now()
    WHERE id = p_room_id;
  END IF;

  RETURN private.rope_pull_snapshot(p_room_id);
END;
$$;

CREATE OR REPLACE FUNCTION private.rope_pull_finish_on_threshold()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, private
AS $$
BEGIN
  IF NEW.status = 'playing'
     AND abs(NEW.rope_score) >= 10
     AND COALESCE((NEW.questions->0->>'split') = 'true', FALSE) = FALSE
     AND jsonb_array_length(NEW.questions) <= 10 THEN
    NEW.status := 'finished';
  END IF;
  IF NEW.status = 'finished' AND NEW.finished_at IS NULL THEN
    NEW.finished_at := now();
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

------------------------------------------------------------------------------
-- Quick match with a classmate
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rope_pull_quick_match(
  p_bank TEXT,
  p_questions JSONB,
  p_display_name TEXT DEFAULT 'Learner',
  p_avatar TEXT DEFAULT '🦊'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_school UUID;
  v_room public.rope_pull_rooms%ROWTYPE;
  v_snap JSONB;
  v_room_id UUID;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;

  SELECT school_id INTO v_school FROM private.caller_school(v_uid, NULL);
  IF v_school IS NULL THEN RAISE EXCEPTION 'NEEDS_SCHOOL'; END IF;

  -- Already waiting in a quick room? Go back to it.
  SELECT r.* INTO v_room FROM public.rope_pull_rooms r
  JOIN public.rope_pull_players p ON p.room_id = r.id AND p.user_id = v_uid
  WHERE r.quick_match AND r.status IN ('lobby', 'playing')
    AND r.created_at > now() - interval '10 minutes'
  ORDER BY r.created_at DESC LIMIT 1;
  IF v_room.id IS NOT NULL THEN RETURN private.rope_pull_snapshot(v_room.id); END IF;

  -- Join the oldest waiting classmate for the same game.
  SELECT r.* INTO v_room FROM public.rope_pull_rooms r
  WHERE r.quick_match AND r.status = 'lobby' AND r.bank = p_bank
    AND r.school_id = v_school AND r.host_id <> v_uid
    AND r.created_at > now() - interval '3 minutes'
    AND (SELECT count(*) FROM public.rope_pull_players rp WHERE rp.room_id = r.id) < r.max_players
  ORDER BY r.created_at
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF v_room.id IS NOT NULL THEN
    RETURN private.join_rope_pull_room(v_uid, v_room.join_code, p_display_name, p_avatar);
  END IF;

  -- Nobody waiting: open a room others can drop into.
  v_snap := public.create_rope_pull_room(p_bank, p_questions, TRUE, p_display_name, p_avatar, NULL, NULL);
  v_room_id := (v_snap->'room'->>'id')::uuid;
  UPDATE public.rope_pull_rooms SET quick_match = TRUE, max_players = 2 WHERE id = v_room_id;
  RETURN private.rope_pull_snapshot(v_room_id);
END;
$$;

------------------------------------------------------------------------------
-- Weekly ladder for the caller's school
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rope_pull_ladder(p_days INTEGER DEFAULT 7)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_school UUID;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  SELECT school_id INTO v_school FROM private.caller_school(v_uid, NULL);
  IF v_school IS NULL THEN RETURN '[]'::jsonb; END IF;

  RETURN COALESCE((
    SELECT jsonb_agg(row ORDER BY (row->>'wins')::int DESC, (row->>'correct')::int DESC)
    FROM (
      SELECT jsonb_build_object(
        'user_id', p.user_id,
        'display_name', max(p.display_name),
        'avatar', max(p.avatar),
        'matches', count(DISTINCT r.id),
        'wins', count(DISTINCT r.id) FILTER (
          WHERE (r.rope_score > 0 AND p.team = 'red') OR (r.rope_score < 0 AND p.team = 'blue')
        ),
        'correct', (
          SELECT count(*) FROM public.rope_pull_answers a
          JOIN public.rope_pull_rooms ar ON ar.id = a.room_id
          WHERE a.user_id = p.user_id AND a.is_correct
            AND ar.school_id = v_school
            AND ar.created_at > now() - make_interval(days => GREATEST(1, LEAST(p_days, 60)))
        ),
        'is_you', p.user_id = v_uid
      ) AS row
      FROM public.rope_pull_players p
      JOIN public.rope_pull_rooms r ON r.id = p.room_id
      WHERE r.school_id = v_school
        AND r.status = 'finished'
        AND r.created_at > now() - make_interval(days => GREATEST(1, LEAST(p_days, 60)))
      GROUP BY p.user_id
      LIMIT 50
    ) ranked
  ), '[]'::jsonb);
END;
$$;

------------------------------------------------------------------------------
-- Realtime: rooms + players only (answers would leak picks mid-round)
------------------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'rope_pull_answers'
  ) THEN
    ALTER PUBLICATION supabase_realtime DROP TABLE public.rope_pull_answers;
  END IF;
END $$;

------------------------------------------------------------------------------
-- Grants
------------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.rope_pull_quick_match(TEXT, JSONB, TEXT, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rope_pull_ladder(INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rope_pull_quick_match(TEXT, JSONB, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rope_pull_ladder(INTEGER) TO authenticated;
REVOKE ALL ON FUNCTION private.rope_pull_seal(JSONB) FROM PUBLIC, anon, authenticated;

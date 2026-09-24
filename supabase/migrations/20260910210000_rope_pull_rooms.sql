-- Friends Rope Pull: 4-letter rooms, two teams, synced listen-and-tap rounds.

CREATE TABLE IF NOT EXISTS public.rope_pull_rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  host_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  join_code TEXT NOT NULL UNIQUE,
  bank TEXT NOT NULL CHECK (bank IN ('lessons_1_5', 'module_1', 'daily_review')),
  status TEXT NOT NULL DEFAULT 'lobby'
    CHECK (status IN ('lobby', 'playing', 'finished')),
  current_round INTEGER NOT NULL DEFAULT 0,
  round_started_at TIMESTAMPTZ,
  rope_score INTEGER NOT NULL DEFAULT 0,
  questions JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.rope_pull_players (
  room_id UUID NOT NULL REFERENCES public.rope_pull_rooms(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL DEFAULT 'Learner',
  avatar TEXT NOT NULL DEFAULT '🦊',
  team TEXT NOT NULL CHECK (team IN ('blue', 'red')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (room_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.rope_pull_answers (
  room_id UUID NOT NULL REFERENCES public.rope_pull_rooms(id) ON DELETE CASCADE,
  round_index INTEGER NOT NULL,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  selected TEXT NOT NULL,
  is_correct BOOLEAN NOT NULL,
  answered_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (room_id, round_index, user_id)
);

CREATE INDEX IF NOT EXISTS idx_rope_pull_rooms_code ON public.rope_pull_rooms(join_code);
CREATE INDEX IF NOT EXISTS idx_rope_pull_rooms_host ON public.rope_pull_rooms(host_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_rope_pull_players_user ON public.rope_pull_players(user_id);
CREATE INDEX IF NOT EXISTS idx_rope_pull_answers_room ON public.rope_pull_answers(room_id, round_index);

ALTER TABLE public.rope_pull_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rope_pull_players ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rope_pull_answers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rope_pull_rooms REPLICA IDENTITY FULL;
ALTER TABLE public.rope_pull_players REPLICA IDENTITY FULL;
ALTER TABLE public.rope_pull_answers REPLICA IDENTITY FULL;

GRANT SELECT ON public.rope_pull_rooms TO authenticated;
GRANT SELECT ON public.rope_pull_players TO authenticated;
GRANT SELECT ON public.rope_pull_answers TO authenticated;

CREATE OR REPLACE FUNCTION private.is_rope_pull_member(p_room_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, private
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.rope_pull_rooms
    WHERE id = p_room_id AND host_id = auth.uid()
  ) OR EXISTS (
    SELECT 1 FROM public.rope_pull_players
    WHERE room_id = p_room_id AND user_id = auth.uid()
  );
$$;

REVOKE ALL ON FUNCTION private.is_rope_pull_member(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.is_rope_pull_member(UUID) TO authenticated;

DROP POLICY IF EXISTS "Members read rope pull rooms" ON public.rope_pull_rooms;
CREATE POLICY "Members read rope pull rooms"
  ON public.rope_pull_rooms FOR SELECT TO authenticated
  USING (private.is_rope_pull_member(id));

DROP POLICY IF EXISTS "Members read rope pull players" ON public.rope_pull_players;
CREATE POLICY "Members read rope pull players"
  ON public.rope_pull_players FOR SELECT TO authenticated
  USING (private.is_rope_pull_member(room_id));

DROP POLICY IF EXISTS "Members read rope pull answers" ON public.rope_pull_answers;
CREATE POLICY "Members read rope pull answers"
  ON public.rope_pull_answers FOR SELECT TO authenticated
  USING (private.is_rope_pull_member(room_id));

CREATE OR REPLACE FUNCTION private.rope_pull_new_code()
RETURNS TEXT
LANGUAGE plpgsql
SET search_path = public, private
AS $$
DECLARE
  v_chars TEXT := 'ACEFGHJKLMNPQRTUVWXY';
  v_code TEXT;
  v_exists BOOLEAN;
BEGIN
  LOOP
    v_code := '';
    FOR i IN 1..4 LOOP
      v_code := v_code || substr(v_chars, 1 + floor(random() * length(v_chars))::int, 1);
    END LOOP;
    SELECT EXISTS(SELECT 1 FROM public.rope_pull_rooms WHERE join_code = v_code)
      INTO v_exists;
    EXIT WHEN NOT v_exists;
  END LOOP;
  RETURN v_code;
END;
$$;

CREATE OR REPLACE FUNCTION private.rope_pull_snapshot(p_room_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_room JSONB;
  v_players JSONB;
  v_answers JSONB;
BEGIN
  SELECT to_jsonb(r) INTO v_room
  FROM public.rope_pull_rooms r
  WHERE r.id = p_room_id;
  IF v_room IS NULL THEN
    RAISE EXCEPTION 'ROOM_NOT_FOUND';
  END IF;

  SELECT COALESCE(jsonb_agg(to_jsonb(p) ORDER BY p.joined_at), '[]'::jsonb)
    INTO v_players
  FROM public.rope_pull_players p
  WHERE p.room_id = p_room_id;

  SELECT COALESCE(jsonb_agg(to_jsonb(a) ORDER BY a.answered_at), '[]'::jsonb)
    INTO v_answers
  FROM public.rope_pull_answers a
  WHERE a.room_id = p_room_id;

  RETURN jsonb_build_object(
    'room', v_room,
    'players', v_players,
    'answers', v_answers
  );
END;
$$;

CREATE OR REPLACE FUNCTION private.create_rope_pull_room(
  p_user_id UUID,
  p_bank TEXT,
  p_questions JSONB,
  p_host_plays BOOLEAN,
  p_display_name TEXT,
  p_avatar TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_room_id UUID;
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;
  IF p_bank NOT IN ('lessons_1_5', 'module_1', 'daily_review') THEN
    RAISE EXCEPTION 'INVALID_BANK';
  END IF;
  IF jsonb_typeof(p_questions) <> 'array'
     OR jsonb_array_length(p_questions) < 4
     OR jsonb_array_length(p_questions) > 10 THEN
    RAISE EXCEPTION 'INVALID_QUESTIONS';
  END IF;

  INSERT INTO public.rope_pull_rooms (host_id, join_code, bank, questions)
  VALUES (v_uid, private.rope_pull_new_code(), p_bank, p_questions)
  RETURNING id INTO v_room_id;

  IF COALESCE(p_host_plays, TRUE) THEN
    INSERT INTO public.rope_pull_players (
      room_id, user_id, display_name, avatar, team
    ) VALUES (
      v_room_id,
      v_uid,
      COALESCE(NULLIF(trim(p_display_name), ''), 'Host'),
      COALESCE(NULLIF(trim(p_avatar), ''), '🦊'),
      'blue'
    );
  END IF;

  RETURN private.rope_pull_snapshot(v_room_id);
END;
$$;

CREATE OR REPLACE FUNCTION private.join_rope_pull_room(
  p_user_id UUID,
  p_code TEXT,
  p_display_name TEXT,
  p_avatar TEXT
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
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  SELECT * INTO v_room
  FROM public.rope_pull_rooms
  WHERE join_code = upper(trim(p_code));
  IF v_room.id IS NULL THEN
    RAISE EXCEPTION 'INVALID_CODE';
  END IF;
  IF v_room.status = 'finished' THEN
    RAISE EXCEPTION 'ROOM_FINISHED';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.rope_pull_players
    WHERE room_id = v_room.id AND user_id = v_uid
  ) THEN
    RETURN private.rope_pull_snapshot(v_room.id);
  END IF;

  SELECT
    COUNT(*) FILTER (WHERE team = 'blue'),
    COUNT(*) FILTER (WHERE team = 'red')
  INTO v_blue, v_red
  FROM public.rope_pull_players
  WHERE room_id = v_room.id;

  v_team := CASE WHEN v_blue <= v_red THEN 'blue' ELSE 'red' END;

  INSERT INTO public.rope_pull_players (
    room_id, user_id, display_name, avatar, team
  ) VALUES (
    v_room.id,
    v_uid,
    COALESCE(NULLIF(trim(p_display_name), ''), 'Learner'),
    COALESCE(NULLIF(trim(p_avatar), ''), '🦊'),
    v_team
  );

  RETURN private.rope_pull_snapshot(v_room.id);
END;
$$;

CREATE OR REPLACE FUNCTION private.start_rope_pull_room(
  p_user_id UUID,
  p_room_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_host UUID;
  v_status TEXT;
  v_players INTEGER;
  v_uid UUID := auth.uid();
BEGIN
  SELECT host_id, status INTO v_host, v_status
  FROM public.rope_pull_rooms WHERE id = p_room_id;
  IF v_host IS NULL THEN
    RAISE EXCEPTION 'ROOM_NOT_FOUND';
  END IF;
  IF v_host <> v_uid THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;
  IF v_status <> 'lobby' THEN
    RETURN private.rope_pull_snapshot(p_room_id);
  END IF;

  SELECT COUNT(*) INTO v_players
  FROM public.rope_pull_players WHERE room_id = p_room_id;
  IF v_players < 2 THEN
    RAISE EXCEPTION 'NEED_TWO_PLAYERS';
  END IF;

  UPDATE public.rope_pull_rooms
  SET
    status = 'playing',
    current_round = 0,
    round_started_at = now(),
    rope_score = 0,
    updated_at = now()
  WHERE id = p_room_id;

  RETURN private.rope_pull_snapshot(p_room_id);
END;
$$;

CREATE OR REPLACE FUNCTION private.submit_rope_pull_answer(
  p_user_id UUID,
  p_room_id UUID,
  p_round INTEGER,
  p_selected TEXT
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
  v_uid UUID := auth.uid();
BEGIN
  SELECT * INTO v_room FROM public.rope_pull_rooms WHERE id = p_room_id;
  IF v_room.id IS NULL THEN
    RAISE EXCEPTION 'ROOM_NOT_FOUND';
  END IF;
  IF v_room.status <> 'playing' THEN
    RAISE EXCEPTION 'NOT_PLAYING';
  END IF;
  IF p_round <> v_room.current_round THEN
    RETURN private.rope_pull_snapshot(p_room_id);
  END IF;

  SELECT team INTO v_team
  FROM public.rope_pull_players
  WHERE room_id = p_room_id AND user_id = v_uid;
  IF v_team IS NULL THEN
    RAISE EXCEPTION 'NOT_A_PLAYER';
  END IF;

  v_answer := v_room.questions -> p_round ->> 'answer';
  v_correct := lower(trim(COALESCE(p_selected, ''))) = lower(trim(COALESCE(v_answer, '')));

  INSERT INTO public.rope_pull_answers (
    room_id, round_index, user_id, selected, is_correct
  ) VALUES (
    p_room_id, p_round, v_uid, left(trim(p_selected), 80), v_correct
  )
  ON CONFLICT (room_id, round_index, user_id) DO NOTHING;
  GET DIAGNOSTICS v_inserted = ROW_COUNT;

  IF v_inserted > 0 AND v_correct THEN
    SELECT COUNT(*) INTO v_team_correct
    FROM public.rope_pull_answers a
    JOIN public.rope_pull_players p
      ON p.room_id = a.room_id AND p.user_id = a.user_id
    WHERE a.room_id = p_room_id
      AND a.round_index = p_round
      AND a.is_correct
      AND p.team = v_team;
    IF v_team_correct = 1 THEN
      UPDATE public.rope_pull_rooms
      SET
        rope_score = GREATEST(-10, LEAST(10,
          rope_score + CASE WHEN v_team = 'red' THEN 1 ELSE -1 END
        )),
        updated_at = now()
      WHERE id = p_room_id;
    END IF;
  END IF;

  RETURN private.rope_pull_snapshot(p_room_id);
END;
$$;

CREATE OR REPLACE FUNCTION private.advance_rope_pull_round(
  p_user_id UUID,
  p_room_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_room public.rope_pull_rooms%ROWTYPE;
  v_elapsed DOUBLE PRECISION;
  v_all_answered BOOLEAN;
  v_host BOOLEAN;
  v_rounds INTEGER;
  v_uid UUID := auth.uid();
BEGIN
  SELECT * INTO v_room FROM public.rope_pull_rooms WHERE id = p_room_id;
  IF v_room.id IS NULL THEN
    RAISE EXCEPTION 'ROOM_NOT_FOUND';
  END IF;
  IF v_room.status <> 'playing' THEN
    RETURN private.rope_pull_snapshot(p_room_id);
  END IF;
  IF NOT private.is_rope_pull_member(p_room_id) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  v_host := v_room.host_id = v_uid;
  v_elapsed := EXTRACT(EPOCH FROM (now() - COALESCE(v_room.round_started_at, now())));
  SELECT NOT EXISTS (
    SELECT 1 FROM public.rope_pull_players p
    WHERE p.room_id = p_room_id
      AND NOT EXISTS (
        SELECT 1 FROM public.rope_pull_answers a
        WHERE a.room_id = p.room_id
          AND a.user_id = p.user_id
          AND a.round_index = v_room.current_round
      )
  ) INTO v_all_answered;

  IF NOT (
    v_elapsed >= 10
    OR (v_host AND (v_all_answered OR v_elapsed >= 10))
  ) THEN
    RETURN private.rope_pull_snapshot(p_room_id);
  END IF;

  v_rounds := jsonb_array_length(v_room.questions);
  IF v_room.current_round >= v_rounds - 1 THEN
    UPDATE public.rope_pull_rooms
    SET status = 'finished', updated_at = now()
    WHERE id = p_room_id;
  ELSE
    UPDATE public.rope_pull_rooms
    SET
      current_round = current_round + 1,
      round_started_at = now(),
      updated_at = now()
    WHERE id = p_room_id;
  END IF;

  RETURN private.rope_pull_snapshot(p_room_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.create_rope_pull_room(
  p_bank TEXT,
  p_questions JSONB,
  p_host_plays BOOLEAN DEFAULT TRUE,
  p_display_name TEXT DEFAULT 'Host',
  p_avatar TEXT DEFAULT '🦊'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
BEGIN
  RETURN private.create_rope_pull_room(
    auth.uid(), p_bank, p_questions, p_host_plays, p_display_name, p_avatar
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.join_rope_pull_room(
  p_code TEXT,
  p_display_name TEXT DEFAULT 'Learner',
  p_avatar TEXT DEFAULT '🦊'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
BEGIN
  RETURN private.join_rope_pull_room(
    auth.uid(), p_code, p_display_name, p_avatar
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.start_rope_pull_room(p_room_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
BEGIN
  RETURN private.start_rope_pull_room(auth.uid(), p_room_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_rope_pull_answer(
  p_room_id UUID,
  p_round INTEGER,
  p_selected TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
BEGIN
  RETURN private.submit_rope_pull_answer(
    auth.uid(), p_room_id, p_round, p_selected
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.advance_rope_pull_round(p_room_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
BEGIN
  RETURN private.advance_rope_pull_round(auth.uid(), p_room_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.fetch_rope_pull_room(p_room_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
BEGIN
  IF NOT private.is_rope_pull_member(p_room_id) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;
  RETURN private.rope_pull_snapshot(p_room_id);
END;
$$;

REVOKE ALL ON FUNCTION private.rope_pull_snapshot(UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.create_rope_pull_room(UUID, TEXT, JSONB, BOOLEAN, TEXT, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.join_rope_pull_room(UUID, TEXT, TEXT, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.start_rope_pull_room(UUID, UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.submit_rope_pull_answer(UUID, UUID, INTEGER, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.advance_rope_pull_round(UUID, UUID) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.create_rope_pull_room(TEXT, JSONB, BOOLEAN, TEXT, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.join_rope_pull_room(TEXT, TEXT, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.start_rope_pull_room(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.submit_rope_pull_answer(UUID, INTEGER, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.advance_rope_pull_round(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fetch_rope_pull_room(UUID) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.create_rope_pull_room(TEXT, JSONB, BOOLEAN, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_rope_pull_room(TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.start_rope_pull_room(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_rope_pull_answer(UUID, INTEGER, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.advance_rope_pull_round(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fetch_rope_pull_room(UUID) TO authenticated;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.rope_pull_rooms;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.rope_pull_players;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.rope_pull_answers;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

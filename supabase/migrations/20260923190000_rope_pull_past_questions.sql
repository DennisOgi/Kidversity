-- Longer decks, exam and maths banks, and a split round for class boards.
-- Each team answers its own question. Short Mandarin matches still end at 10 tugs.

ALTER TABLE public.rope_pull_rooms
  DROP CONSTRAINT IF EXISTS rope_pull_rooms_bank_check;

ALTER TABLE public.rope_pull_rooms
  ADD CONSTRAINT rope_pull_rooms_bank_check
  CHECK (bank IN (
    'lessons_1_5', 'module_1', 'daily_review', 'past_questions', 'maths'
  ));

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
  IF p_bank NOT IN (
    'lessons_1_5', 'module_1', 'daily_review', 'past_questions', 'maths'
  ) THEN
    RAISE EXCEPTION 'INVALID_BANK';
  END IF;
  IF jsonb_typeof(p_questions) <> 'array'
     OR jsonb_array_length(p_questions) < 4
     OR jsonb_array_length(p_questions) > 40 THEN
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
  v_index INTEGER;
  v_cap INTEGER;
  v_split BOOLEAN;
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

  v_split := COALESCE((v_room.questions->0->>'split') = 'true', false)
    AND jsonb_array_length(v_room.questions) >= 4;
  v_index := CASE
    WHEN v_split THEN p_round * 2 + CASE WHEN v_team = 'red' THEN 1 ELSE 0 END
    ELSE p_round
  END;
  v_answer := v_room.questions -> v_index ->> 'answer';
  v_correct := lower(trim(COALESCE(p_selected, ''))) = lower(trim(COALESCE(v_answer, '')));
  v_cap := CASE
    WHEN v_split THEN GREATEST(10, LEAST(20, jsonb_array_length(v_room.questions) / 2))
    WHEN jsonb_array_length(v_room.questions) > 10
      THEN LEAST(40, jsonb_array_length(v_room.questions))
    ELSE 10
  END;

  INSERT INTO public.rope_pull_answers (
    room_id, round_index, user_id, selected, is_correct
  ) VALUES (
    p_room_id, p_round, v_uid, left(trim(p_selected), 240), v_correct
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
        rope_score = GREATEST(-v_cap, LEAST(v_cap,
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
  v_split BOOLEAN;
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
    OR (v_host AND v_all_answered)
  ) THEN
    RETURN private.rope_pull_snapshot(p_room_id);
  END IF;

  v_split := COALESCE((v_room.questions->0->>'split') = 'true', false)
    AND jsonb_array_length(v_room.questions) >= 4;
  v_rounds := CASE
    WHEN v_split THEN jsonb_array_length(v_room.questions) / 2
    ELSE jsonb_array_length(v_room.questions)
  END;
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

CREATE OR REPLACE FUNCTION private.rope_pull_finish_on_threshold()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, private
AS $$
BEGIN
  IF NEW.status = 'playing'
     AND abs(NEW.rope_score) >= 10
     AND COALESCE((NEW.questions->0->>'split') = 'true', false) = false
     AND jsonb_array_length(NEW.questions) <= 10 THEN
    NEW.status := 'finished';
    NEW.updated_at := now();
  END IF;
  RETURN NEW;
END;
$$;

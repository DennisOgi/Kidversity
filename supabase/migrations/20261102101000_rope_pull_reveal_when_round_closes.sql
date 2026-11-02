-- Reveal the live round's answer to everyone (including a projecting teacher)
-- once every player has answered or the timer has run out.
CREATE OR REPLACE FUNCTION private.rope_pull_round_limit(p_room public.rope_pull_rooms)
RETURNS INTEGER
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
  SELECT CASE
    WHEN p_room.bank = 'maths' OR p_room.questions->0->>'kind' = 'maths' THEN 15
    WHEN p_room.bank = 'past_questions' OR p_room.questions->0->>'kind' = 'exam' THEN 25
    ELSE 10
  END;
$$;

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
  v_round_closed BOOLEAN;
  v_reveal_now BOOLEAN;
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
  v_round_closed := v_room.status = 'playing' AND (
    (v_room.round_started_at IS NOT NULL
      AND EXTRACT(EPOCH FROM (now() - v_room.round_started_at))
          >= private.rope_pull_round_limit(v_room))
    OR NOT EXISTS (
      SELECT 1 FROM public.rope_pull_players p
      WHERE p.room_id = p_room_id
        AND NOT EXISTS (
          SELECT 1 FROM public.rope_pull_answers a
          WHERE a.room_id = p_room_id AND a.user_id = p.user_id
            AND a.round_index = v_room.current_round
        )
    )
  );
  v_reveal_now := v_answered_now OR v_round_closed;

  SELECT COALESCE(jsonb_agg(
    CASE
      WHEN v_room.status = 'finished'
        OR (CASE WHEN v_split THEN (ord - 1) / 2 ELSE ord - 1 END) < v_room.current_round
        OR ((CASE WHEN v_split THEN (ord - 1) / 2 ELSE ord - 1 END) = v_room.current_round
            AND v_reveal_now)
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

  SELECT COALESCE(jsonb_agg(
    CASE
      WHEN v_room.status = 'playing'
        AND a.round_index = v_room.current_round
        AND a.user_id <> v_uid
        AND NOT v_reveal_now
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

REVOKE ALL ON FUNCTION private.rope_pull_round_limit(public.rope_pull_rooms) FROM PUBLIC, anon, authenticated;

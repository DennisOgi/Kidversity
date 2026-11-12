-- Rope Pull: stop counting answers that arrive after the round's time is up.
--
-- Answers used to count until any player advanced the round, so a slow
-- advance let late answers pull the rope. The check lives in the public
-- wrapper so the scoring function (private.submit_rope_pull_answer, also
-- changed on the live database by rope_pull_accept_answers_during_countdown)
-- is left exactly as it is.
--
-- Round lengths match private.advance_rope_pull_round: 15 s maths, 25 s past
-- questions, 10 s words. A 1.5 s grace covers a slow network. During the
-- countdown round_started_at is in the future, so early answers still pass.

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
DECLARE
  v_room public.rope_pull_rooms%ROWTYPE;
  v_limit INTEGER;
BEGIN
  SELECT * INTO v_room FROM public.rope_pull_rooms WHERE id = p_room_id;

  IF v_room.id IS NOT NULL
     AND v_room.status = 'playing'
     AND p_round = v_room.current_round
     AND v_room.round_started_at IS NOT NULL THEN
    v_limit := CASE
      WHEN v_room.bank = 'maths' OR v_room.questions->0->>'kind' = 'maths' THEN 15
      WHEN v_room.bank = 'past_questions' OR v_room.questions->0->>'kind' = 'exam' THEN 25
      ELSE 10
    END;
    IF now() > v_room.round_started_at + make_interval(secs => v_limit + 1.5) THEN
      -- Too late: record nothing, just show the current state.
      IF NOT private.is_rope_pull_member(p_room_id) THEN
        RAISE EXCEPTION 'NOT_AUTHORIZED';
      END IF;
      RETURN private.rope_pull_snapshot(p_room_id);
    END IF;
  END IF;

  RETURN private.submit_rope_pull_answer(auth.uid(), p_room_id, p_round, p_selected);
END;
$$;

REVOKE ALL ON FUNCTION public.submit_rope_pull_answer(UUID, INTEGER, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_rope_pull_answer(UUID, INTEGER, TEXT) TO authenticated;

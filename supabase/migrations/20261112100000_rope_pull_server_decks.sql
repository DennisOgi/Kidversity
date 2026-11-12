-- Rope Pull: build every match deck on the server.
--
-- Before this, the host's device built the questions (answers included) and
-- sent them to create_rope_pull_room, so the host held the answer key. Now the
-- app sends only the match type and settings; the server picks the questions,
-- seals the answers into private.rope_pull_keys, and nobody's device ever
-- receives an answer before answering.
--
-- Sources:
--   lessons_1_5, module_1, daily_review  Mandarin words from vocab_items
--   past_questions                        exam_bank_questions
--   maths                                 generated here
--
-- The old entry points (create_rope_pull_room, rope_pull_quick_match with a
-- p_questions deck) keep working for app builds that are still cached in
-- browsers. 20261112100100_rope_pull_lock_client_decks.sql closes them once
-- the new app is live.

-- Shared helpers ----------------------------------------------------------------

CREATE OR REPLACE FUNCTION private.rope_pull_tenths(p_value INTEGER)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$ SELECT format('%s.%s', p_value / 10, p_value % 10) $$;

-- The answer plus up to three different distractors from the pool, shuffled.
CREATE OR REPLACE FUNCTION private.rope_pull_pick_options(p_answer TEXT, p_pool TEXT[])
RETURNS JSONB
LANGUAGE sql
VOLATILE
AS $$
  SELECT jsonb_agg(o ORDER BY random())
  FROM (
    SELECT p_answer AS o
    UNION ALL
    (
      SELECT d FROM (
        SELECT DISTINCT d FROM unnest(p_pool) AS d
        WHERE d IS NOT NULL AND d <> p_answer
      ) distinct_pool
      ORDER BY random()
      LIMIT 3
    )
  ) options;
$$;

-- Marks a deck as "each team gets its own question" (split) and tags its kind.
-- Matches packSplitDeck in the app: an even number of questions, split only
-- flagged on the first one.
CREATE OR REPLACE FUNCTION private.rope_pull_pack_split(p_deck JSONB, p_kind TEXT)
RETURNS JSONB
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT COALESCE(jsonb_agg(
    e || jsonb_build_object('split', ord = 1, 'kind', p_kind) ORDER BY ord
  ), '[]'::jsonb)
  FROM jsonb_array_elements(COALESCE(p_deck, '[]'::jsonb)) WITH ORDINALITY AS t(e, ord)
  WHERE ord <= (jsonb_array_length(COALESCE(p_deck, '[]'::jsonb)) / 2) * 2;
$$;

-- Maths ------------------------------------------------------------------------
-- Times tables, adding, taking away, sharing, word problems, order of
-- operations and tenths. Distractors sit close to the answer so guessing is
-- hard.

CREATE OR REPLACE FUNCTION private.rope_pull_maths_question(p_index INTEGER)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SET search_path = public, private
AS $$
DECLARE
  v_kind INTEGER := floor(random() * 7)::int;
  a INTEGER;
  b INTEGER;
  c INTEGER;
  v_answer INTEGER;
  v_prompt TEXT;
  v_tenths BOOLEAN := FALSE;
  v_offsets INTEGER[] := ARRAY[-10, -5, -2, -1, 1, 2, 5, 10];
  v_options TEXT[];
  v_candidate INTEGER;
  v_label TEXT;
  v_tries INTEGER := 0;
BEGIN
  CASE v_kind
    WHEN 0 THEN
      a := 2 + floor(random() * 11)::int; b := 2 + floor(random() * 11)::int;
      v_answer := a * b; v_prompt := format('%s × %s = ?', a, b);
    WHEN 1 THEN
      a := 12 + floor(random() * 70)::int; b := 4 + floor(random() * 28)::int;
      v_answer := a + b; v_prompt := format('%s + %s = ?', a, b);
    WHEN 2 THEN
      a := 12 + floor(random() * 70)::int; b := 4 + floor(random() * 28)::int;
      v_answer := a; v_prompt := format('%s − %s = ?', a + b, b);
    WHEN 3 THEN
      b := 2 + floor(random() * 11)::int; c := 2 + floor(random() * 11)::int;
      v_answer := c; v_prompt := format('%s ÷ %s = ?', b * c, b);
    WHEN 4 THEN
      a := 3 + floor(random() * 6)::int; b := 4 + floor(random() * 8)::int;
      CASE floor(random() * 3)::int
        WHEN 0 THEN
          v_prompt := format('A class sits in %s rows of %s. How many seats?', a, b);
          v_answer := a * b;
        WHEN 1 THEN
          v_prompt := format('%s friends each bring %s pencils. How many pencils?', b, a);
          v_answer := a * b;
        ELSE
          v_prompt := format('There are %s mangoes in %s equal bags. How many in one bag?', a * b, a);
          v_answer := b;
      END CASE;
    WHEN 5 THEN
      a := 2 + floor(random() * 8)::int; b := 2 + floor(random() * 6)::int;
      c := 2 + floor(random() * 6)::int;
      v_answer := a + b * c; v_prompt := format('%s + %s × %s = ?', a, b, c);
    ELSE
      -- Tenths, kept as whole tenths so the arithmetic stays exact.
      a := 5 + floor(random() * 90)::int; b := 5 + floor(random() * 90)::int;
      v_answer := a + b; v_tenths := TRUE;
      v_prompt := format('%s + %s = ?', private.rope_pull_tenths(a), private.rope_pull_tenths(b));
  END CASE;

  v_label := CASE WHEN v_tenths THEN private.rope_pull_tenths(v_answer) ELSE v_answer::text END;
  v_options := ARRAY[v_label];
  WHILE array_length(v_options, 1) < 4 AND v_tries < 50 LOOP
    v_tries := v_tries + 1;
    v_candidate := v_answer + v_offsets[1 + floor(random() * array_length(v_offsets, 1))::int];
    CONTINUE WHEN v_candidate <= 0;
    v_label := CASE WHEN v_tenths THEN private.rope_pull_tenths(v_candidate) ELSE v_candidate::text END;
    IF NOT v_label = ANY (v_options) THEN
      v_options := v_options || v_label;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'id', 'maths-' || p_index,
    'simplified', '', 'pinyin', '', 'english', '',
    'prompt', v_prompt,
    'answer', v_options[1],
    'options', (SELECT jsonb_agg(o ORDER BY random()) FROM unnest(v_options) AS o)
  );
END;
$$;

-- Mandarin words ---------------------------------------------------------------

CREATE OR REPLACE FUNCTION private.rope_pull_word_deck(p_user UUID, p_bank TEXT, p_count INTEGER)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_words JSONB;
  v_pool TEXT[];
  v_deck JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(to_jsonb(w)), '[]'::jsonb) INTO v_words
  FROM (
    SELECT DISTINCT ON (v.simplified_chinese, v.pinyin)
      v.id, v.simplified_chinese, v.pinyin, trim(v.english_meaning) AS english_meaning
    FROM public.vocab_items v
    JOIN public.course_lessons l ON l.id = v.lesson_id
    WHERE l.status = 'approved'
      AND v.review_status IN ('approved', 'corrected')
      AND COALESCE(trim(v.english_meaning), '') <> ''
      AND COALESCE(trim(v.simplified_chinese), '') <> ''
      AND (
        (p_bank = 'lessons_1_5' AND l.sequence BETWEEN 1 AND 5)
        OR (p_bank = 'module_1' AND l.sequence BETWEEN 1 AND 10)
        -- Daily review: lesson 1, plus every lesson whose previous lesson
        -- this learner has finished.
        OR (p_bank = 'daily_review' AND (
          l.sequence = 1
          OR EXISTS (
            SELECT 1
            FROM public.lesson_results r
            JOIN public.course_lessons prev ON prev.id = r.lesson_id
            WHERE r.user_id = p_user
              AND prev.course_id = l.course_id
              AND prev.sequence = l.sequence - 1
          )
        ))
      )
    ORDER BY v.simplified_chinese, v.pinyin, v.id
  ) w;

  IF jsonb_array_length(v_words) < 4 THEN
    IF p_bank <> 'lessons_1_5' THEN
      RETURN private.rope_pull_word_deck(p_user, 'lessons_1_5', p_count);
    END IF;
    RAISE EXCEPTION 'NOT_ENOUGH_QUESTIONS';
  END IF;

  v_pool := ARRAY(SELECT DISTINCT e->>'english_meaning' FROM jsonb_array_elements(v_words) e);

  SELECT jsonb_agg(question) INTO v_deck
  FROM (
    SELECT jsonb_build_object(
      'id', pick.e->>'id',
      'simplified', pick.e->>'simplified_chinese',
      'pinyin', pick.e->>'pinyin',
      'english', pick.e->>'english_meaning',
      'answer', pick.e->>'english_meaning',
      'audio_url', audio.ref,
      'options', private.rope_pull_pick_options(pick.e->>'english_meaning', v_pool)
    ) AS question
    FROM (
      SELECT e FROM jsonb_array_elements(v_words) e
      ORDER BY random()
      LIMIT LEAST(GREATEST(p_count, 4), 10)
    ) pick
    LEFT JOIN LATERAL (
      SELECT CASE
        WHEN NULLIF(a.storage_path, '') IS NOT NULL THEN 'storage:' || a.storage_path
        ELSE NULLIF(a.audio_url, '')
      END AS ref
      FROM public.audio_clips a
      WHERE a.item_type = 'vocab' AND a.item_id = pick.e->>'id'
      ORDER BY a.generated_at DESC NULLS LAST
      LIMIT 1
    ) audio ON TRUE
  ) deck;

  RETURN v_deck;
END;
$$;

-- Past questions -------------------------------------------------------------------

CREATE OR REPLACE FUNCTION private.rope_pull_exam_deck(
  p_exam TEXT,
  p_subject TEXT,
  p_university TEXT,
  p_count INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_deck JSONB;
BEGIN
  SELECT jsonb_agg(question ORDER BY ord) INTO v_deck
  FROM (
    SELECT row_number() OVER () AS ord, question
    FROM (
      SELECT jsonb_build_object(
        'id', 'pq-' || q.id,
        'simplified', '', 'pinyin', '',
        'english', COALESCE(q.payload->>'examyear', q.exam_year, ''),
        'prompt', trim(q.payload->>'question'),
        'solution', NULLIF(trim(COALESCE(q.payload->>'solution', '')), ''),
        'options', opts.options,
        'answer', opts.answer
      ) AS question
      FROM (
        SELECT * FROM public.exam_bank_questions
        WHERE exam_slug = p_exam
          AND subject_slug = p_subject
          AND (NULLIF(trim(p_university), '') IS NULL OR university = trim(p_university))
          AND COALESCE(trim(payload->>'question'), '') <> ''
          -- Image questions cannot be shown in the match.
          AND COALESCE(payload->>'image', '') = ''
          AND jsonb_typeof(payload->'option') = 'object'
        ORDER BY random()
        LIMIT 60
      ) q
      CROSS JOIN LATERAL (
        SELECT
          jsonb_agg(upper(k) || '. ' || trim(v) ORDER BY k) AS options,
          max(CASE WHEN lower(k) = lower(trim(q.payload->>'answer'))
                   THEN upper(k) || '. ' || trim(v) END) AS answer
        FROM jsonb_each_text(q.payload->'option') AS o(k, v)
        WHERE COALESCE(trim(v), '') <> ''
      ) opts
      WHERE opts.answer IS NOT NULL AND jsonb_array_length(opts.options) >= 2
    ) usable
  ) numbered
  WHERE ord <= LEAST(GREATEST(p_count, 4), 40);

  IF v_deck IS NULL OR jsonb_array_length(v_deck) < 4 THEN
    RAISE EXCEPTION 'NOT_ENOUGH_QUESTIONS';
  END IF;
  RETURN v_deck;
END;
$$;

-- Dispatcher -----------------------------------------------------------------------

-- p_options: {"count": 10, "exam": "utme", "subject": "biology", "university": null}
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
    SELECT jsonb_agg(private.rope_pull_maths_question(i)) INTO v_deck
    FROM generate_series(0, v_count - 1) AS i;
    RETURN private.rope_pull_pack_split(v_deck, 'maths');
  ELSIF p_bank = 'past_questions' THEN
    v_deck := private.rope_pull_exam_deck(
      p_options->>'exam', p_options->>'subject', p_options->>'university', v_count
    );
    RETURN private.rope_pull_pack_split(v_deck, 'exam');
  ELSIF p_bank IN ('lessons_1_5', 'module_1', 'daily_review') THEN
    RETURN private.rope_pull_word_deck(p_user, p_bank, LEAST(v_count, 10));
  END IF;
  RAISE EXCEPTION 'INVALID_BANK';
END;
$$;

-- Public entry points ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.create_rope_pull_match(
  p_bank TEXT,
  p_options JSONB DEFAULT '{}'::jsonb,
  p_host_plays BOOLEAN DEFAULT TRUE,
  p_display_name TEXT DEFAULT 'Host',
  p_avatar TEXT DEFAULT '🦊',
  p_challenged_user_id UUID DEFAULT NULL,
  p_class_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  RETURN public.create_rope_pull_room(
    p_bank,
    private.rope_pull_build_deck(auth.uid(), p_bank, COALESCE(p_options, '{}'::jsonb)),
    p_host_plays,
    p_display_name,
    p_avatar,
    p_challenged_user_id,
    p_class_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.rope_pull_quick_match_v2(
  p_bank TEXT,
  p_options JSONB DEFAULT '{}'::jsonb,
  p_display_name TEXT DEFAULT 'Learner',
  p_avatar TEXT DEFAULT '🦊'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  -- The deck is only used if no classmate is waiting; joining keeps theirs.
  RETURN public.rope_pull_quick_match(
    p_bank,
    private.rope_pull_build_deck(auth.uid(), p_bank, COALESCE(p_options, '{}'::jsonb)),
    p_display_name,
    p_avatar
  );
END;
$$;

-- Grants -----------------------------------------------------------------------------

REVOKE ALL ON FUNCTION private.rope_pull_tenths(INTEGER) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.rope_pull_pick_options(TEXT, TEXT[]) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.rope_pull_pack_split(JSONB, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.rope_pull_maths_question(INTEGER) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.rope_pull_word_deck(UUID, TEXT, INTEGER) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.rope_pull_exam_deck(TEXT, TEXT, TEXT, INTEGER) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.rope_pull_build_deck(UUID, TEXT, JSONB) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.create_rope_pull_match(TEXT, JSONB, BOOLEAN, TEXT, TEXT, UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_rope_pull_match(TEXT, JSONB, BOOLEAN, TEXT, TEXT, UUID, UUID) TO authenticated;
REVOKE ALL ON FUNCTION public.rope_pull_quick_match_v2(TEXT, JSONB, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rope_pull_quick_match_v2(TEXT, JSONB, TEXT, TEXT) TO authenticated;

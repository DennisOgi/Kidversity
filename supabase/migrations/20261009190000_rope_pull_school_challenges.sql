-- Rope Pull: classmates and schoolmates can challenge each other
-- without sharing a courtyard code.

ALTER TABLE public.rope_pull_rooms
  ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES public.schools(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS class_id UUID REFERENCES public.classes(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS challenged_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_rope_pull_rooms_school_lobby
  ON public.rope_pull_rooms (school_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_rope_pull_rooms_challenge
  ON public.rope_pull_rooms (challenged_user_id, status)
  WHERE challenged_user_id IS NOT NULL;

DROP FUNCTION IF EXISTS public.create_rope_pull_room(TEXT, JSONB, BOOLEAN, TEXT, TEXT);

CREATE FUNCTION public.create_rope_pull_room(
  p_bank TEXT,
  p_questions JSONB,
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
DECLARE
  v_uid UUID := auth.uid();
  v_snap JSONB;
  v_room UUID;
  v_school UUID;
  v_role TEXT;
  v_class UUID;
  v_challenge UUID := p_challenged_user_id;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  v_snap := private.create_rope_pull_room(
    v_uid, p_bank, p_questions, p_host_plays, p_display_name, p_avatar
  );
  v_room := (v_snap -> 'room' ->> 'id')::uuid;

  SELECT school_id, member_role INTO v_school, v_role
  FROM private.caller_school(v_uid, NULL);

  IF v_school IS NOT NULL THEN
    IF p_class_id IS NOT NULL THEN
      SELECT c.id INTO v_class
      FROM public.classes c
      WHERE c.id = p_class_id AND c.school_id = v_school
        AND (
          v_role = 'admin'
          OR c.teacher_id = v_uid
          OR EXISTS (
            SELECT 1 FROM public.class_members cm
            WHERE cm.class_id = c.id AND cm.user_id = v_uid
          )
        );
    END IF;

    IF v_class IS NULL THEN
      SELECT c.id INTO v_class
      FROM public.classes c
      WHERE c.school_id = v_school
        AND (
          c.teacher_id = v_uid
          OR EXISTS (
            SELECT 1 FROM public.class_members cm
            WHERE cm.class_id = c.id AND cm.user_id = v_uid
          )
        )
      ORDER BY c.name
      LIMIT 1;
    END IF;

    IF v_challenge IS NOT NULL THEN
      IF v_challenge = v_uid OR NOT EXISTS (
        SELECT 1 FROM public.school_members m
        WHERE m.school_id = v_school AND m.user_id = v_challenge
      ) THEN
        v_challenge := NULL;
      END IF;
    END IF;

    UPDATE public.rope_pull_rooms
    SET
      school_id = v_school,
      class_id = v_class,
      challenged_user_id = v_challenge,
      updated_at = now()
    WHERE id = v_room;
  END IF;

  RETURN private.rope_pull_snapshot(v_room);
END;
$$;

CREATE OR REPLACE FUNCTION public.join_rope_pull_room_by_id(
  p_room_id UUID,
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
  v_room public.rope_pull_rooms%ROWTYPE;
  v_school UUID;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  SELECT * INTO v_room FROM public.rope_pull_rooms WHERE id = p_room_id;
  IF v_room.id IS NULL THEN
    RAISE EXCEPTION 'INVALID_CODE';
  END IF;

  SELECT school_id INTO v_school
  FROM private.caller_school(v_uid, NULL);

  IF NOT (
    v_room.host_id = v_uid
    OR v_room.challenged_user_id = v_uid
    OR EXISTS (
      SELECT 1 FROM public.rope_pull_players p
      WHERE p.room_id = v_room.id AND p.user_id = v_uid
    )
    OR (
      v_room.school_id IS NOT NULL
      AND v_school IS NOT NULL
      AND v_room.school_id = v_school
    )
  ) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  RETURN private.join_rope_pull_room(
    v_uid, v_room.join_code, p_display_name, p_avatar
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fetch_rope_pull_school_play()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_school UUID;
  v_role TEXT;
  v_name TEXT;
  v_class UUID;
  v_class_name TEXT;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  SELECT school_id, school_name, member_role
  INTO v_school, v_name, v_role
  FROM private.caller_school(v_uid, NULL);

  IF v_school IS NULL THEN
    RETURN jsonb_build_object(
      'school_name', NULL,
      'class_name', NULL,
      'playmates', '[]'::jsonb,
      'matches', '[]'::jsonb
    );
  END IF;

  SELECT c.id, c.name INTO v_class, v_class_name
  FROM public.classes c
  WHERE c.school_id = v_school
    AND (
      c.teacher_id = v_uid
      OR EXISTS (
        SELECT 1 FROM public.class_members cm
        WHERE cm.class_id = c.id AND cm.user_id = v_uid
      )
    )
  ORDER BY c.name
  LIMIT 1;

  RETURN jsonb_build_object(
    'school_name', v_name,
    'class_name', v_class_name,
    'playmates', COALESCE(
      (
        SELECT jsonb_agg(person ORDER BY (person->>'same_class') DESC, person->>'display_name')
        FROM (
          SELECT jsonb_build_object(
            'user_id', m.user_id,
            'display_name', COALESCE(NULLIF(trim(p.display_name), ''), 'Learner'),
            'avatar', COALESCE(NULLIF(trim(p.avatar_emoji), ''), '🦊'),
            'role', m.role,
            'class_name', (
              SELECT c.name
              FROM public.class_members cm
              JOIN public.classes c ON c.id = cm.class_id
              WHERE cm.user_id = m.user_id AND c.school_id = v_school
              ORDER BY c.name
              LIMIT 1
            ),
            'same_class', EXISTS (
              SELECT 1
              FROM public.class_members mine
              JOIN public.class_members theirs ON theirs.class_id = mine.class_id
              JOIN public.classes c ON c.id = mine.class_id
              WHERE mine.user_id = v_uid
                AND theirs.user_id = m.user_id
                AND c.school_id = v_school
            )
          ) AS person
          FROM public.school_members m
          JOIN public.user_profiles p ON p.user_id = m.user_id
          WHERE m.school_id = v_school
            AND m.user_id <> v_uid
            AND m.role IN ('student', 'teacher')
        ) listed
      ),
      '[]'::jsonb
    ),
    'matches', COALESCE(
      (
        SELECT jsonb_agg(item ORDER BY (item->>'challenged_you') DESC, item->>'created_at' DESC)
        FROM (
          SELECT jsonb_build_object(
            'room_id', r.id,
            'host_name', COALESCE(NULLIF(trim(host.display_name), ''), 'Host'),
            'host_avatar', COALESCE(NULLIF(trim(host.avatar_emoji), ''), '🦊'),
            'bank', r.bank,
            'class_name', cls.name,
            'player_count', (
              SELECT COUNT(*) FROM public.rope_pull_players rp WHERE rp.room_id = r.id
            ),
            'challenged_you', r.challenged_user_id = v_uid,
            'created_at', r.created_at
          ) AS item
          FROM public.rope_pull_rooms r
          LEFT JOIN public.user_profiles host ON host.user_id = r.host_id
          LEFT JOIN public.classes cls ON cls.id = r.class_id
          WHERE r.status = 'lobby'
            AND r.school_id = v_school
            AND r.host_id <> v_uid
            AND r.created_at > now() - interval '2 hours'
            AND NOT EXISTS (
              SELECT 1 FROM public.rope_pull_players rp
              WHERE rp.room_id = r.id AND rp.user_id = v_uid
            )
            AND (
              r.challenged_user_id = v_uid
              OR (
                r.challenged_user_id IS NULL
                AND (
                  v_class IS NULL
                  OR r.class_id IS NULL
                  OR r.class_id = v_class
                )
              )
            )
        ) waiting
      ),
      '[]'::jsonb
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.create_rope_pull_room(TEXT, JSONB, BOOLEAN, TEXT, TEXT, UUID, UUID)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.join_rope_pull_room_by_id(UUID, TEXT, TEXT)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fetch_rope_pull_school_play()
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.create_rope_pull_room(TEXT, JSONB, BOOLEAN, TEXT, TEXT, UUID, UUID)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_rope_pull_room_by_id(UUID, TEXT, TEXT)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.fetch_rope_pull_school_play()
  TO authenticated;

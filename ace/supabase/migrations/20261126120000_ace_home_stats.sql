-- Learner home: progress per channel, overall stats, a study streak and the
-- lesson to resume. Extends ace_me(); same access rules.
CREATE OR REPLACE FUNCTION public.ace_me()
RETURNS JSONB
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_streak INT := 0;
  v_day DATE;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;

  -- Consecutive days with at least one attempt, ending today or yesterday.
  v_day := (SELECT max(created_at)::date FROM public.attempts WHERE user_id = v_uid);
  IF v_day IS NOT NULL AND v_day >= current_date - 1 THEN
    WHILE EXISTS (SELECT 1 FROM public.attempts
                  WHERE user_id = v_uid AND created_at::date = v_day) LOOP
      v_streak := v_streak + 1;
      v_day := v_day - 1;
    END LOOP;
  END IF;

  RETURN jsonb_build_object(
    'user_id', v_uid,
    'display_name', (SELECT display_name FROM public.profiles WHERE user_id = v_uid),
    'platform_role', (SELECT platform_role FROM public.profiles WHERE user_id = v_uid),
    'schools', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', s.id, 'name', s.name, 'role', m.role, 'content_mode', s.content_mode
      ) ORDER BY s.name)
      FROM public.school_members m JOIN public.schools s ON s.id = m.school_id
      WHERE m.user_id = v_uid
    ), '[]'::jsonb),
    'stats', jsonb_build_object(
      'attempts', (SELECT count(*) FROM public.attempts WHERE user_id = v_uid),
      'questions_tried', (SELECT count(DISTINCT question_id) FROM public.attempts WHERE user_id = v_uid),
      'matched', (SELECT count(DISTINCT question_id) FROM public.attempts WHERE user_id = v_uid
                  AND final_answer_status IN ('final_answer_match', 'option_match')),
      'awaiting_teacher', (SELECT count(*) FROM public.attempts WHERE user_id = v_uid
                           AND marking_state = 'needs_review'),
      'streak_days', v_streak
    ),
    'resume', (
      SELECT jsonb_build_object(
        'lesson_id', l.id, 'title', l.title, 'channel_id', l.channel_id,
        'stage', c.stage, 'subject', c.subject
      )
      FROM public.attempts a
      JOIN public.questions q ON q.id = a.question_id
      JOIN public.lessons l ON l.id = q.lesson_id
      JOIN public.channels c ON c.id = l.channel_id
      WHERE a.user_id = v_uid
        AND private.can_see_content(l.channel_id, l.school_id, l.review_status)
      ORDER BY a.created_at DESC LIMIT 1
    ),
    'channels', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', c.id, 'stage', c.stage, 'subject', c.subject, 'group', c.group_label,
        'profile_id', c.profile_id,
        'syllabus', p.board || ' ' || p.syllabus_code,
        'lessons', (
          SELECT count(*) FROM public.lessons l
          WHERE l.channel_id = c.id
            AND private.can_see_content(l.channel_id, l.school_id, l.review_status)
        ),
        'questions', (
          SELECT count(*) FROM public.questions q
          WHERE q.channel_id = c.id
            AND private.can_see_content(q.channel_id, q.school_id, q.review_status)
        ),
        'attempted', (
          SELECT count(DISTINCT a.question_id) FROM public.attempts a
          JOIN public.questions q ON q.id = a.question_id
          WHERE a.user_id = v_uid AND q.channel_id = c.id
        ),
        'matched', (
          SELECT count(DISTINCT a.question_id) FROM public.attempts a
          JOIN public.questions q ON q.id = a.question_id
          WHERE a.user_id = v_uid AND q.channel_id = c.id
            AND a.final_answer_status IN ('final_answer_match', 'option_match')
        )
      ) ORDER BY c.sort_order)
      FROM public.channels c
      JOIN public.syllabus_profiles p ON p.id = c.profile_id
      WHERE private.is_platform_staff()
         OR c.id IN (SELECT channel_id FROM private.my_channels())
    ), '[]'::jsonb)
  );
END;
$$;

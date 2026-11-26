-- ACE content import, installed once. Callers pass one package (or one
-- chunk of it) as JSON; see ace/tools/import_content.py. Idempotent.
CREATE OR REPLACE FUNCTION private.ace_import_package(pkg JSONB)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, private
AS $import$
DECLARE
  r JSONB;
  v_conflicts TEXT;
  v_school UUID;
  v_code TEXT;
BEGIN
  -- Refuse changed content that kept the same version.
  SELECT string_agg(x.id, ', ') INTO v_conflicts
  FROM (
    SELECT l->>'id' AS id, 'lesson' AS kind, (l->>'content_version')::int AS v, l->>'snapshot_hash' AS h
    FROM jsonb_array_elements(pkg->'lessons') l
    UNION ALL
    SELECT q->>'id', 'question', (q->>'content_version')::int, q->>'snapshot_hash'
    FROM jsonb_array_elements(pkg->'questions') q
  ) x
  JOIN private.content_versions cv
    ON cv.kind = x.kind AND cv.id = x.id AND cv.content_version = x.v
  WHERE cv.snapshot_hash <> x.h;
  IF v_conflicts IS NOT NULL THEN
    RAISE EXCEPTION 'Content changed without a content_version bump: %', v_conflicts;
  END IF;

  INSERT INTO public.sources (id, title, url, checked_on, access, bundled_content, raw, updated_at)
  SELECT s->>'id', s->>'title', s->>'url', (s->>'checked_on')::date, s->>'access',
         COALESCE((s->>'bundled_content')::boolean, false), s, now()
  FROM jsonb_array_elements(pkg->'sources') s
  ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, url = EXCLUDED.url,
    checked_on = EXCLUDED.checked_on, access = EXCLUDED.access,
    bundled_content = EXCLUDED.bundled_content, raw = EXCLUDED.raw, updated_at = now();

  INSERT INTO public.syllabus_profiles (id, board, qualification, subject, syllabus_code,
    exam_years, status, syllabus_document_version, revision_published, source_ids, raw, updated_at)
  SELECT p->>'id', p->>'board', p->>'qualification', p->>'subject', p->>'syllabus_code',
    ARRAY(SELECT jsonb_array_elements_text(p->'exam_years')::int), p->>'status',
    (p->>'syllabus_document_version')::int, p->>'revision_published',
    ARRAY(SELECT jsonb_array_elements_text(COALESCE(p->'source_ids', '[]'::jsonb))), p, now()
  FROM jsonb_array_elements(pkg->'profiles') p
  ON CONFLICT (id) DO UPDATE SET board = EXCLUDED.board, qualification = EXCLUDED.qualification,
    subject = EXCLUDED.subject, syllabus_code = EXCLUDED.syllabus_code,
    exam_years = EXCLUDED.exam_years, status = EXCLUDED.status,
    syllabus_document_version = EXCLUDED.syllabus_document_version,
    revision_published = EXCLUDED.revision_published, source_ids = EXCLUDED.source_ids,
    raw = EXCLUDED.raw, updated_at = now();

  INSERT INTO public.topics (id, profile_id, syllabus_ref, title, paper_components, stages,
    scope, lesson_status, source_id, sort_order, updated_at)
  SELECT t->>'id', t->>'profile_id', t->>'syllabus_ref', t->>'title',
    ARRAY(SELECT jsonb_array_elements_text(COALESCE(t->'paper_components', '[]'::jsonb))),
    ARRAY(SELECT jsonb_array_elements_text(COALESCE(t->'stages', '[]'::jsonb))),
    t->>'scope', t->>'lesson_status', t->>'source_id', (t->>'sort_order')::int, now()
  FROM jsonb_array_elements(pkg->'topics') t
  ON CONFLICT (id) DO UPDATE SET profile_id = EXCLUDED.profile_id,
    syllabus_ref = EXCLUDED.syllabus_ref, title = EXCLUDED.title,
    paper_components = EXCLUDED.paper_components, stages = EXCLUDED.stages,
    scope = EXCLUDED.scope, lesson_status = EXCLUDED.lesson_status,
    source_id = EXCLUDED.source_id, sort_order = EXCLUDED.sort_order, updated_at = now();

  INSERT INTO public.routes (id, profile_id, award, papers, progresses_by_as_carry_forward, raw, updated_at)
  SELECT r2->>'id', r2->>'profile_id', r2->>'award',
    ARRAY(SELECT jsonb_array_elements_text(COALESCE(r2->'papers', '[]'::jsonb))),
    (r2->>'progresses_by_as_carry_forward')::boolean, r2, now()
  FROM jsonb_array_elements(pkg->'routes') r2
  ON CONFLICT (id) DO UPDATE SET profile_id = EXCLUDED.profile_id, award = EXCLUDED.award,
    papers = EXCLUDED.papers,
    progresses_by_as_carry_forward = EXCLUDED.progresses_by_as_carry_forward,
    raw = EXCLUDED.raw, updated_at = now();

  INSERT INTO public.channels (id, group_label, stage, subject, profile_id, sections,
    publication_status, mathematics_route_filter_required, as_prerequisite_links, sort_order, updated_at)
  SELECT c->>'id', c->>'group', c->>'stage', c->>'subject', c->>'profile_id',
    ARRAY(SELECT jsonb_array_elements_text(COALESCE(c->'sections', '[]'::jsonb))),
    COALESCE(c->>'publication_status', 'staging'),
    COALESCE((c->>'mathematics_route_filter_required')::boolean, false),
    COALESCE((c->>'as_prerequisite_links')::boolean, false),
    (c->>'sort_order')::int, now()
  FROM jsonb_array_elements(pkg->'channels') c
  ON CONFLICT (id) DO UPDATE SET group_label = EXCLUDED.group_label, stage = EXCLUDED.stage,
    subject = EXCLUDED.subject, profile_id = EXCLUDED.profile_id, sections = EXCLUDED.sections,
    publication_status = EXCLUDED.publication_status,
    mathematics_route_filter_required = EXCLUDED.mathematics_route_filter_required,
    as_prerequisite_links = EXCLUDED.as_prerequisite_links,
    sort_order = EXCLUDED.sort_order, updated_at = now();

  INSERT INTO public.resources (id, source_id, profile_id, resource_type, delivery,
    is_exam_paper, rights_status, raw, updated_at)
  SELECT x->>'id', x->>'source_id', x->>'profile_id', x->>'resource_type',
    COALESCE(x->>'delivery', 'external_link'), COALESCE((x->>'is_exam_paper')::boolean, false),
    x->>'rights_status', x, now()
  FROM jsonb_array_elements(pkg->'resources') x
  ON CONFLICT (id) DO UPDATE SET source_id = EXCLUDED.source_id, profile_id = EXCLUDED.profile_id,
    resource_type = EXCLUDED.resource_type, delivery = EXCLUDED.delivery,
    is_exam_paper = EXCLUDED.is_exam_paper, rights_status = EXCLUDED.rights_status,
    raw = EXCLUDED.raw, updated_at = now();

  INSERT INTO public.lessons (id, school_id, channel_id, profile_id, topic_id, stage, title,
    minutes, objectives, prerequisites, explanation_markdown, worked_example, common_errors,
    exit_check, provenance, official_endorsement, alignment_status, content_version,
    review_status, reviewer, reviewed_on, sort_order, updated_at)
  SELECT l->>'id', NULL, l->>'channel_id', l->>'profile_id', l->>'topic_id', l->>'stage',
    l->>'title', (l->>'minutes')::int,
    ARRAY(SELECT jsonb_array_elements_text(COALESCE(l->'objectives', '[]'::jsonb))),
    ARRAY(SELECT jsonb_array_elements_text(COALESCE(l->'prerequisites', '[]'::jsonb))),
    COALESCE(l->>'explanation_markdown', ''), l->'worked_example',
    ARRAY(SELECT jsonb_array_elements_text(COALESCE(l->'common_errors', '[]'::jsonb))),
    l->>'exit_check', l->>'provenance', COALESCE((l->>'official_endorsement')::boolean, false),
    l->>'alignment_status', (l->>'content_version')::int, l->>'review_status',
    l->>'reviewer', (l->>'reviewed_on')::date, (l->>'sort_order')::int, now()
  FROM jsonb_array_elements(pkg->'lessons') l
  ON CONFLICT (id) DO UPDATE SET channel_id = EXCLUDED.channel_id,
    profile_id = EXCLUDED.profile_id, topic_id = EXCLUDED.topic_id, stage = EXCLUDED.stage,
    title = EXCLUDED.title, minutes = EXCLUDED.minutes, objectives = EXCLUDED.objectives,
    prerequisites = EXCLUDED.prerequisites, explanation_markdown = EXCLUDED.explanation_markdown,
    worked_example = EXCLUDED.worked_example, common_errors = EXCLUDED.common_errors,
    exit_check = EXCLUDED.exit_check, provenance = EXCLUDED.provenance,
    official_endorsement = EXCLUDED.official_endorsement,
    alignment_status = EXCLUDED.alignment_status, content_version = EXCLUDED.content_version,
    review_status = EXCLUDED.review_status, reviewer = EXCLUDED.reviewer,
    reviewed_on = EXCLUDED.reviewed_on, sort_order = EXCLUDED.sort_order, updated_at = now()
  WHERE public.lessons.school_id IS NULL;  -- never overwrite school-private content

  INSERT INTO private.content_versions (kind, id, content_version, snapshot, snapshot_hash)
  SELECT 'lesson', l->>'id', (l->>'content_version')::int, l - 'snapshot_hash' - 'sort_order', l->>'snapshot_hash'
  FROM jsonb_array_elements(pkg->'lessons') l
  ON CONFLICT DO NOTHING;

  INSERT INTO public.questions (id, school_id, lesson_id, channel_id, profile_id, topic_id,
    stage, kind, prompt_markdown, parts, options, max_marks, answer_unit, difficulty,
    provenance, is_past_paper, exam_mode_response, workings_required_for_exam_mode,
    content_version, review_status, reviewer, reviewed_on, sort_order, updated_at)
  SELECT q->>'id', NULL, q->>'lesson_id', q->>'channel_id', q->>'profile_id', q->>'topic_id',
    q->>'stage', q->>'kind', q->>'prompt_markdown', q->'parts', q->'options',
    (q->>'max_marks')::int, q->>'answer_unit', q->>'difficulty', q->>'provenance',
    COALESCE((q->>'is_past_paper')::boolean, false), q->>'exam_mode_response',
    COALESCE((q->>'workings_required_for_exam_mode')::boolean, false),
    (q->>'content_version')::int, q->>'review_status', q->>'reviewer',
    (q->>'reviewed_on')::date, (q->>'sort_order')::int, now()
  FROM jsonb_array_elements(pkg->'questions') q
  ON CONFLICT (id) DO UPDATE SET lesson_id = EXCLUDED.lesson_id,
    channel_id = EXCLUDED.channel_id, profile_id = EXCLUDED.profile_id,
    topic_id = EXCLUDED.topic_id, stage = EXCLUDED.stage, kind = EXCLUDED.kind,
    prompt_markdown = EXCLUDED.prompt_markdown, parts = EXCLUDED.parts,
    options = EXCLUDED.options, max_marks = EXCLUDED.max_marks,
    answer_unit = EXCLUDED.answer_unit, difficulty = EXCLUDED.difficulty,
    provenance = EXCLUDED.provenance, is_past_paper = EXCLUDED.is_past_paper,
    exam_mode_response = EXCLUDED.exam_mode_response,
    workings_required_for_exam_mode = EXCLUDED.workings_required_for_exam_mode,
    content_version = EXCLUDED.content_version, review_status = EXCLUDED.review_status,
    reviewer = EXCLUDED.reviewer, reviewed_on = EXCLUDED.reviewed_on,
    sort_order = EXCLUDED.sort_order, updated_at = now()
  WHERE public.questions.school_id IS NULL;

  INSERT INTO private.question_keys (question_id, content_version, answer_markdown,
    worked_solution, rubric, numeric_answer, correct_option, grading)
  SELECT q->>'id', (q->>'content_version')::int, q->'key'->>'answer_markdown',
    COALESCE(q->'key'->'worked_solution', '[]'::jsonb), COALESCE(q->'key'->'rubric', '[]'::jsonb),
    NULLIF(q->'key'->'numeric_answer', 'null'::jsonb), q->'key'->>'correct_option',
    COALESCE(q->'key'->>'grading', 'teacher_marked')
  FROM jsonb_array_elements(pkg->'questions') q
  ON CONFLICT (question_id, content_version) DO NOTHING;

  INSERT INTO private.content_versions (kind, id, content_version, snapshot, snapshot_hash)
  SELECT 'question', q->>'id', (q->>'content_version')::int, q - 'snapshot_hash' - 'sort_order', q->>'snapshot_hash'
  FROM jsonb_array_elements(pkg->'questions') q
  ON CONFLICT DO NOTHING;

  INSERT INTO private.import_runs (package, package_version, counts)
  VALUES (pkg->>'package', pkg->>'version', jsonb_build_object(
    'sources', jsonb_array_length(pkg->'sources'),
    'profiles', jsonb_array_length(pkg->'profiles'),
    'topics', jsonb_array_length(pkg->'topics'),
    'routes', jsonb_array_length(pkg->'routes'),
    'channels', jsonb_array_length(pkg->'channels'),
    'resources', jsonb_array_length(pkg->'resources'),
    'lessons', jsonb_array_length(pkg->'lessons'),
    'questions', jsonb_array_length(pkg->'questions')
  ));

  -- Optional pilot school, staging mode, all channels.
  IF pkg->>'pilot_school' IS NOT NULL THEN
    SELECT id, join_code INTO v_school, v_code FROM public.schools WHERE name = pkg->>'pilot_school';
    IF v_school IS NULL THEN
      v_code := upper(substr(translate(md5(random()::text || clock_timestamp()::text), '01', ''), 1, 8));
      INSERT INTO public.schools (name, join_code, content_mode)
      VALUES (pkg->>'pilot_school', v_code, 'staging') RETURNING id INTO v_school;
    END IF;
    INSERT INTO public.school_channels (school_id, channel_id)
    SELECT v_school, c->>'id' FROM jsonb_array_elements(pkg->'channels') c
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN jsonb_build_object('lessons', jsonb_array_length(pkg->'lessons'),
    'questions', jsonb_array_length(pkg->'questions'), 'pilot_join_code', v_code);
END
$import$;
REVOKE ALL ON FUNCTION private.ace_import_package(JSONB) FROM PUBLIC, anon, authenticated;

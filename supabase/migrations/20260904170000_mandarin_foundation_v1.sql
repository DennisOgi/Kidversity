-- Mandarin Foundation V1: sequenced, review-gated content engine.

ALTER TABLE user_profiles DROP CONSTRAINT IF EXISTS user_profiles_role_check;
ALTER TABLE user_profiles ADD CONSTRAINT user_profiles_role_check
  CHECK (role IN ('student', 'teacher', 'reviewer'));

CREATE TABLE IF NOT EXISTS reviewer_accounts (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  provisioned_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE reviewer_accounts ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT CASE
    WHEN profile.role = 'reviewer' AND EXISTS (
      SELECT 1 FROM public.reviewer_accounts reviewer
      WHERE reviewer.user_id = auth.uid() AND reviewer.active
    ) THEN 'reviewer'
    WHEN profile.role IN ('student', 'teacher') THEN profile.role
    ELSE NULL
  END
  FROM public.user_profiles profile
  WHERE profile.user_id = auth.uid();
$$;

REVOKE ALL ON FUNCTION public.current_user_role() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_user_role() TO authenticated;

CREATE TABLE IF NOT EXISTS courses (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  level TEXT NOT NULL,
  target_age TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS course_modules (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  course_id TEXT NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  sequence INTEGER NOT NULL,
  title TEXT NOT NULL,
  subtitle TEXT NOT NULL DEFAULT '',
  quest_lesson_id TEXT,
  UNIQUE(course_id, sequence)
);

CREATE TABLE IF NOT EXISTS course_lessons (
  id TEXT PRIMARY KEY,
  course_id TEXT NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  module_sequence INTEGER NOT NULL,
  sequence INTEGER NOT NULL,
  title TEXT NOT NULL,
  objective TEXT NOT NULL DEFAULT '',
  explanation TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'shell'
    CHECK (status IN ('shell', 'ready', 'in_review', 'approved')),
  xp_reward INTEGER NOT NULL DEFAULT 100,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(course_id, sequence)
);

ALTER TABLE course_modules
  DROP CONSTRAINT IF EXISTS course_modules_quest_lesson_id_fkey;
ALTER TABLE course_modules
  ADD CONSTRAINT course_modules_quest_lesson_id_fkey
  FOREIGN KEY (quest_lesson_id) REFERENCES course_lessons(id) ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS content_sources (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  source_name TEXT NOT NULL,
  url TEXT,
  licence TEXT NOT NULL,
  dataset_version TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO content_sources (id, source_name, url, licence, dataset_version)
VALUES (
  'f1000000-0000-4000-8000-000000000001',
  'Kidversity Foundation V1 first-party pack',
  NULL,
  'All rights reserved — original Kidversity content',
  '1.0'
)
ON CONFLICT (id) DO UPDATE SET
  source_name = EXCLUDED.source_name,
  licence = EXCLUDED.licence,
  dataset_version = EXCLUDED.dataset_version;

CREATE TABLE IF NOT EXISTS vocab_items (
  id TEXT PRIMARY KEY,
  lesson_id TEXT NOT NULL REFERENCES course_lessons(id) ON DELETE CASCADE,
  simplified_chinese TEXT NOT NULL,
  pinyin TEXT NOT NULL,
  english_meaning TEXT NOT NULL,
  part_of_speech TEXT NOT NULL DEFAULT '',
  source_id UUID REFERENCES content_sources(id),
  review_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (review_status IN ('pending', 'approved', 'corrected', 'rejected')),
  sequence INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS examples (
  id TEXT PRIMARY KEY,
  lesson_id TEXT NOT NULL REFERENCES course_lessons(id) ON DELETE CASCADE,
  chinese TEXT NOT NULL,
  pinyin TEXT NOT NULL,
  english TEXT NOT NULL,
  source_id UUID REFERENCES content_sources(id),
  review_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (review_status IN ('pending', 'approved', 'corrected', 'rejected')),
  sequence INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS grammar_patterns (
  id TEXT PRIMARY KEY,
  lesson_id TEXT NOT NULL REFERENCES course_lessons(id) ON DELETE CASCADE,
  pattern TEXT NOT NULL,
  explanation TEXT NOT NULL,
  chinese TEXT NOT NULL,
  pinyin TEXT NOT NULL,
  english TEXT NOT NULL,
  source_id UUID REFERENCES content_sources(id),
  review_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (review_status IN ('pending', 'approved', 'corrected', 'rejected'))
);

CREATE TABLE IF NOT EXISTS dialogues (
  id TEXT PRIMARY KEY,
  lesson_id TEXT NOT NULL REFERENCES course_lessons(id) ON DELETE CASCADE,
  speaker TEXT NOT NULL,
  chinese TEXT NOT NULL,
  pinyin TEXT NOT NULL,
  english TEXT NOT NULL,
  source_id UUID REFERENCES content_sources(id),
  review_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (review_status IN ('pending', 'approved', 'corrected', 'rejected')),
  sequence INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS activities (
  id TEXT PRIMARY KEY,
  lesson_id TEXT NOT NULL REFERENCES course_lessons(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('listen_tap', 'match', 'mcq', 'fill_blank')),
  prompt TEXT NOT NULL,
  answer TEXT NOT NULL,
  distractors JSONB NOT NULL DEFAULT '[]',
  explanation TEXT NOT NULL DEFAULT '',
  difficulty INTEGER NOT NULL DEFAULT 1 CHECK (difficulty BETWEEN 1 AND 5),
  source_id UUID REFERENCES content_sources(id),
  review_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (review_status IN ('pending', 'approved', 'corrected', 'rejected')),
  sequence INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS assessment_items (
  id TEXT PRIMARY KEY,
  lesson_id TEXT NOT NULL REFERENCES course_lessons(id) ON DELETE CASCADE,
  question TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('listen_tap', 'match', 'mcq', 'fill_blank')),
  correct_answer TEXT NOT NULL,
  distractors JSONB NOT NULL DEFAULT '[]',
  explanation TEXT NOT NULL,
  source_id UUID REFERENCES content_sources(id),
  review_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (review_status IN ('pending', 'approved', 'corrected', 'rejected')),
  sequence INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS audio_clips (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  lesson_id TEXT NOT NULL REFERENCES course_lessons(id) ON DELETE CASCADE,
  item_type TEXT NOT NULL,
  item_id TEXT NOT NULL,
  audio_text TEXT NOT NULL,
  speech_lang TEXT NOT NULL DEFAULT 'zh-CN',
  audio_url TEXT,
  voice TEXT,
  provider TEXT,
  source_id UUID REFERENCES content_sources(id),
  review_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (review_status IN ('pending', 'approved', 'corrected', 'rejected'))
);

CREATE TABLE IF NOT EXISTS curriculum_constraints (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  course_id TEXT NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  tag TEXT NOT NULL,
  description TEXT NOT NULL,
  level TEXT NOT NULL DEFAULT 'beginner',
  vocabulary_or_character TEXT,
  grammar_point TEXT,
  language_function TEXT,
  listening_competency TEXT,
  speaking_competency TEXT,
  reading_competency TEXT,
  writing_competency TEXT,
  source_id UUID NOT NULL REFERENCES content_sources(id),
  verification_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (verification_status IN ('pending', 'verified', 'rejected')),
  UNIQUE(course_id, tag)
);

CREATE TABLE IF NOT EXISTS staged_sentences (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  simplified_chinese TEXT NOT NULL,
  pinyin TEXT,
  english_translation TEXT NOT NULL,
  estimated_level TEXT NOT NULL DEFAULT 'beginner',
  source_id UUID NOT NULL REFERENCES content_sources(id),
  review_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (review_status IN ('pending', 'approved', 'corrected', 'rejected')),
  imported_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS speech_assets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  transcript TEXT NOT NULL,
  audio_url TEXT NOT NULL,
  language_code TEXT NOT NULL DEFAULT 'zh-CN',
  intended_use TEXT NOT NULL DEFAULT 'asr_evaluation'
    CHECK (intended_use IN ('asr_evaluation', 'pronunciation_research')),
  source_id UUID NOT NULL REFERENCES content_sources(id),
  review_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (review_status IN ('pending', 'approved', 'corrected', 'rejected'))
);

CREATE TABLE IF NOT EXISTS tts_provider_evaluations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  provider TEXT NOT NULL CHECK (provider IN ('google', 'azure')),
  voice TEXT NOT NULL,
  test_text TEXT NOT NULL,
  pronunciation_score INTEGER CHECK (pronunciation_score BETWEEN 1 AND 5),
  tone_score INTEGER CHECK (tone_score BETWEEN 1 AND 5),
  naturalness_score INTEGER CHECK (naturalness_score BETWEEN 1 AND 5),
  latency_ms INTEGER,
  estimated_cost NUMERIC,
  reviewer_id UUID REFERENCES auth.users(id),
  notes TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS review_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  item_type TEXT NOT NULL,
  item_id TEXT NOT NULL,
  reviewer_id UUID NOT NULL REFERENCES auth.users(id),
  verdict TEXT NOT NULL CHECK (verdict IN ('approved', 'corrected', 'rejected')),
  notes TEXT NOT NULL DEFAULT '',
  version INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS lesson_results (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  lesson_id TEXT NOT NULL REFERENCES course_lessons(id) ON DELETE CASCADE,
  score INTEGER NOT NULL CHECK (score BETWEEN 0 AND 100),
  answers JSONB NOT NULL DEFAULT '[]',
  completed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, lesson_id)
);

CREATE INDEX IF NOT EXISTS idx_course_lessons_course_sequence
  ON course_lessons(course_id, sequence);
CREATE INDEX IF NOT EXISTS idx_lesson_results_user
  ON lesson_results(user_id, completed_at DESC);

ALTER TABLE courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE course_modules ENABLE ROW LEVEL SECURITY;
ALTER TABLE course_lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE vocab_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE examples ENABLE ROW LEVEL SECURITY;
ALTER TABLE grammar_patterns ENABLE ROW LEVEL SECURITY;
ALTER TABLE dialogues ENABLE ROW LEVEL SECURITY;
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE assessment_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE audio_clips ENABLE ROW LEVEL SECURITY;
ALTER TABLE curriculum_constraints ENABLE ROW LEVEL SECURITY;
ALTER TABLE content_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE staged_sentences ENABLE ROW LEVEL SECURITY;
ALTER TABLE speech_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE tts_provider_evaluations ENABLE ROW LEVEL SECURITY;
ALTER TABLE review_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE lesson_results ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users read course metadata"
  ON courses FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users read module metadata"
  ON course_modules FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users read content provenance"
  ON content_sources FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users read curriculum fences"
  ON curriculum_constraints FOR SELECT TO authenticated USING (true);
CREATE POLICY "Reviewers manage staged sentences"
  ON staged_sentences FOR ALL TO authenticated
  USING (public.current_user_role() = 'reviewer')
  WITH CHECK (public.current_user_role() = 'reviewer');
CREATE POLICY "Reviewers manage speech research assets"
  ON speech_assets FOR ALL TO authenticated
  USING (public.current_user_role() = 'reviewer')
  WITH CHECK (public.current_user_role() = 'reviewer');
CREATE POLICY "Reviewers manage TTS evaluations"
  ON tts_provider_evaluations FOR ALL TO authenticated
  USING (public.current_user_role() = 'reviewer')
  WITH CHECK (public.current_user_role() = 'reviewer');
CREATE POLICY "Students read approved lesson metadata"
  ON course_lessons FOR SELECT TO authenticated
  USING (
    status IN ('shell', 'approved')
    OR public.current_user_role() IN ('teacher', 'reviewer')
  );

CREATE POLICY "Students read approved vocabulary"
  ON vocab_items FOR SELECT TO authenticated
  USING (
    review_status IN ('approved', 'corrected')
    AND EXISTS (SELECT 1 FROM course_lessons l WHERE l.id = lesson_id AND l.status = 'approved')
    OR public.current_user_role() = 'reviewer'
  );
CREATE POLICY "Students read approved examples"
  ON examples FOR SELECT TO authenticated
  USING (
    review_status IN ('approved', 'corrected')
    AND EXISTS (SELECT 1 FROM course_lessons l WHERE l.id = lesson_id AND l.status = 'approved')
    OR public.current_user_role() = 'reviewer'
  );
CREATE POLICY "Students read approved grammar"
  ON grammar_patterns FOR SELECT TO authenticated
  USING (
    review_status IN ('approved', 'corrected')
    AND EXISTS (SELECT 1 FROM course_lessons l WHERE l.id = lesson_id AND l.status = 'approved')
    OR public.current_user_role() = 'reviewer'
  );
CREATE POLICY "Students read approved dialogues"
  ON dialogues FOR SELECT TO authenticated
  USING (
    review_status IN ('approved', 'corrected')
    AND EXISTS (SELECT 1 FROM course_lessons l WHERE l.id = lesson_id AND l.status = 'approved')
    OR public.current_user_role() = 'reviewer'
  );
CREATE POLICY "Students read approved activities"
  ON activities FOR SELECT TO authenticated
  USING (
    review_status IN ('approved', 'corrected')
    AND EXISTS (SELECT 1 FROM course_lessons l WHERE l.id = lesson_id AND l.status = 'approved')
    OR public.current_user_role() = 'reviewer'
  );
CREATE POLICY "Students read approved assessments"
  ON assessment_items FOR SELECT TO authenticated
  USING (
    review_status IN ('approved', 'corrected')
    AND EXISTS (SELECT 1 FROM course_lessons l WHERE l.id = lesson_id AND l.status = 'approved')
    OR public.current_user_role() = 'reviewer'
  );
CREATE POLICY "Students read approved audio"
  ON audio_clips FOR SELECT TO authenticated
  USING (
    review_status IN ('approved', 'corrected')
    AND EXISTS (SELECT 1 FROM course_lessons l WHERE l.id = lesson_id AND l.status = 'approved')
    OR public.current_user_role() = 'reviewer'
  );

CREATE POLICY "Reviewers manage lesson content"
  ON course_lessons FOR ALL TO authenticated
  USING (public.current_user_role() = 'reviewer')
  WITH CHECK (public.current_user_role() = 'reviewer');
CREATE POLICY "Reviewers record review events"
  ON review_events FOR INSERT TO authenticated
  WITH CHECK (public.current_user_role() = 'reviewer' AND reviewer_id = auth.uid());
CREATE POLICY "Reviewers read review events"
  ON review_events FOR SELECT TO authenticated
  USING (public.current_user_role() = 'reviewer');

CREATE POLICY "Users manage own Foundation results"
  ON lesson_results FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
CREATE POLICY "Teachers read class Foundation results"
  ON lesson_results FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM class_members cm
      JOIN classes c ON c.id = cm.class_id
      WHERE cm.user_id = lesson_results.user_id
        AND c.teacher_id = auth.uid()
    )
  );

CREATE OR REPLACE FUNCTION public.complete_foundation_lesson(
  p_lesson_id TEXT,
  p_score INTEGER,
  p_answers JSONB,
  p_xp_reward INTEGER DEFAULT 100,
  p_minutes INTEGER DEFAULT 10
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_inserted INTEGER;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM course_lessons
    WHERE id = p_lesson_id AND status = 'approved'
  ) THEN
    RAISE EXCEPTION 'LESSON_NOT_APPROVED';
  END IF;

  INSERT INTO lesson_results (user_id, lesson_id, score, answers)
  VALUES (v_uid, p_lesson_id, greatest(0, least(100, p_score)), COALESCE(p_answers, '[]'))
  ON CONFLICT (user_id, lesson_id) DO NOTHING;
  GET DIAGNOSTICS v_inserted = ROW_COUNT;

  IF v_inserted = 1 THEN
    PERFORM public.award_xp(v_uid, greatest(0, p_xp_reward), 'Foundation lesson completed', NULL);
    PERFORM public.update_user_streak(v_uid);
    UPDATE user_profiles
    SET lessons_completed = lessons_completed + 1,
        minutes_learned = minutes_learned + greatest(1, p_minutes),
        updated_at = NOW()
    WHERE user_id = v_uid;
  ELSE
    UPDATE lesson_results
    SET score = greatest(score, greatest(0, least(100, p_score))),
        answers = CASE WHEN p_score >= score THEN COALESCE(p_answers, answers) ELSE answers END,
        completed_at = NOW()
    WHERE user_id = v_uid AND lesson_id = p_lesson_id;
  END IF;

  RETURN v_inserted = 1;
END;
$$;

REVOKE ALL ON FUNCTION public.complete_foundation_lesson(TEXT, INTEGER, JSONB, INTEGER, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.complete_foundation_lesson(TEXT, INTEGER, JSONB, INTEGER, INTEGER)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.review_foundation_item(
  p_item_type TEXT,
  p_item_id TEXT,
  p_verdict TEXT,
  p_notes TEXT DEFAULT '',
  p_corrections JSONB DEFAULT '{}'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status TEXT;
BEGIN
  IF public.current_user_role() <> 'reviewer' THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;
  IF p_verdict NOT IN ('approved', 'corrected', 'rejected') THEN
    RAISE EXCEPTION 'INVALID_VERDICT';
  END IF;
  v_status := p_verdict;

  CASE p_item_type
    WHEN 'lesson' THEN
      UPDATE course_lessons SET
        title = COALESCE(p_corrections->>'title', title),
        objective = COALESCE(p_corrections->>'objective', objective),
        explanation = COALESCE(p_corrections->>'explanation', explanation),
        status = CASE WHEN p_verdict IN ('approved', 'corrected') THEN 'approved' ELSE 'ready' END,
        updated_at = NOW()
      WHERE id = p_item_id;
    WHEN 'vocab' THEN
      UPDATE vocab_items SET
        simplified_chinese = COALESCE(p_corrections->>'chinese', simplified_chinese),
        pinyin = COALESCE(p_corrections->>'pinyin', pinyin),
        english_meaning = COALESCE(p_corrections->>'english', english_meaning),
        review_status = v_status
      WHERE id = p_item_id;
    WHEN 'dialogue' THEN
      UPDATE dialogues SET
        chinese = COALESCE(p_corrections->>'chinese', chinese),
        pinyin = COALESCE(p_corrections->>'pinyin', pinyin),
        english = COALESCE(p_corrections->>'english', english),
        review_status = v_status
      WHERE id = p_item_id;
    WHEN 'activity' THEN
      UPDATE activities SET
        prompt = COALESCE(p_corrections->>'prompt', prompt),
        answer = COALESCE(p_corrections->>'answer', answer),
        explanation = COALESCE(p_corrections->>'explanation', explanation),
        review_status = v_status
      WHERE id = p_item_id;
    WHEN 'assessment' THEN
      UPDATE assessment_items SET
        question = COALESCE(p_corrections->>'question', question),
        correct_answer = COALESCE(p_corrections->>'answer', correct_answer),
        explanation = COALESCE(p_corrections->>'explanation', explanation),
        review_status = v_status
      WHERE id = p_item_id;
    ELSE
      RAISE EXCEPTION 'INVALID_ITEM_TYPE';
  END CASE;

  IF NOT FOUND THEN RAISE EXCEPTION 'ITEM_NOT_FOUND'; END IF;

  INSERT INTO review_events (item_type, item_id, reviewer_id, verdict, notes)
  VALUES (p_item_type, p_item_id, auth.uid(), p_verdict, COALESCE(p_notes, ''));
END;
$$;

REVOKE ALL ON FUNCTION public.review_foundation_item(TEXT, TEXT, TEXT, TEXT, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.review_foundation_item(TEXT, TEXT, TEXT, TEXT, JSONB)
  TO authenticated;

INSERT INTO courses (id, title, level, target_age)
VALUES ('mandarin_foundation_v1', 'Mandarin Foundation', 'Complete beginner', '7–12')
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title;

INSERT INTO course_modules (course_id, sequence, title, subtitle)
VALUES
  ('mandarin_foundation_v1', 1, 'First Contact', 'Hear Mandarin, understand tones, and say hello.'),
  ('mandarin_foundation_v1', 2, 'My World', 'Talk about yourself and the world around you.'),
  ('mandarin_foundation_v1', 3, 'Everyday Mandarin', 'Use Mandarin in everyday situations.')
ON CONFLICT (course_id, sequence) DO UPDATE
SET title = EXCLUDED.title, subtitle = EXCLUDED.subtitle;

INSERT INTO course_lessons
  (id, course_id, module_sequence, sequence, title, objective, explanation, status, xp_reward)
VALUES
  ('mfv1_l01','mandarin_foundation_v1',1,1,'Welcome to Mandarin','Recognise Mandarin and use a first greeting.','Chinese characters show meaning. Pinyin helps us learn how Mandarin sounds.','approved',100),
  ('mfv1_l02','mandarin_foundation_v1',1,2,'Understanding the Four Tones','Hear and identify Mandarin’s four main tones.','A tone is the shape your voice makes. Mandarin has level, rising, dipping, and falling tones.','approved',100),
  ('mfv1_l03','mandarin_foundation_v1',1,3,'Hello!','Greet a friend or teacher and say goodbye.','Use 你好 with most people, 您好 as a respectful hello, and 老师好 for a teacher.','approved',120),
  ('mfv1_l04','mandarin_foundation_v1',1,4,'What Is Your Name?','Ask someone’s name.','','shell',100),
  ('mfv1_l05','mandarin_foundation_v1',1,5,'Introducing Yourself','Say your name and introduce yourself.','','shell',100),
  ('mfv1_l06','mandarin_foundation_v1',1,6,'Yes and No','Respond with 是 and 不是.','','shell',100),
  ('mfv1_l07','mandarin_foundation_v1',1,7,'Numbers 1–5','Count from one to five.','','shell',100),
  ('mfv1_l08','mandarin_foundation_v1',1,8,'Numbers 6–10','Count from six to ten.','','shell',100),
  ('mfv1_l09','mandarin_foundation_v1',1,9,'How Old Are You?','Ask and answer about age.','','shell',100),
  ('mfv1_l10','mandarin_foundation_v1',1,10,'Module 1 Quest — Review and Assessment','Use Module 1 language in a short quest.','','shell',150),
  ('mfv1_l11','mandarin_foundation_v1',2,11,'My Family','Name close family members.','','shell',100),
  ('mfv1_l12','mandarin_foundation_v1',2,12,'This Is My…','Introduce a person or belonging.','','shell',100),
  ('mfv1_l13','mandarin_foundation_v1',2,13,'My School','Talk about school.','','shell',100),
  ('mfv1_l14','mandarin_foundation_v1',2,14,'Things in My Classroom','Name common classroom objects.','','shell',100),
  ('mfv1_l15','mandarin_foundation_v1',2,15,'Colours','Recognise and name basic colours.','','shell',100),
  ('mfv1_l16','mandarin_foundation_v1',2,16,'What Is This?','Ask and answer what an object is.','','shell',100),
  ('mfv1_l17','mandarin_foundation_v1',2,17,'Food and Drinks','Name beginner foods and drinks.','','shell',100),
  ('mfv1_l18','mandarin_foundation_v1',2,18,'I Like…','Say what you like.','','shell',100),
  ('mfv1_l19','mandarin_foundation_v1',2,19,'I Don’t Like…','Say what you do not like.','','shell',100),
  ('mfv1_l20','mandarin_foundation_v1',2,20,'Module 2 Quest — Review and Assessment','Combine Module 2 language in a quest.','','shell',150),
  ('mfv1_l21','mandarin_foundation_v1',3,21,'Good Morning and Other Greetings','Use greetings for different moments.','','shell',100),
  ('mfv1_l22','mandarin_foundation_v1',3,22,'Today and Tomorrow','Talk about today and tomorrow.','','shell',100),
  ('mfv1_l23','mandarin_foundation_v1',3,23,'Days of the Week','Name the days of the week.','','shell',100),
  ('mfv1_l24','mandarin_foundation_v1',3,24,'Where Are You Going?','Ask and say where someone is going.','','shell',100),
  ('mfv1_l25','mandarin_foundation_v1',3,25,'Home, School and Other Places','Name familiar places.','','shell',100),
  ('mfv1_l26','mandarin_foundation_v1',3,26,'Come, Go, Eat and Drink','Use four everyday action verbs.','','shell',100),
  ('mfv1_l27','mandarin_foundation_v1',3,27,'I Can…','Say what you can do.','','shell',100),
  ('mfv1_l28','mandarin_foundation_v1',3,28,'Please, Thank You and You’re Welcome','Use essential polite phrases.','','shell',100),
  ('mfv1_l29','mandarin_foundation_v1',3,29,'My First Mandarin Conversation','Combine greetings and familiar language.','','shell',100),
  ('mfv1_l30','mandarin_foundation_v1',3,30,'Mandarin Foundation Quest — Final Assessment','Complete the final Foundation conversation.','','shell',200)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  objective = EXCLUDED.objective,
  explanation = EXCLUDED.explanation,
  status = EXCLUDED.status;

INSERT INTO vocab_items
  (id, lesson_id, simplified_chinese, pinyin, english_meaning, part_of_speech, review_status, sequence)
VALUES
  ('l1v1','mfv1_l01','你好','nǐ hǎo','hello','greeting','approved',1),
  ('l1v2','mfv1_l01','中文','Zhōngwén','Chinese language','noun','approved',2),
  ('l1v3','mfv1_l01','听','tīng','listen','verb','approved',3),
  ('l1v4','mfv1_l01','说','shuō','speak','verb','approved',4),
  ('l1v5','mfv1_l01','我','wǒ','I / me','pronoun','approved',5),
  ('l2v1','mfv1_l02','妈','mā','mum — first tone','','approved',1),
  ('l2v2','mfv1_l02','麻','má','hemp — second tone','','approved',2),
  ('l2v3','mfv1_l02','马','mǎ','horse — third tone','','approved',3),
  ('l2v4','mfv1_l02','骂','mà','scold — fourth tone','','approved',4),
  ('l3v1','mfv1_l03','你好','nǐ hǎo','hello','greeting','approved',1),
  ('l3v2','mfv1_l03','您好','nín hǎo','hello (respectful)','greeting','approved',2),
  ('l3v3','mfv1_l03','老师好','lǎoshī hǎo','hello, teacher','greeting','approved',3),
  ('l3v4','mfv1_l03','再见','zàijiàn','goodbye','greeting','approved',4)
ON CONFLICT (id) DO UPDATE SET
  simplified_chinese = EXCLUDED.simplified_chinese,
  pinyin = EXCLUDED.pinyin,
  english_meaning = EXCLUDED.english_meaning,
  review_status = EXCLUDED.review_status;

INSERT INTO dialogues
  (id, lesson_id, speaker, chinese, pinyin, english, review_status, sequence)
VALUES
  ('l3d1','mfv1_l03','Mei','老师好！','Lǎoshī hǎo!','Hello, teacher!','approved',1),
  ('l3d2','mfv1_l03','Teacher','你好！','Nǐ hǎo!','Hello!','approved',2),
  ('l3d3','mfv1_l03','Mei','再见！','Zàijiàn!','Goodbye!','approved',3)
ON CONFLICT (id) DO UPDATE SET
  chinese = EXCLUDED.chinese, pinyin = EXCLUDED.pinyin,
  english = EXCLUDED.english, review_status = EXCLUDED.review_status;

INSERT INTO activities
  (id, lesson_id, type, prompt, answer, distractors, explanation, review_status, sequence)
VALUES
  ('l1a1','mfv1_l01','listen_tap','Listen and tap “hello”.','你好','["中文","听"]','你好 means hello.','approved',1),
  ('l1a2','mfv1_l01','match','Match the action to its meaning.','听 = listen','["说 = listen","中文 = speak"]','听 means listen; 说 means speak.','approved',2),
  ('l2a1','mfv1_l02','listen_tap','Listen for the falling fourth tone.','mà','["mā","má","mǎ"]','The fourth tone falls sharply.','approved',1),
  ('l2a2','mfv1_l02','match','Match the tone shape.','mǎ = dip','["mǎ = level","mǎ = falling"]','The third tone dips.','approved',2),
  ('l3a1','mfv1_l03','listen_tap','Choose the respectful greeting.','您好','["你好","再见"]','您好 is respectful.','approved',1),
  ('l3a2','mfv1_l03','fill_blank','老师___','好','["见","您"]','老师好 means hello, teacher.','approved',2)
ON CONFLICT (id) DO UPDATE SET
  prompt = EXCLUDED.prompt, answer = EXCLUDED.answer,
  distractors = EXCLUDED.distractors, review_status = EXCLUDED.review_status;

INSERT INTO assessment_items
  (id, lesson_id, question, type, correct_answer, distractors, explanation, review_status, sequence)
VALUES
  ('l1q1','mfv1_l01','Which word means “hello”?','mcq','你好','["中文","我"]','你好 means hello.','approved',1),
  ('l1q2','mfv1_l01','What does 中文 mean?','mcq','Chinese language','["listen","hello"]','中文 is the Chinese language.','approved',2),
  ('l1q3','mfv1_l01','Tap the word for “listen”.','listen_tap','听','["说","我"]','听 means listen.','approved',3),
  ('l1q4','mfv1_l01','Which word means “speak”?','mcq','说','["听","中文"]','说 means speak.','approved',4),
  ('l1q5','mfv1_l01','Complete: nǐ hǎo = ____','fill_blank','hello','["goodbye","thank you"]','nǐ hǎo is hello.','approved',5),
  ('l2q1','mfv1_l02','Which Pinyin has the level first tone?','mcq','mā','["má","mǎ","mà"]','The macron shows a level tone.','approved',1),
  ('l2q2','mfv1_l02','Which tone rises?','mcq','má','["mā","mǎ","mà"]','The acute mark rises.','approved',2),
  ('l2q3','mfv1_l02','Which tone dips?','mcq','mǎ','["mā","má","mà"]','The caron marks the dip.','approved',3),
  ('l2q4','mfv1_l02','Which tone falls sharply?','mcq','mà','["mā","má","mǎ"]','The grave mark falls.','approved',4),
  ('l2q5','mfv1_l02','Why do tones matter?','mcq','They can change meaning','["They change the alphabet","They are decoration"]','Tone can change meaning.','approved',5),
  ('l3q1','mfv1_l03','How do you say hello?','mcq','你好','["再见","中文"]','你好 means hello.','approved',1),
  ('l3q2','mfv1_l03','Which greeting is respectful?','mcq','您好','["你好","再见"]','您好 uses respectful 您.','approved',2),
  ('l3q3','mfv1_l03','How do you greet a teacher?','mcq','老师好','["老师见","您好见"]','老师好 means hello, teacher.','approved',3),
  ('l3q4','mfv1_l03','What does 再见 mean?','mcq','goodbye','["hello","teacher"]','再见 means goodbye.','approved',4),
  ('l3q5','mfv1_l03','Complete: zàijiàn = ____','fill_blank','goodbye','["hello","please"]','zàijiàn is goodbye.','approved',5)
ON CONFLICT (id) DO UPDATE SET
  question = EXCLUDED.question, correct_answer = EXCLUDED.correct_answer,
  distractors = EXCLUDED.distractors, explanation = EXCLUDED.explanation,
  review_status = EXCLUDED.review_status;

UPDATE vocab_items
SET source_id = 'f1000000-0000-4000-8000-000000000001'
WHERE source_id IS NULL;
UPDATE dialogues
SET source_id = 'f1000000-0000-4000-8000-000000000001'
WHERE source_id IS NULL;
UPDATE activities
SET source_id = 'f1000000-0000-4000-8000-000000000001'
WHERE source_id IS NULL;
UPDATE assessment_items
SET source_id = 'f1000000-0000-4000-8000-000000000001'
WHERE source_id IS NULL;

ALTER TABLE vocab_items ALTER COLUMN source_id SET NOT NULL;
ALTER TABLE examples ALTER COLUMN source_id SET NOT NULL;
ALTER TABLE grammar_patterns ALTER COLUMN source_id SET NOT NULL;
ALTER TABLE dialogues ALTER COLUMN source_id SET NOT NULL;
ALTER TABLE activities ALTER COLUMN source_id SET NOT NULL;
ALTER TABLE assessment_items ALTER COLUMN source_id SET NOT NULL;

INSERT INTO curriculum_constraints
  (course_id, tag, description, language_function, source_id, verification_status)
VALUES
  ('mandarin_foundation_v1','beginner-reviewed','Only reviewer-approved beginner Mandarin may reach learners.','Quality gate for beginner language','f1000000-0000-4000-8000-000000000001','verified'),
  ('mandarin_foundation_v1','no-new-chinese','Generation may not introduce Chinese outside the approved lesson pack.','Constrained generation','f1000000-0000-4000-8000-000000000001','verified'),
  ('mandarin_foundation_v1','pinyin-preserved','Generation must preserve supplied characters and Pinyin exactly.','Orthographic fidelity','f1000000-0000-4000-8000-000000000001','verified')
ON CONFLICT (course_id, tag) DO UPDATE SET description = EXCLUDED.description;

INSERT INTO audio_clips
  (lesson_id, item_type, item_id, audio_text, speech_lang, audio_url, provider, source_id, review_status)
SELECT
  vocab.lesson_id, 'vocab', vocab.id, vocab.simplified_chinese,
  'zh-CN', NULL, 'device_tts', 'f1000000-0000-4000-8000-000000000001', 'approved'
FROM vocab_items vocab
WHERE vocab.lesson_id IN ('mfv1_l01', 'mfv1_l02', 'mfv1_l03')
  AND NOT EXISTS (
    SELECT 1 FROM audio_clips clip
    WHERE clip.item_type = 'vocab' AND clip.item_id = vocab.id
  );

INSERT INTO audio_clips
  (lesson_id, item_type, item_id, audio_text, speech_lang, audio_url, provider, source_id, review_status)
SELECT
  line.lesson_id, 'dialogue', line.id, line.chinese,
  'zh-CN', NULL, 'device_tts', 'f1000000-0000-4000-8000-000000000001', 'approved'
FROM dialogues line
WHERE line.lesson_id = 'mfv1_l03'
  AND NOT EXISTS (
    SELECT 1 FROM audio_clips clip
    WHERE clip.item_type = 'dialogue' AND clip.item_id = line.id
  );

ALTER TABLE audio_clips ALTER COLUMN source_id SET NOT NULL;


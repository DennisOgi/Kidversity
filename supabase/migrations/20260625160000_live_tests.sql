-- Live timed tests with realtime participant + answer tracking

CREATE TABLE IF NOT EXISTS live_tests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  teacher_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  class_id UUID REFERENCES classes(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  subject TEXT NOT NULL DEFAULT 'General',
  duration_seconds INTEGER NOT NULL DEFAULT 300 CHECK (duration_seconds >= 60),
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'live', 'ended')),
  join_code TEXT UNIQUE,
  started_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_live_tests_teacher ON live_tests(teacher_id);
CREATE INDEX IF NOT EXISTS idx_live_tests_status ON live_tests(status);
CREATE INDEX IF NOT EXISTS idx_live_tests_class ON live_tests(class_id);

CREATE TABLE IF NOT EXISTS live_test_questions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  test_id UUID REFERENCES live_tests(id) ON DELETE CASCADE NOT NULL,
  order_index INTEGER NOT NULL DEFAULT 0,
  prompt TEXT NOT NULL,
  options JSONB NOT NULL DEFAULT '[]',
  points INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_live_test_questions_test ON live_test_questions(test_id);

CREATE TABLE IF NOT EXISTS live_test_participants (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  test_id UUID REFERENCES live_tests(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  display_name TEXT,
  avatar_emoji TEXT DEFAULT '🦊',
  status TEXT NOT NULL DEFAULT 'waiting' CHECK (status IN ('waiting', 'active', 'submitted')),
  score INTEGER NOT NULL DEFAULT 0,
  correct_count INTEGER NOT NULL DEFAULT 0,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  submitted_at TIMESTAMPTZ,
  UNIQUE(test_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_live_test_participants_test ON live_test_participants(test_id);

CREATE TABLE IF NOT EXISTS live_test_answers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  test_id UUID REFERENCES live_tests(id) ON DELETE CASCADE NOT NULL,
  question_id UUID REFERENCES live_test_questions(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  selected_option_id TEXT,
  is_correct BOOLEAN NOT NULL DEFAULT false,
  answered_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(test_id, question_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_live_test_answers_test ON live_test_answers(test_id);

ALTER TABLE live_tests ENABLE ROW LEVEL SECURITY;
ALTER TABLE live_test_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE live_test_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE live_test_answers ENABLE ROW LEVEL SECURITY;

-- Teachers manage own tests
DROP POLICY IF EXISTS "Teachers manage own live tests" ON live_tests;
CREATE POLICY "Teachers manage own live tests"
  ON live_tests FOR ALL
  USING (auth.uid() = teacher_id)
  WITH CHECK (auth.uid() = teacher_id);

-- Class members + teachers can read live/ended tests
DROP POLICY IF EXISTS "Students read live tests for their class" ON live_tests;
CREATE POLICY "Students read live tests for their class"
  ON live_tests FOR SELECT
  USING (
    auth.uid() = teacher_id OR (
      status IN ('live', 'ended') AND class_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM class_members cm
        WHERE cm.class_id = live_tests.class_id AND cm.user_id = auth.uid()
      )
    )
  );

DROP POLICY IF EXISTS "Teachers manage test questions" ON live_test_questions;
CREATE POLICY "Teachers manage test questions"
  ON live_test_questions FOR ALL
  USING (EXISTS (SELECT 1 FROM live_tests t WHERE t.id = test_id AND t.teacher_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM live_tests t WHERE t.id = test_id AND t.teacher_id = auth.uid()));

DROP POLICY IF EXISTS "Participants read test questions" ON live_test_questions;
CREATE POLICY "Participants read test questions"
  ON live_test_questions FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM live_tests t
    WHERE t.id = test_id AND t.status IN ('live', 'ended')
      AND (t.teacher_id = auth.uid() OR EXISTS (
        SELECT 1 FROM class_members cm WHERE cm.class_id = t.class_id AND cm.user_id = auth.uid()
      ))
  ));

DROP POLICY IF EXISTS "Teachers read all participants" ON live_test_participants;
CREATE POLICY "Teachers read all participants"
  ON live_test_participants FOR SELECT
  USING (EXISTS (SELECT 1 FROM live_tests t WHERE t.id = test_id AND t.teacher_id = auth.uid()));

DROP POLICY IF EXISTS "Students manage own participation" ON live_test_participants;
CREATE POLICY "Students manage own participation"
  ON live_test_participants FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Teachers read all answers" ON live_test_answers;
CREATE POLICY "Teachers read all answers"
  ON live_test_answers FOR SELECT
  USING (EXISTS (SELECT 1 FROM live_tests t WHERE t.id = test_id AND t.teacher_id = auth.uid()));

DROP POLICY IF EXISTS "Students manage own answers" ON live_test_answers;
CREATE POLICY "Students manage own answers"
  ON live_test_answers FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Realtime
ALTER TABLE live_tests REPLICA IDENTITY FULL;
ALTER TABLE live_test_participants REPLICA IDENTITY FULL;
ALTER TABLE live_test_answers REPLICA IDENTITY FULL;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE live_tests;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE live_test_participants;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE live_test_answers;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

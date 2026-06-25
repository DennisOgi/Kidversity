-- Kidversity Database Schema
-- This schema should be executed in your Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================== User Profiles
CREATE TABLE user_profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
  display_name TEXT NOT NULL,
  avatar_emoji TEXT DEFAULT '🦊',
  level INTEGER DEFAULT 1,
  xp INTEGER DEFAULT 0,
  streak_days INTEGER DEFAULT 0,
  last_activity_date DATE,
  lessons_completed INTEGER DEFAULT 0,
  minutes_learned INTEGER DEFAULT 0,
  preferences JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ================================================================== Lessons
CREATE TABLE lessons (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  subject TEXT NOT NULL,
  description TEXT,
  source TEXT CHECK (source IN ('uploaded', 'ai_generated', 'hybrid')),
  status TEXT CHECK (status IN ('draft', 'published', 'assigned')) DEFAULT 'draft',
  author_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  author_name TEXT,
  color TEXT DEFAULT '#7C3AED',
  emoji TEXT DEFAULT '📘',
  grade_band_label INTEGER DEFAULT 5,
  xp_reward INTEGER DEFAULT 120,
  estimated_minutes INTEGER DEFAULT 10,
  slides JSONB DEFAULT '[]',
  checkpoints JSONB DEFAULT '[]',
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_lessons_status ON lessons(status);
CREATE INDEX idx_lessons_subject ON lessons(subject);
CREATE INDEX idx_lessons_author ON lessons(author_id);

-- ========================================================= Lesson Progress
CREATE TABLE lesson_progress (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  lesson_id UUID REFERENCES lessons(id) ON DELETE CASCADE NOT NULL,
  progress DECIMAL(3,2) DEFAULT 0 CHECK (progress >= 0 AND progress <= 1),
  slides_completed INTEGER DEFAULT 0,
  checkpoints_correct INTEGER DEFAULT 0,
  checkpoints_total INTEGER DEFAULT 0,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, lesson_id)
);

CREATE INDEX idx_progress_user ON lesson_progress(user_id);
CREATE INDEX idx_progress_lesson ON lesson_progress(lesson_id);

-- ====================================================== Lesson Assignments
CREATE TABLE lesson_assignments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  lesson_id UUID REFERENCES lessons(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  assigned_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  assigned_at TIMESTAMPTZ DEFAULT NOW(),
  due_date TIMESTAMPTZ,
  UNIQUE(lesson_id, user_id)
);

CREATE INDEX idx_assignments_user ON lesson_assignments(user_id);
CREATE INDEX idx_assignments_lesson ON lesson_assignments(lesson_id);

-- ================================================================ Badges
CREATE TABLE badges (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  emoji TEXT DEFAULT '🏆',
  color TEXT DEFAULT '#7C3AED',
  criteria JSONB NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =========================================================== User Badges
CREATE TABLE user_badges (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  badge_id UUID REFERENCES badges(id) ON DELETE CASCADE NOT NULL,
  progress DECIMAL(3,2) DEFAULT 0 CHECK (progress >= 0 AND progress <= 1),
  unlocked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, badge_id)
);

CREATE INDEX idx_user_badges_user ON user_badges(user_id);

-- ============================================================== Classes
CREATE TABLE classes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  teacher_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  description TEXT,
  grade_level INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_classes_teacher ON classes(teacher_id);

-- ======================================================== Class Members
CREATE TABLE class_members (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  class_id UUID REFERENCES classes(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(class_id, user_id)
);

CREATE INDEX idx_class_members_class ON class_members(class_id);
CREATE INDEX idx_class_members_user ON class_members(user_id);

-- =========================================================== File Storage
CREATE TABLE uploaded_files (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  filename TEXT NOT NULL,
  storage_path TEXT NOT NULL,
  mime_type TEXT,
  file_size INTEGER,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_uploaded_files_user ON uploaded_files(user_id);

-- ============================================================== XP Logs
CREATE TABLE xp_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  amount INTEGER NOT NULL,
  reason TEXT,
  lesson_id UUID REFERENCES lessons(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_xp_logs_user ON xp_logs(user_id);

-- ============================================================ Functions

-- Update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply update_updated_at trigger to relevant tables
CREATE TRIGGER update_user_profiles_updated_at
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_lessons_updated_at
  BEFORE UPDATE ON lessons
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_lesson_progress_updated_at
  BEFORE UPDATE ON lesson_progress
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_classes_updated_at
  BEFORE UPDATE ON classes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to award XP
CREATE OR REPLACE FUNCTION award_xp(
  p_user_id UUID,
  p_amount INTEGER,
  p_reason TEXT DEFAULT NULL,
  p_lesson_id UUID DEFAULT NULL
)
RETURNS void AS $$
DECLARE
  v_new_xp INTEGER;
  v_new_level INTEGER;
BEGIN
  -- Update user XP
  UPDATE user_profiles
  SET xp = xp + p_amount
  WHERE user_id = p_user_id
  RETURNING xp INTO v_new_xp;
  
  -- Log XP gain
  INSERT INTO xp_logs (user_id, amount, reason, lesson_id)
  VALUES (p_user_id, p_amount, p_reason, p_lesson_id);
  
  -- Calculate new level (every 500 XP = 1 level)
  v_new_level := FLOOR(v_new_xp / 500.0) + 1;
  
  -- Update level if changed
  UPDATE user_profiles
  SET level = v_new_level
  WHERE user_id = p_user_id AND level < v_new_level;
END;
$$ LANGUAGE plpgsql;

-- ========================================================= Row Level Security

-- Enable RLS on all tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE lesson_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE lesson_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE uploaded_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE xp_logs ENABLE ROW LEVEL SECURITY;

-- User Profiles: Users can read all profiles, but only update their own
CREATE POLICY "Public profiles are viewable by everyone"
  ON user_profiles FOR SELECT
  USING (true);

CREATE POLICY "Users can update own profile"
  ON user_profiles FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own profile"
  ON user_profiles FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Lessons: Published lessons viewable by all, drafts only by author
CREATE POLICY "Published lessons are viewable by everyone"
  ON lessons FOR SELECT
  USING (status = 'published' OR author_id = auth.uid());

CREATE POLICY "Authors can create lessons"
  ON lessons FOR INSERT
  WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Authors can update own lessons"
  ON lessons FOR UPDATE
  USING (auth.uid() = author_id);

-- Lesson Progress: Users can read/write their own progress
CREATE POLICY "Users can view own progress"
  ON lesson_progress FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own progress"
  ON lesson_progress FOR ALL
  USING (auth.uid() = user_id);

-- Lesson Assignments: Users can view their assignments
CREATE POLICY "Users can view own assignments"
  ON lesson_assignments FOR SELECT
  USING (auth.uid() = user_id OR auth.uid() = assigned_by);

-- User Badges: Users can view own badges
CREATE POLICY "Users can view own badges"
  ON user_badges FOR SELECT
  USING (auth.uid() = user_id);

-- Uploaded Files: Users can manage own files
CREATE POLICY "Users can view own files"
  ON uploaded_files FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can upload files"
  ON uploaded_files FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- XP Logs: Users can view own logs
CREATE POLICY "Users can view own XP logs"
  ON xp_logs FOR SELECT
  USING (auth.uid() = user_id);

-- ========================================================== Insert Sample Data

-- Insert default badges
INSERT INTO badges (name, description, emoji, color, criteria) VALUES
  ('First Steps', 'Completed your first lesson', '🎯', '#7C3AED', '{"lessons_completed": 1}'),
  ('7-Day Streak', 'Learned 7 days in a row', '🔥', '#EA580C', '{"streak_days": 7}'),
  ('Quiz Whiz', 'Scored 100% on 5 quizzes', '🧠', '#059669', '{"perfect_quizzes": 5}'),
  ('Polyglot', 'Finished a language course', '🌍', '#0284C7', '{"language_course_completed": 1}'),
  ('Math Master', 'Master 10 maths skills', '🏆', '#EAB308', '{"math_lessons_completed": 10}'),
  ('Early Bird', 'Study before 8am, 5 times', '🌅', '#DB2777', '{"early_morning_sessions": 5}');

COMMENT ON TABLE user_profiles IS 'User profile information and gamification stats';
COMMENT ON TABLE lessons IS 'Learning content with slides and checkpoints';
COMMENT ON TABLE lesson_progress IS 'User progress tracking for each lesson';
COMMENT ON TABLE lesson_assignments IS 'Teacher-assigned lessons to students';
COMMENT ON TABLE badges IS 'Achievement badges definitions';
COMMENT ON TABLE user_badges IS 'User badge unlocks and progress';
COMMENT ON TABLE classes IS 'Teacher classes/groups';
COMMENT ON TABLE class_members IS 'Students enrolled in classes';

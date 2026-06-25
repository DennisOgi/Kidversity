import '../models/models.dart';
import '../theme/app_colors.dart';

/// Static, in-memory content used to drive the UI.
///
/// Everything here is intentionally isolated so a real backend (e.g. Supabase)
/// + an LLM generation service can replace [MockData] without touching widgets.
class MockData {
  static const learner = LearnerProfile(
    name: 'Chioma',
    avatarEmoji: '🦊',
    level: 7,
    xp: 1840,
    xpToNextLevel: 2400,
    streakDays: 12,
    lessonsCompleted: 23,
    minutesLearned: 540,
  );

  static const mandarinFamily = Lesson(
    id: 'l1',
    title: 'Family Words in Mandarin',
    subject: 'Mandarin',
    description: 'Learn to say mum, dad, sister and more with native-style audio.',
    source: ContentSource.uploaded,
    status: LessonStatus.assigned,
    authorName: 'Mrs. Ade',
    color: AppColors.secondary,
    emoji: '👨‍👩‍👧',
    gradeBandLabel: 4,
    progress: 0.8,
    xpReward: 150,
    slides: [
      LessonSlide(
        id: 's1',
        title: '妈妈 — māma',
        body: 'This means "mum". Listen and repeat the rising-falling tones.',
        imageEmoji: '👩',
        caption: 'māma means mum. Tap play and repeat after me.',
        audioDuration: Duration(seconds: 16),
        speechText: '妈妈。māma。',
        speechLang: 'zh-CN',
      ),
      LessonSlide(
        id: 's2',
        title: '爸爸 — bàba',
        body: 'This means "dad". Notice the falling tone on the first syllable.',
        imageEmoji: '👨',
        caption: 'bàba means dad.',
        audioDuration: Duration(seconds: 15),
        speechText: '爸爸。bàba。',
        speechLang: 'zh-CN',
      ),
      LessonSlide(
        id: 's3',
        title: '姐姐 — jiějie',
        body: 'This means "older sister".',
        imageEmoji: '👧',
        caption: 'jiějie means older sister.',
        audioDuration: Duration(seconds: 14),
        aiVoice: true,
        speechText: '姐姐。jiějie。',
        speechLang: 'zh-CN',
      ),
    ],
    checkpoints: [
      Checkpoint(
        id: 'c1',
        type: CheckpointType.pronunciation,
        prompt: 'Hear "māma" — tap the correct character',
        audioPrompt: '妈妈',
        options: [
          QuizOption(id: 'o1', label: '妈妈', isCorrect: true),
          QuizOption(id: 'o2', label: '爸爸'),
          QuizOption(id: 'o3', label: '姐姐'),
        ],
      ),
      Checkpoint(
        id: 'c2',
        type: CheckpointType.multipleChoice,
        prompt: 'What does "bàba" mean?',
        hint: 'Think of the deeper voice in the family!',
        options: [
          QuizOption(id: 'o1', label: 'Mum'),
          QuizOption(id: 'o2', label: 'Dad', isCorrect: true),
          QuizOption(id: 'o3', label: 'Sister'),
          QuizOption(id: 'o4', label: 'Brother'),
        ],
      ),
    ],
  );

  static const mandarinNumbers = Lesson(
    id: 'l2',
    title: 'Numbers 1–10 in Mandarin',
    subject: 'Mandarin',
    description: 'AI-generated beginner lesson with characters, pinyin and a quiz.',
    source: ContentSource.aiGenerated,
    status: LessonStatus.published,
    authorName: 'Mr. Ibrahim',
    color: AppColors.primary,
    emoji: '🔢',
    gradeBandLabel: 3,
    progress: 0.35,
    xpReward: 120,
    slides: [
      LessonSlide(
        id: 's1', title: '一 — yī (one)', body: 'A single horizontal stroke.',
        imageEmoji: '1️⃣', caption: 'yī means one.', aiVoice: true,
        speechText: '一。yī。', speechLang: 'zh-CN'),
      LessonSlide(
        id: 's2', title: '二 — èr (two)', body: 'Two strokes stacked.',
        imageEmoji: '2️⃣', caption: 'èr means two.', aiVoice: true,
        speechText: '二。èr。', speechLang: 'zh-CN'),
      LessonSlide(
        id: 's3', title: '三 — sān (three)', body: 'Three horizontal strokes.',
        imageEmoji: '3️⃣', caption: 'sān means three.', aiVoice: true,
        speechText: '三。sān。', speechLang: 'zh-CN'),
    ],
    checkpoints: [
      Checkpoint(
        id: 'c1', type: CheckpointType.multipleChoice,
        prompt: 'Which character means "three"?',
        options: [
          QuizOption(id: 'o1', label: '一'),
          QuizOption(id: 'o2', label: '三', isCorrect: true),
          QuizOption(id: 'o3', label: '二'),
        ],
      ),
    ],
  );

  static const fractions = Lesson(
    id: 'l3',
    title: 'Introduction to Fractions',
    subject: 'Maths',
    description: 'Halves, thirds and quarters explained with pizza slices.',
    source: ContentSource.hybrid,
    status: LessonStatus.published,
    authorName: 'AI + Mr. Okoro',
    color: AppColors.accentTeal,
    emoji: '🍕',
    gradeBandLabel: 5,
    progress: 0.0,
    xpReward: 140,
    slides: [
      LessonSlide(id: 's1', title: 'What is a fraction?', body: 'A part of a whole.', imageEmoji: '🍕'),
      LessonSlide(id: 's2', title: 'One half', body: '1/2 means one of two equal parts.', imageEmoji: '🌗'),
    ],
    checkpoints: [
      Checkpoint(
        id: 'c1', type: CheckpointType.multipleChoice,
        prompt: 'If you eat 2 of 4 equal slices, what fraction did you eat?',
        options: [
          QuizOption(id: 'o1', label: '1/2', isCorrect: true),
          QuizOption(id: 'o2', label: '1/4'),
          QuizOption(id: 'o3', label: '3/4'),
        ],
      ),
    ],
  );

  static const solarSystem = Lesson(
    id: 'l4',
    title: 'Our Solar System',
    subject: 'Science',
    description: 'A tour of the eight planets with fun facts and narration.',
    source: ContentSource.aiGenerated,
    status: LessonStatus.published,
    authorName: 'AI Studio',
    color: AppColors.accentBlue,
    emoji: '🪐',
    gradeBandLabel: 6,
    progress: 1.0,
    xpReward: 160,
    slides: [
      LessonSlide(id: 's1', title: 'The Sun', body: 'A giant ball of hot plasma.', imageEmoji: '☀️', aiVoice: true),
      LessonSlide(id: 's2', title: 'Earth', body: 'The only planet with known life.', imageEmoji: '🌍', aiVoice: true),
    ],
  );

  static const alphabet = Lesson(
    id: 'l5',
    title: 'Phonics: The Letter S',
    subject: 'Reading',
    description: 'Sound it out — "sss" like a snake. Great for early readers.',
    source: ContentSource.uploaded,
    status: LessonStatus.assigned,
    authorName: 'Mrs. Bello',
    color: AppColors.accentPink,
    emoji: '🐍',
    gradeBandLabel: 1,
    progress: 0.5,
    xpReward: 100,
    slides: [
      LessonSlide(id: 's1', title: 'S says sss', body: 'Like a snake!', imageEmoji: '🐍'),
    ],
  );

  static List<Lesson> get lessons =>
      [mandarinFamily, mandarinNumbers, fractions, solarSystem, alphabet];

  static List<Lesson> get assigned =>
      lessons.where((l) => l.status == LessonStatus.assigned || l.progress > 0).toList();

  static const badges = [
    RewardBadge(id: 'b1', name: 'First Steps', description: 'Completed your first lesson', emoji: '🎯', color: AppColors.primary, unlocked: true),
    RewardBadge(id: 'b2', name: '7-Day Streak', description: 'Learned 7 days in a row', emoji: '🔥', color: AppColors.secondary, unlocked: true),
    RewardBadge(id: 'b3', name: 'Quiz Whiz', description: 'Scored 100% on 5 quizzes', emoji: '🧠', color: AppColors.accentTeal, unlocked: true),
    RewardBadge(id: 'b4', name: 'Polyglot', description: 'Finished a language course', emoji: '🌍', color: AppColors.accentBlue, unlocked: false, progress: 0.7),
    RewardBadge(id: 'b5', name: 'Math Master', description: 'Master 10 maths skills', emoji: '🏆', color: AppColors.accentYellow, unlocked: false, progress: 0.4),
    RewardBadge(id: 'b6', name: 'Early Bird', description: 'Study before 8am, 5 times', emoji: '🌅', color: AppColors.accentPink, unlocked: false, progress: 0.2),
  ];

  static const leaderboard = [
    LeaderboardEntry(rank: 1, name: 'Tunde', avatarEmoji: '🦁', xp: 2210, tag: 'Top Scorer'),
    LeaderboardEntry(rank: 2, name: 'Chioma', avatarEmoji: '🦊', xp: 1840, isCurrentUser: true, tag: 'Most Improved'),
    LeaderboardEntry(rank: 3, name: 'Zainab', avatarEmoji: '🐼', xp: 1755),
    LeaderboardEntry(rank: 4, name: 'Emeka', avatarEmoji: '🐯', xp: 1620),
    LeaderboardEntry(rank: 5, name: 'Aisha', avatarEmoji: '🐨', xp: 1490),
  ];

  static const classRoster = [
    StudentPerformance(name: 'Chioma', avatarEmoji: '🦊', overallMastery: 0.86, lessonsDone: 23, strength: 'Vocabulary', growthArea: 'Tones', weeklyActivity: [0.4, 0.8, 0.6, 1.0, 0.7, 0.3, 0.9]),
    StudentPerformance(name: 'Tunde', avatarEmoji: '🦁', overallMastery: 0.92, lessonsDone: 28, strength: 'Numbers', growthArea: 'Reading', weeklyActivity: [0.9, 0.7, 0.8, 0.6, 1.0, 0.8, 0.7]),
    StudentPerformance(name: 'Zainab', avatarEmoji: '🐼', overallMastery: 0.74, lessonsDone: 19, strength: 'Listening', growthArea: 'Writing', weeklyActivity: [0.3, 0.5, 0.4, 0.6, 0.5, 0.2, 0.4]),
    StudentPerformance(name: 'Emeka', avatarEmoji: '🐯', overallMastery: 0.68, lessonsDone: 16, strength: 'Speaking', growthArea: 'Fractions', weeklyActivity: [0.6, 0.3, 0.7, 0.4, 0.5, 0.6, 0.3]),
  ];

  static const teacherName = 'Mrs. Ade';
}

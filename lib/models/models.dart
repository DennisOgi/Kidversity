import 'package:flutter/material.dart';

enum UserRole { student, teacher }

enum ContentSource { uploaded, aiGenerated, hybrid }

enum LessonStatus { draft, published, assigned }

enum CheckpointType { multipleChoice, matching, pronunciation, typed }

/// A single slide inside a lesson, paired with narration audio.
class LessonSlide {
  final String id;
  final String title;
  final String body;
  final String? imageEmoji; // lightweight visual stand-in for slide art
  final String? caption; // synced narration text (accessibility)
  final Duration audioDuration;
  final bool aiVoice;

  /// The exact text spoken aloud by the narrator. Falls back to [caption]
  /// then [body] when null. For language lessons this is the target-language
  /// word/phrase (e.g. the Chinese characters).
  final String? speechText;

  /// BCP-47 locale used for narration, e.g. 'zh-CN' for Mandarin, 'en-US'.
  final String speechLang;

  const LessonSlide({
    required this.id,
    required this.title,
    required this.body,
    this.imageEmoji,
    this.caption,
    this.audioDuration = const Duration(seconds: 18),
    this.aiVoice = false,
    this.speechText,
    this.speechLang = 'en-US',
  });

  /// Resolved text to feed the TTS engine.
  String get narration => speechText ?? caption ?? body;
}

class QuizOption {
  final String id;
  final String label;
  final bool isCorrect;
  const QuizOption({required this.id, required this.label, this.isCorrect = false});
}

class Checkpoint {
  final String id;
  final CheckpointType type;
  final String prompt;
  final List<QuizOption> options;
  final String? hint;
  final String? audioPrompt;
  final String audioLang;

  const Checkpoint({
    required this.id,
    required this.type,
    required this.prompt,
    this.options = const [],
    this.hint,
    this.audioPrompt,
    this.audioLang = 'zh-CN',
  });
}

class Lesson {
  final String id;
  final String title;
  final String subject;
  final String description;
  final ContentSource source;
  final LessonStatus status;
  final String authorName;
  final Color color;
  final String emoji;
  final int gradeBandLabel; // e.g. grade level
  final List<LessonSlide> slides;
  final List<Checkpoint> checkpoints;
  final double progress; // 0..1 for current student
  final int xpReward;

  const Lesson({
    required this.id,
    required this.title,
    required this.subject,
    required this.description,
    required this.source,
    required this.status,
    required this.authorName,
    required this.color,
    required this.emoji,
    this.gradeBandLabel = 5,
    this.slides = const [],
    this.checkpoints = const [],
    this.progress = 0,
    this.xpReward = 120,
  });

  int get slideCount => slides.length;
  Duration get estimatedTime =>
      Duration(seconds: slides.fold(0, (s, e) => s + e.audioDuration.inSeconds) + checkpoints.length * 30);
}

class RewardBadge {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final Color color;
  final bool unlocked;
  final double progress; // for locked badges

  const RewardBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.color,
    this.unlocked = false,
    this.progress = 0,
  });
}

class LearnerProfile {
  final String name;
  final String avatarEmoji;
  final int level;
  final int xp;
  final int xpToNextLevel;
  final int streakDays;
  final int lessonsCompleted;
  final int minutesLearned;

  const LearnerProfile({
    required this.name,
    required this.avatarEmoji,
    required this.level,
    required this.xp,
    required this.xpToNextLevel,
    required this.streakDays,
    required this.lessonsCompleted,
    required this.minutesLearned,
  });

  double get levelProgress => xp / xpToNextLevel;
}

class LeaderboardEntry {
  final String name;
  final String avatarEmoji;
  final int xp;
  final int rank;
  final bool isCurrentUser;
  final String tag; // e.g. "Most Improved"
  const LeaderboardEntry({
    required this.name,
    required this.avatarEmoji,
    required this.xp,
    required this.rank,
    this.isCurrentUser = false,
    this.tag = '',
  });
}

class StudentPerformance {
  final String name;
  final String avatarEmoji;
  final double overallMastery; // 0..1
  final int lessonsDone;
  final String strength;
  final String growthArea;
  final List<double> weeklyActivity; // 7 values 0..1
  const StudentPerformance({
    required this.name,
    required this.avatarEmoji,
    required this.overallMastery,
    required this.lessonsDone,
    required this.strength,
    required this.growthArea,
    required this.weeklyActivity,
  });
}

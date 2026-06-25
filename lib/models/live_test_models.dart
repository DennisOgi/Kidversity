import 'package:flutter/material.dart';

enum LiveTestStatus { draft, live, ended }

enum ParticipantStatus { waiting, active, submitted }

class LiveTestOption {
  final String id;
  final String label;
  final bool isCorrect;

  const LiveTestOption({required this.id, required this.label, this.isCorrect = false});

  factory LiveTestOption.fromJson(Map<String, dynamic> json) => LiveTestOption(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        isCorrect: json['is_correct'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        if (isCorrect) 'is_correct': true,
      };
}

class LiveTestQuestion {
  final String id;
  final String testId;
  final int orderIndex;
  final String prompt;
  final List<LiveTestOption> options;
  final int points;

  const LiveTestQuestion({
    required this.id,
    required this.testId,
    required this.orderIndex,
    required this.prompt,
    required this.options,
    this.points = 1,
  });

  factory LiveTestQuestion.fromRow(Map<String, dynamic> row) {
    final optionsRaw = row['options'] as List? ?? [];
    return LiveTestQuestion(
      id: row['id'] as String,
      testId: row['test_id'] as String,
      orderIndex: (row['order_index'] as num?)?.toInt() ?? 0,
      prompt: row['prompt'] as String? ?? '',
      points: (row['points'] as num?)?.toInt() ?? 1,
      options: optionsRaw.map((o) => LiveTestOption.fromJson(Map<String, dynamic>.from(o as Map))).toList(),
    );
  }
}

class LiveTest {
  final String id;
  final String teacherId;
  final String? classId;
  final String title;
  final String subject;
  final int durationSeconds;
  final LiveTestStatus status;
  final String? joinCode;
  final DateTime? startedAt;
  final DateTime? endsAt;
  final DateTime createdAt;
  final List<LiveTestQuestion> questions;

  const LiveTest({
    required this.id,
    required this.teacherId,
    this.classId,
    required this.title,
    required this.subject,
    required this.durationSeconds,
    required this.status,
    this.joinCode,
    this.startedAt,
    this.endsAt,
    required this.createdAt,
    this.questions = const [],
  });

  factory LiveTest.fromRow(Map<String, dynamic> row, {List<LiveTestQuestion> questions = const []}) {
    return LiveTest(
      id: row['id'] as String,
      teacherId: row['teacher_id'] as String,
      classId: row['class_id'] as String?,
      title: row['title'] as String? ?? 'Live Quiz',
      subject: row['subject'] as String? ?? 'General',
      durationSeconds: (row['duration_seconds'] as num?)?.toInt() ?? 300,
      status: _statusFromDb(row['status'] as String?),
      joinCode: row['join_code'] as String?,
      startedAt: row['started_at'] != null ? DateTime.tryParse(row['started_at'] as String) : null,
      endsAt: row['ends_at'] != null ? DateTime.tryParse(row['ends_at'] as String) : null,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
      questions: questions,
    );
  }

  Duration? get remaining {
    if (endsAt == null) return null;
    final left = endsAt!.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  bool get isActive => status == LiveTestStatus.live && (remaining == null || remaining! > Duration.zero);

  static LiveTestStatus _statusFromDb(String? value) => switch (value) {
        'live' => LiveTestStatus.live,
        'ended' => LiveTestStatus.ended,
        _ => LiveTestStatus.draft,
      };
}

class LiveTestParticipant {
  final String id;
  final String testId;
  final String userId;
  final String displayName;
  final String avatarEmoji;
  final ParticipantStatus status;
  final int score;
  final int correctCount;
  final DateTime? submittedAt;

  const LiveTestParticipant({
    required this.id,
    required this.testId,
    required this.userId,
    required this.displayName,
    required this.avatarEmoji,
    required this.status,
    required this.score,
    required this.correctCount,
    this.submittedAt,
  });

  factory LiveTestParticipant.fromRow(Map<String, dynamic> row) => LiveTestParticipant(
        id: row['id'] as String,
        testId: row['test_id'] as String,
        userId: row['user_id'] as String,
        displayName: row['display_name'] as String? ?? 'Student',
        avatarEmoji: row['avatar_emoji'] as String? ?? '🦊',
        status: _statusFromDb(row['status'] as String?),
        score: (row['score'] as num?)?.toInt() ?? 0,
        correctCount: (row['correct_count'] as num?)?.toInt() ?? 0,
        submittedAt: row['submitted_at'] != null ? DateTime.tryParse(row['submitted_at'] as String) : null,
      );

  static ParticipantStatus _statusFromDb(String? value) => switch (value) {
        'active' => ParticipantStatus.active,
        'submitted' => ParticipantStatus.submitted,
        _ => ParticipantStatus.waiting,
      };
}

class LiveTestAnswer {
  final String id;
  final String testId;
  final String questionId;
  final String userId;
  final String? selectedOptionId;
  final bool isCorrect;
  final DateTime answeredAt;

  const LiveTestAnswer({
    required this.id,
    required this.testId,
    required this.questionId,
    required this.userId,
    this.selectedOptionId,
    required this.isCorrect,
    required this.answeredAt,
  });

  factory LiveTestAnswer.fromRow(Map<String, dynamic> row) => LiveTestAnswer(
        id: row['id'] as String,
        testId: row['test_id'] as String,
        questionId: row['question_id'] as String,
        userId: row['user_id'] as String,
        selectedOptionId: row['selected_option_id'] as String?,
        isCorrect: row['is_correct'] as bool? ?? false,
        answeredAt: DateTime.tryParse(row['answered_at'] as String? ?? '') ?? DateTime.now(),
      );
}

/// Aggregated view for teacher monitor dashboard.
class LiveTestSnapshot {
  final LiveTest test;
  final List<LiveTestParticipant> participants;
  final List<LiveTestAnswer> answers;

  const LiveTestSnapshot({
    required this.test,
    required this.participants,
    required this.answers,
  });

  int get submittedCount => participants.where((p) => p.status == ParticipantStatus.submitted).length;

  double get averageScore {
    if (participants.isEmpty) return 0;
    return participants.map((p) => p.score).reduce((a, b) => a + b) / participants.length;
  }

  Map<String, int> optionCounts(String questionId) {
    final counts = <String, int>{};
    for (final a in answers.where((x) => x.questionId == questionId)) {
      final key = a.selectedOptionId ?? 'skipped';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  int answeredCount(String userId) =>
      answers.where((a) => a.userId == userId).length;

  double participantProgress(LiveTestParticipant participant) {
    if (test.questions.isEmpty) return 0;
    if (participant.status == ParticipantStatus.submitted) return 1;
    return answeredCount(participant.userId) / test.questions.length;
  }

  List<LiveTestParticipant> get leaderboard =>
      [...participants]..sort((a, b) => b.score.compareTo(a.score));
}

/// Preset quiz templates for quick start.
class LiveQuizTemplate {
  final String title;
  final String subject;
  final String emoji;
  final Color color;
  final List<(String prompt, List<(String label, bool correct)>)> questions;

  const LiveQuizTemplate({
    required this.title,
    required this.subject,
    required this.emoji,
    required this.color,
    required this.questions,
  });

  static const mandarinQuick = LiveQuizTemplate(
    title: 'Mandarin Quick Check',
    subject: 'Mandarin',
    emoji: '🀄',
    color: Color(0xFF6C5CE7),
    questions: [
      ('What does 妈妈 mean?', [('Mum', true), ('Dad', false), ('Sister', false)]),
      ('Which is "three"?', [('一', false), ('三', true), ('二', false)]),
      ('How do you say "hello"?', [('你好', true), ('再见', false), ('谢谢', false)]),
    ],
  );

  static const mathsWarmup = LiveQuizTemplate(
    title: 'Maths Warm-up',
    subject: 'Maths',
    emoji: '🍕',
    color: Color(0xFF00CEC9),
    questions: [
      ('What is 1/2 + 1/4?', [('3/4', true), ('2/4', false), ('1/3', false)]),
      ('How many sides does a hexagon have?', [('6', true), ('5', false), ('8', false)]),
      ('12 × 3 = ?', [('36', true), ('32', false), ('39', false)]),
    ],
  );

  static const all = [mandarinQuick, mathsWarmup];
}

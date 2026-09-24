import 'past_questions_models.dart';

int percentOf(int correct, int total) =>
    total <= 0 ? 0 : ((correct / total) * 100).round();

class ExamAttempt {
  final String id;
  final String userId;
  final String examSlug;
  final String examLabel;
  final String subjectSlug;
  final String subjectName;
  final int? year;
  final String mode;
  final int total;
  final int correct;
  final int durationSeconds;
  final String? assignmentId;
  final DateTime createdAt;

  const ExamAttempt({
    required this.id,
    required this.userId,
    required this.examSlug,
    required this.examLabel,
    required this.subjectSlug,
    required this.subjectName,
    required this.year,
    required this.mode,
    required this.total,
    required this.correct,
    required this.durationSeconds,
    required this.assignmentId,
    required this.createdAt,
  });

  factory ExamAttempt.fromJson(Map<String, dynamic> json) => ExamAttempt(
    id: json['id'] as String,
    userId: json['user_id'] as String? ?? '',
    examSlug: json['exam_slug'] as String? ?? '',
    examLabel: json['exam_label'] as String? ?? '',
    subjectSlug: json['subject_slug'] as String? ?? '',
    subjectName: json['subject_name'] as String? ?? '',
    year: (json['exam_year'] as num?)?.toInt(),
    mode: json['mode'] as String? ?? 'standard',
    total: (json['total'] as num?)?.toInt() ?? 0,
    correct: (json['correct'] as num?)?.toInt() ?? 0,
    durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
    assignmentId: json['assignment_id'] as String?,
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
  );

  int get percent => percentOf(correct, total);

  String get modeLabel => switch (mode) {
    'quick' => 'Quick 10',
    'standard' => 'Standard 20',
    'challenge' => 'Challenge 40',
    'mock' => 'Timed mock',
    'retry' => 'Mistakes retry',
    _ => mode,
  };

  String get headline =>
      '$examLabel · $subjectName${year == null ? '' : ' · $year'}';
}

class ExamMistake {
  final int questionId;
  final String examSlug;
  final String examLabel;
  final String subjectSlug;
  final String subjectName;
  final PastQuestion question;
  final int missCount;
  final DateTime lastMissedAt;

  const ExamMistake({
    required this.questionId,
    required this.examSlug,
    required this.examLabel,
    required this.subjectSlug,
    required this.subjectName,
    required this.question,
    required this.missCount,
    required this.lastMissedAt,
  });

  factory ExamMistake.fromJson(Map<String, dynamic> json) => ExamMistake(
    questionId: (json['question_id'] as num).toInt(),
    examSlug: json['exam_slug'] as String? ?? '',
    examLabel: json['exam_label'] as String? ?? '',
    subjectSlug: json['subject_slug'] as String? ?? '',
    subjectName: json['subject_name'] as String? ?? '',
    question: PastQuestion.fromJson(
      Map<String, dynamic>.from(json['payload'] as Map),
    ),
    missCount: (json['miss_count'] as num?)?.toInt() ?? 1,
    lastMissedAt:
        DateTime.tryParse(json['last_missed_at'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
  );
}

/// Open mistakes for one exam and subject, ready to replay.
class MistakeGroup {
  final String examSlug;
  final String examLabel;
  final String subjectSlug;
  final String subjectName;
  final List<ExamMistake> items;

  const MistakeGroup({
    required this.examSlug,
    required this.examLabel,
    required this.subjectSlug,
    required this.subjectName,
    required this.items,
  });

  PastQuestionsSessionConfig retryConfig({int limit = 20}) {
    final ordered = [...items]
      ..sort((a, b) => b.missCount.compareTo(a.missCount));
    return PastQuestionsSessionConfig(
      exam: PastExamType(id: 0, name: examLabel, slug: examSlug),
      subject: PastSubject(id: 0, name: subjectName, slug: subjectSlug),
      mode: PastPracticeMode.standard,
      preset: [for (final item in ordered.take(limit)) item.question],
    );
  }
}

List<MistakeGroup> groupMistakes(List<ExamMistake> mistakes) {
  final groups = <String, List<ExamMistake>>{};
  for (final item in mistakes) {
    groups
        .putIfAbsent('${item.examSlug}|${item.subjectSlug}', () => [])
        .add(item);
  }
  return [
    for (final items in groups.values)
      MistakeGroup(
        examSlug: items.first.examSlug,
        examLabel: items.first.examLabel,
        subjectSlug: items.first.subjectSlug,
        subjectName: items.first.subjectName,
        items: items,
      ),
  ]..sort((a, b) => b.items.length.compareTo(a.items.length));
}

class MathsResult {
  final int level;
  final int correct;
  final int total;
  final DateTime createdAt;

  const MathsResult({
    required this.level,
    required this.correct,
    required this.total,
    required this.createdAt,
  });

  factory MathsResult.fromJson(Map<String, dynamic> json) => MathsResult(
    level: (json['level'] as num).toInt(),
    correct: (json['correct'] as num).toInt(),
    total: (json['total'] as num).toInt(),
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
  );

  int get percent => percentOf(correct, total);

  bool get passed => correct * 10 >= total * 7;
}

enum AssignmentKind { exam, lesson, maths }

extension AssignmentKindX on AssignmentKind {
  String get label => switch (this) {
    AssignmentKind.exam => 'Exam practice',
    AssignmentKind.lesson => 'Mandarin lesson',
    AssignmentKind.maths => 'Maths level',
  };
}

class ClassAssignment {
  final String id;
  final String classId;
  final AssignmentKind kind;
  final String title;
  final Map<String, dynamic> config;
  final DateTime? dueAt;
  final DateTime createdAt;

  const ClassAssignment({
    required this.id,
    required this.classId,
    required this.kind,
    required this.title,
    required this.config,
    required this.dueAt,
    required this.createdAt,
  });

  factory ClassAssignment.fromJson(Map<String, dynamic> json) =>
      ClassAssignment(
        id: json['id'] as String,
        classId: json['class_id'] as String? ?? '',
        kind: AssignmentKind.values.firstWhere(
          (kind) => kind.name == json['kind'],
          orElse: () => AssignmentKind.exam,
        ),
        title: json['title'] as String? ?? 'Assignment',
        config: Map<String, dynamic>.from(json['config'] as Map? ?? const {}),
        dueAt: DateTime.tryParse(json['due_at'] as String? ?? '')?.toLocal(),
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
      );

  String? get lessonId => config['lesson_id'] as String?;

  int? get mathsLevel => (config['level'] as num?)?.toInt();

  int get questionCount => (config['count'] as num?)?.toInt() ?? 20;

  bool get isOverdue =>
      dueAt != null &&
      DateTime.now().isAfter(dueAt!.add(const Duration(days: 1)));

  PastQuestionsSessionConfig? get examConfig {
    if (kind != AssignmentKind.exam) return null;
    final examSlug = config['exam_slug'] as String?;
    final subjectSlug = config['subject_slug'] as String?;
    if (examSlug == null || subjectSlug == null) return null;
    final topicId = config['topic_id'] as String?;
    return PastQuestionsSessionConfig(
      exam: PastExamType(
        id: 0,
        name: config['exam_name'] as String? ?? examSlug.toUpperCase(),
        slug: examSlug,
      ),
      subject: PastSubject(
        id: 0,
        name: config['subject_name'] as String? ?? subjectSlug,
        slug: subjectSlug,
      ),
      year: (config['year'] as num?)?.toInt(),
      mode: topicId == null
          ? PastPracticeModeX.forCount(questionCount)
          : PastPracticeMode.quick,
      assignmentId: id,
      topicId: topicId,
      topicTitle: config['topic_title'] as String?,
    );
  }
}

class AssignmentSubmission {
  final String assignmentId;
  final String userId;
  final int correct;
  final int total;
  final DateTime completedAt;

  const AssignmentSubmission({
    required this.assignmentId,
    required this.userId,
    required this.correct,
    required this.total,
    required this.completedAt,
  });

  factory AssignmentSubmission.fromJson(Map<String, dynamic> json) =>
      AssignmentSubmission(
        assignmentId: json['assignment_id'] as String,
        userId: json['user_id'] as String,
        correct: (json['correct'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
        completedAt:
            DateTime.tryParse(
              json['completed_at'] as String? ?? '',
            )?.toLocal() ??
            DateTime.now(),
      );

  int get percent => percentOf(correct, total);
}

class ClassStudent {
  final String userId;
  final String name;
  final String avatar;

  const ClassStudent({
    required this.userId,
    required this.name,
    required this.avatar,
  });
}

/// One assignment with each student's status, for the teacher.
class AssignmentProgress {
  final ClassAssignment assignment;
  final List<ClassStudent> students;
  final Map<String, AssignmentSubmission> submissions;
  final Map<String, int> lessonScores;

  const AssignmentProgress({
    required this.assignment,
    required this.students,
    required this.submissions,
    required this.lessonScores,
  });

  bool isDone(String userId) => assignment.kind == AssignmentKind.lesson
      ? lessonScores.containsKey(userId)
      : submissions.containsKey(userId);

  String statusFor(String userId) {
    if (assignment.kind == AssignmentKind.lesson) {
      final score = lessonScores[userId];
      return score == null ? 'Not yet' : '$score%';
    }
    final submission = submissions[userId];
    if (submission == null) return 'Not yet';
    return '${submission.correct}/${submission.total} · ${submission.percent}%';
  }

  int get doneCount => students.where((s) => isDone(s.userId)).length;
}

class LessonRecord {
  final String lessonId;
  final int score;
  final DateTime completedAt;

  const LessonRecord({
    required this.lessonId,
    required this.score,
    required this.completedAt,
  });
}

class SubjectSummary {
  final String label;
  final int attempts;
  final int averagePercent;
  final int bestPercent;
  final int questions;

  const SubjectSummary({
    required this.label,
    required this.attempts,
    required this.averagePercent,
    required this.bestPercent,
    required this.questions,
  });
}

class ProgressReport {
  final String userId;
  final String name;
  final String avatar;
  final List<LessonRecord> lessons;
  final List<ExamAttempt> attempts;
  final List<MathsResult> maths;
  final int openMistakes;
  final DateTime generatedAt;

  const ProgressReport({
    required this.userId,
    required this.name,
    required this.avatar,
    required this.lessons,
    required this.attempts,
    required this.maths,
    required this.openMistakes,
    required this.generatedAt,
  });

  int get lessonsDone => lessons.map((l) => l.lessonId).toSet().length;

  int get lessonAverage => lessons.isEmpty
      ? 0
      : (lessons.fold<int>(0, (sum, l) => sum + l.score) / lessons.length)
            .round();

  int get examQuestions => attempts.fold(0, (sum, a) => sum + a.total);

  int get examAverage =>
      percentOf(attempts.fold(0, (sum, a) => sum + a.correct), examQuestions);

  int get examMinutes =>
      (attempts.fold(0, (sum, a) => sum + a.durationSeconds) / 60).round();

  Set<int> get mathsLevelsPassed => {
    for (final result in maths)
      if (result.passed) result.level,
  };

  int get mathsAverage => percentOf(
    maths.fold(0, (sum, m) => sum + m.correct),
    maths.fold(0, (sum, m) => sum + m.total),
  );

  List<SubjectSummary> get subjects {
    final groups = <String, List<ExamAttempt>>{};
    for (final attempt in attempts) {
      groups
          .putIfAbsent(
            '${attempt.examLabel} · ${attempt.subjectName}',
            () => [],
          )
          .add(attempt);
    }
    return [
      for (final entry in groups.entries)
        SubjectSummary(
          label: entry.key,
          attempts: entry.value.length,
          averagePercent: percentOf(
            entry.value.fold(0, (sum, a) => sum + a.correct),
            entry.value.fold(0, (sum, a) => sum + a.total),
          ),
          bestPercent: entry.value
              .map((a) => a.percent)
              .reduce((a, b) => a > b ? a : b),
          questions: entry.value.fold(0, (sum, a) => sum + a.total),
        ),
    ]..sort((a, b) => b.questions.compareTo(a.questions));
  }

  /// Distinct days with any lesson, exam, or maths work in the last week.
  int activeDaysThisWeek() {
    final since = DateTime.now().subtract(const Duration(days: 7));
    final days = <String>{};
    void add(DateTime date) {
      if (date.isAfter(since)) {
        days.add('${date.year}-${date.month}-${date.day}');
      }
    }

    for (final l in lessons) {
      add(l.completedAt);
    }
    for (final a in attempts) {
      add(a.createdAt);
    }
    for (final m in maths) {
      add(m.createdAt);
    }
    return days.length;
  }
}

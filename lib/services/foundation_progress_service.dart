import '../core/error_handler.dart' as app_errors;
import '../models/mandarin_content.dart';
import 'supabase_service.dart';

enum LearningMovement { rising, steady, quiet, struggling }

class StruggleItem {
  final String key;
  final String label;
  final String detail;
  final int missCount;
  final String? lessonTitle;

  const StruggleItem({
    required this.key,
    required this.label,
    required this.detail,
    required this.missCount,
    this.lessonTitle,
  });
}

class FoundationStudentProgress {
  final String userId;
  final String name;
  final String avatarEmoji;
  final Set<String> completedLessonIds;
  final double averageScore;
  final Map<String, int> scoresByLesson;
  final List<String> weakItemIds;
  final DateTime? lastCompletedAt;
  final int lessonsThisWeek;
  final int lessonsPreviousWeek;
  final List<StruggleItem> struggles;
  final List<String> strengths;
  final List<String> attentionReasons;
  final LearningMovement movement;

  const FoundationStudentProgress({
    required this.userId,
    required this.name,
    required this.avatarEmoji,
    required this.completedLessonIds,
    required this.averageScore,
    required this.scoresByLesson,
    required this.weakItemIds,
    required this.lastCompletedAt,
    this.lessonsThisWeek = 0,
    this.lessonsPreviousWeek = 0,
    this.struggles = const [],
    this.strengths = const [],
    this.attentionReasons = const [],
    this.movement = LearningMovement.quiet,
  });

  bool get isStalled =>
      lastCompletedAt == null ||
      DateTime.now().difference(lastCompletedAt!).inDays >= 14;

  bool get needsAttention => attentionReasons.isNotEmpty;

  int get completedCount => completedLessonIds.length;

  int get pathPercent => ((completedCount / 30) * 100).round().clamp(0, 100);

  String get movementLabel => switch (movement) {
    LearningMovement.rising => 'Rising',
    LearningMovement.steady => 'Steady',
    LearningMovement.quiet => 'Quiet',
    LearningMovement.struggling => 'Needs support',
  };

  String get lastActiveLabel {
    final last = lastCompletedAt;
    if (last == null) return 'Not started yet';
    final days = DateTime.now().difference(last).inDays;
    if (days == 0) return 'Active today';
    if (days == 1) return 'Active yesterday';
    if (days < 7) return 'Active $days days ago';
    if (days < 14) return 'Quiet for $days days';
    return 'No lesson in $days days';
  }
}

class FoundationClassDashboard {
  final List<FoundationStudentProgress> students;
  final List<StruggleItem> classHotspots;
  final DateTime generatedAt;

  const FoundationClassDashboard({
    required this.students,
    required this.classHotspots,
    required this.generatedAt,
  });

  int get learnerCount => students.length;

  double get averageCompletion {
    if (students.isEmpty) return 0;
    final total = students.fold<int>(
      0,
      (sum, student) => sum + student.completedCount,
    );
    return total / (students.length * 30);
  }

  double get averageScore {
    if (students.isEmpty) return 0;
    return students.fold<double>(0, (sum, s) => sum + s.averageScore) /
        students.length;
  }

  int get lessonsThisWeek =>
      students.fold(0, (sum, s) => sum + s.lessonsThisWeek);

  List<FoundationStudentProgress> get attentionQueue =>
      students.where((s) => s.needsAttention).toList()..sort((a, b) {
        final rank = _attentionRank(b).compareTo(_attentionRank(a));
        if (rank != 0) return rank;
        final struggles = b.struggles.length.compareTo(a.struggles.length);
        if (struggles != 0) return struggles;
        return a.name.compareTo(b.name);
      });

  List<FoundationStudentProgress> get moversThisWeek =>
      students.where((s) => s.lessonsThisWeek > 0).toList()
        ..sort((a, b) => b.lessonsThisWeek.compareTo(a.lessonsThisWeek));

  List<FoundationStudentProgress> get rising =>
      students.where((s) => s.movement == LearningMovement.rising).toList();

  static int _attentionRank(FoundationStudentProgress student) {
    var score = 0;
    if (student.completedCount == 0) score += 5;
    if (student.isStalled) score += 4;
    if (student.movement == LearningMovement.struggling) score += 5;
    if (student.averageScore > 0 && student.averageScore < 60) score += 3;
    score += student.struggles.length * 2;
    score += student.attentionReasons.length;
    return score;
  }
}

class FoundationProgressService {
  static const instance = FoundationProgressService._();
  const FoundationProgressService._();

  Future<app_errors.Result<List<FoundationStudentProgress>>>
  fetchClassProgress({MandarinCourse? course}) async {
    final service = SupabaseService.instance;
    if (!service.isInitialized) {
      return app_errors.Result.success(const []);
    }
    try {
      final teacherId = service.currentUser?.id;
      if (teacherId == null) {
        return app_errors.Result.failure('Not authenticated');
      }
      final classes = await service.client
          .from('classes')
          .select('id')
          .eq('teacher_id', teacherId);
      final classIds = (classes as List)
          .map((row) => (row as Map)['id'] as String)
          .toList();
      if (classIds.isEmpty) return app_errors.Result.success(const []);

      final memberships = await service.client
          .from('class_members')
          .select('user_id')
          .inFilter('class_id', classIds);
      final userIds = (memberships as List)
          .map((row) => (row as Map)['user_id'] as String)
          .toSet();
      if (userIds.isEmpty) return app_errors.Result.success(const []);

      final profiles = await service.client
          .from('user_profiles')
          .select('user_id, display_name, avatar_emoji')
          .inFilter('user_id', userIds.toList());
      final results = await service.client
          .from('lesson_results')
          .select('user_id, lesson_id, score, answers, completed_at')
          .inFilter('user_id', userIds.toList());

      final catalog = course == null ? const <String, _ItemLookup>{} : _catalog(course);
      final lessonTitles = {
        for (final lesson in course?.lessons ?? const <MandarinCourseLesson>[])
          lesson.id: lesson.title,
      };

      return app_errors.Result.success([
        for (final raw in profiles as List)
          _mapStudent(
            Map<String, dynamic>.from(raw as Map),
            (results as List)
                .where((result) => (result as Map)['user_id'] == raw['user_id'])
                .map((result) => Map<String, dynamic>.from(result as Map))
                .toList(),
            catalog: catalog,
            lessonTitles: lessonTitles,
          ),
      ]..sort((a, b) {
        if (a.needsAttention != b.needsAttention) {
          return a.needsAttention ? -1 : 1;
        }
        return b.completedCount.compareTo(a.completedCount);
      }));
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'Fetch Foundation class progress',
      );
      return app_errors.Result.failure('Could not load Foundation progress.');
    }
  }

  FoundationClassDashboard buildDashboard(
    List<FoundationStudentProgress> students,
  ) {
    final hotspotMap = <String, StruggleItem>{};
    for (final student in students) {
      for (final item in student.struggles) {
        final existing = hotspotMap[item.key];
        if (existing == null) {
          hotspotMap[item.key] = item;
        } else {
          hotspotMap[item.key] = StruggleItem(
            key: item.key,
            label: item.label,
            detail: item.detail,
            missCount: existing.missCount + item.missCount,
            lessonTitle: item.lessonTitle ?? existing.lessonTitle,
          );
        }
      }
    }
    final hotspots = hotspotMap.values.toList()
      ..sort((a, b) => b.missCount.compareTo(a.missCount));
    return FoundationClassDashboard(
      students: students,
      classHotspots: hotspots.take(5).toList(),
      generatedAt: DateTime.now(),
    );
  }

  FoundationStudentProgress _mapStudent(
    Map<String, dynamic> profile,
    List<Map<String, dynamic>> results, {
    required Map<String, _ItemLookup> catalog,
    required Map<String, String> lessonTitles,
  }) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final twoWeeksAgo = now.subtract(const Duration(days: 14));

    final scores = results
        .map((row) => (row['score'] as num).toDouble())
        .toList();
    final completionDates =
        results
            .map(
              (row) => DateTime.tryParse(row['completed_at'] as String? ?? ''),
            )
            .whereType<DateTime>()
            .toList()
          ..sort();

    final missCounts = <String, int>{};
    final missMeta = <String, ({String label, String detail, String? lesson})>{};
    final weakItemIds = <String>[];

    for (final row in results) {
      final lessonId = row['lesson_id'] as String? ?? '';
      final lessonTitle = lessonTitles[lessonId];
      final answers = row['answers'];
      if (answers is! List) continue;
      for (final raw in answers) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        if (map['is_correct'] != false) continue;
        final itemId = map['item_id'] as String? ?? '';
        final correct = (map['correct_answer'] as String? ?? '').trim();
        final selected = (map['selected'] as String? ?? '').trim();
        final lookup = catalog[itemId];
        final key = itemId.isNotEmpty ? itemId : correct;
        if (key.isEmpty) continue;
        weakItemIds.add(key);
        missCounts[key] = (missCounts[key] ?? 0) + 1;
        missMeta[key] = (
          label: lookup?.label ?? (correct.isNotEmpty ? correct : 'Missed item'),
          detail: lookup?.detail ??
              (selected.isNotEmpty
                  ? 'Chose “$selected”'
                  : (lessonTitle ?? 'Needs revisit')),
          lesson: lessonTitle ?? lookup?.lessonTitle,
        );
      }
    }

    final struggles =
        [
          for (final entry in missCounts.entries)
            StruggleItem(
              key: entry.key,
              label: missMeta[entry.key]?.label ?? entry.key,
              detail: missMeta[entry.key]?.detail ?? 'Needs revisit',
              missCount: entry.value,
              lessonTitle: missMeta[entry.key]?.lesson,
            ),
        ]..sort((a, b) => b.missCount.compareTo(a.missCount));

    final scoresByLesson = {
      for (final row in results)
        row['lesson_id'] as String: (row['score'] as num).round(),
    };

    final strengthEntries =
        [
          for (final entry in scoresByLesson.entries)
            if (entry.value >= 80) entry,
        ]..sort((a, b) => b.value.compareTo(a.value));
    final strengths = [
      for (final entry in strengthEntries.take(3))
        lessonTitles[entry.key] ?? 'Lesson score ${entry.value}%',
    ];

    var thisWeek = 0;
    var previousWeek = 0;
    for (final date in completionDates) {
      if (!date.isBefore(weekAgo)) {
        thisWeek++;
      } else if (!date.isBefore(twoWeeksAgo)) {
        previousWeek++;
      }
    }

    final averageScore = scores.isEmpty
        ? 0.0
        : scores.reduce((a, b) => a + b) / scores.length;
    final completed = results.map((row) => row['lesson_id'] as String).toSet();
    final last = completionDates.isEmpty ? null : completionDates.last;
    final stalled =
        last == null || DateTime.now().difference(last).inDays >= 14;

    final reasons = <String>[];
    if (completed.isEmpty) {
      reasons.add('Has not started Foundation yet');
    } else if (stalled) {
      reasons.add('No lesson finished in 14+ days');
    }
    if (completed.length >= 2 && averageScore < 60) {
      reasons.add('Average score below 60%');
    }
    if (struggles.length >= 3) {
      reasons.add('${struggles.length} words/skills need revisiting');
    }
    if (completed.isNotEmpty && thisWeek == 0 && !stalled) {
      reasons.add('No learning movement this week');
    }

    final LearningMovement movement;
    if (completed.isEmpty || stalled) {
      movement = LearningMovement.quiet;
    } else if (averageScore < 60 || struggles.length >= 3) {
      movement = LearningMovement.struggling;
    } else if (thisWeek > previousWeek || thisWeek >= 2) {
      movement = LearningMovement.rising;
    } else {
      movement = LearningMovement.steady;
    }

    return FoundationStudentProgress(
      userId: profile['user_id'] as String,
      name: profile['display_name'] as String? ?? 'Student',
      avatarEmoji: profile['avatar_emoji'] as String? ?? '🦊',
      completedLessonIds: completed,
      averageScore: averageScore,
      scoresByLesson: scoresByLesson,
      weakItemIds: weakItemIds.toSet().toList(),
      lastCompletedAt: last,
      lessonsThisWeek: thisWeek,
      lessonsPreviousWeek: previousWeek,
      struggles: struggles.take(4).toList(),
      strengths: strengths,
      attentionReasons: reasons,
      movement: movement,
    );
  }

  Map<String, _ItemLookup> _catalog(MandarinCourse course) {
    final map = <String, _ItemLookup>{};
    for (final lesson in course.lessons) {
      for (final vocab in lesson.vocabulary) {
        map[vocab.id] = _ItemLookup(
          label: vocab.simplified,
          detail: '${vocab.pinyin} · ${vocab.english}',
          lessonTitle: lesson.title,
        );
      }
      for (final activity in lesson.activities) {
        map[activity.id] = _ItemLookup(
          label: activity.answer,
          detail: activity.prompt,
          lessonTitle: lesson.title,
        );
      }
      for (final item in lesson.assessment) {
        map[item.id] = _ItemLookup(
          label: item.correctAnswer,
          detail: item.question,
          lessonTitle: lesson.title,
        );
      }
    }
    return map;
  }
}

class _ItemLookup {
  final String label;
  final String detail;
  final String lessonTitle;

  const _ItemLookup({
    required this.label,
    required this.detail,
    required this.lessonTitle,
  });
}

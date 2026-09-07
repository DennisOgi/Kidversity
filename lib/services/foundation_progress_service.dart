import '../core/error_handler.dart' as app_errors;
import 'supabase_service.dart';

class FoundationStudentProgress {
  final String userId;
  final String name;
  final String avatarEmoji;
  final Set<String> completedLessonIds;
  final double averageScore;
  final Map<String, int> scoresByLesson;
  final List<String> weakItemIds;
  final DateTime? lastCompletedAt;

  const FoundationStudentProgress({
    required this.userId,
    required this.name,
    required this.avatarEmoji,
    required this.completedLessonIds,
    required this.averageScore,
    required this.scoresByLesson,
    required this.weakItemIds,
    required this.lastCompletedAt,
  });

  bool get isStalled =>
      lastCompletedAt == null ||
      DateTime.now().difference(lastCompletedAt!).inDays >= 14;
}

class FoundationProgressService {
  static const instance = FoundationProgressService._();
  const FoundationProgressService._();

  Future<app_errors.Result<List<FoundationStudentProgress>>>
  fetchClassProgress() async {
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

      return app_errors.Result.success([
        for (final raw in profiles as List)
          _mapStudent(
            Map<String, dynamic>.from(raw as Map),
            (results as List)
                .where((result) => (result as Map)['user_id'] == raw['user_id'])
                .map((result) => Map<String, dynamic>.from(result as Map))
                .toList(),
          ),
      ]);
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'Fetch Foundation class progress',
      );
      return app_errors.Result.failure('Could not load Foundation progress.');
    }
  }

  FoundationStudentProgress _mapStudent(
    Map<String, dynamic> profile,
    List<Map<String, dynamic>> results,
  ) {
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
    final weakItemIds = <String>[];
    for (final row in results) {
      final answers = row['answers'];
      if (answers is! List) continue;
      for (final raw in answers) {
        if (raw is Map &&
            raw['is_correct'] == false &&
            raw['item_id'] is String) {
          weakItemIds.add(raw['item_id'] as String);
        }
      }
    }
    return FoundationStudentProgress(
      userId: profile['user_id'] as String,
      name: profile['display_name'] as String? ?? 'Student',
      avatarEmoji: profile['avatar_emoji'] as String? ?? '🦊',
      completedLessonIds: results
          .map((row) => row['lesson_id'] as String)
          .toSet(),
      averageScore: scores.isEmpty
          ? 0
          : scores.reduce((a, b) => a + b) / scores.length,
      scoresByLesson: {
        for (final row in results)
          row['lesson_id'] as String: (row['score'] as num).round(),
      },
      weakItemIds: weakItemIds,
      lastCompletedAt: completionDates.isEmpty ? null : completionDates.last,
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/live_test_models.dart';
import '../models/mandarin_content.dart';
import '../models/models.dart';
import '../models/user_preferences.dart';
import '../services/live_test_service.dart';
import '../services/mandarin_experience_builder.dart';
import '../services/foundation_review_service.dart';
import '../services/foundation_progress_service.dart';
import '../services/supabase_service.dart';
import 'auth_state.dart';
import 'mandarin_content_repository.dart';
import 'mandarin_foundation_data.dart';

/// Currently selected app persona. Drives which shell is shown.
final roleProvider = StateProvider<UserRole?>((ref) => null);

final mandarinContentRepositoryProvider = Provider<MandarinContentRepository>(
  (ref) => const HybridMandarinContentRepository(),
);

final mandarinCourseProvider = FutureProvider<MandarinCourse>((ref) async {
  ref.watch(authControllerProvider);
  return ref.read(mandarinContentRepositoryProvider).loadCourse();
});

final publishedFoundationLessonCountProvider = FutureProvider<int>((ref) async {
  final service = SupabaseService.instance;
  if (!service.isInitialized) return 0;
  final rows = await service.client
      .from('course_lessons')
      .select('id')
      .eq('course_id', MandarinFoundationData.courseId)
      .eq('status', 'approved');
  return (rows as List).length;
});

final mandarinExperienceProvider =
    FutureProvider.family<MandarinExperience, String>((ref, lessonId) async {
      final course = await ref.watch(mandarinCourseProvider.future);
      final matches = course.lessons.where((item) => item.id == lessonId);
      if (matches.isEmpty) throw StateError('Foundation lesson not found.');
      return const MandarinExperienceBuilder().build(matches.first);
    });

final foundationReviewQueueProvider =
    FutureProvider.autoDispose<List<FoundationReviewItem>>((ref) async {
      ref.watch(authControllerProvider);
      final result = await FoundationReviewService.instance.fetchQueue();
      if (result.isFailure) {
        throw StateError(result.error ?? 'Could not load review queue');
      }
      return result.data!;
    });

final foundationClassProgressProvider =
    FutureProvider.autoDispose<List<FoundationStudentProgress>>((ref) async {
      ref.watch(authControllerProvider);
      final result = await FoundationProgressService.instance
          .fetchClassProgress();
      if (result.isFailure) {
        throw StateError(result.error ?? 'Could not load class progress');
      }
      return result.data!;
    });

final foundationCompletedLessonIdsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
      final auth = ref.watch(authControllerProvider);
      final service = SupabaseService.instance;
      if (!service.isInitialized || !auth.isAuthenticated) return const {};

      final userId = service.currentUser?.id;
      if (userId == null) return const {};

      final rows = await service.client
          .from('lesson_results')
          .select('lesson_id')
          .eq('user_id', userId);
      return {
        for (final row in rows as List)
          if ((row as Map)['lesson_id'] case final String lessonId) lessonId,
      };
    });

/// Teacher's class id, name, and shareable join code.
final teacherClassInfoProvider =
    FutureProvider.autoDispose<({String id, String name, String code})?>((
      ref,
    ) async {
      ref.watch(authControllerProvider);
      if (!SupabaseService.instance.isInitialized) return null;
      final result = await SupabaseService.instance.fetchTeacherClassInfo();
      return result.data;
    });

final rosterProvider = FutureProvider<List<StudentPerformance>>((ref) async {
  ref.watch(authControllerProvider);
  if (!SupabaseService.instance.isInitialized) return const [];
  final result = await SupabaseService.instance.fetchClassRoster();
  if (result.isSuccess) return result.data!;
  throw StateError(result.error ?? 'Could not load the class roster.');
});

final userPreferencesProvider = FutureProvider<UserPreferences>((ref) async {
  ref.watch(authControllerProvider);
  if (!SupabaseService.instance.isInitialized) return const UserPreferences();
  final result = await SupabaseService.instance.fetchUserPreferences();
  return result.data ?? const UserPreferences();
});

final teacherRecentTestsProvider = FutureProvider.autoDispose<List<LiveTest>>((
  ref,
) async {
  ref.watch(authControllerProvider);
  if (!SupabaseService.instance.isInitialized) return const [];
  final result = await LiveTestService.instance.fetchTeacherRecentTests();
  return result.data ?? const [];
});

/// Active live quiz for the current student (realtime).
final activeLiveTestProvider = StreamProvider.autoDispose<LiveTest?>((ref) {
  ref.watch(authControllerProvider);
  if (!SupabaseService.instance.isInitialized) {
    return Stream.value(null);
  }
  return LiveTestService.instance.watchActiveTestForStudent();
});

/// Teacher monitor + student test detail stream.
final liveTestSnapshotProvider = StreamProvider.autoDispose
    .family<LiveTestSnapshot?, String>((ref, testId) {
      if (!SupabaseService.instance.isInitialized) {
        return Stream.value(null);
      }
      return LiveTestService.instance.watchSnapshot(testId);
    });

final liveTestDetailProvider = StreamProvider.autoDispose
    .family<LiveTest?, String>((ref, testId) async* {
      if (!SupabaseService.instance.isInitialized) {
        yield null;
        return;
      }
      final initial = await LiveTestService.instance.fetchTest(testId);
      yield initial.data;
      await for (final snap in LiveTestService.instance.watchSnapshot(testId)) {
        yield snap.test;
      }
    });

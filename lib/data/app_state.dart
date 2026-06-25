import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/live_test_models.dart';
import '../models/models.dart';
import '../models/user_preferences.dart';
import '../services/live_test_service.dart';
import '../services/supabase_service.dart';
import 'auth_state.dart';
import 'content_catalog.dart';
import 'mock_data.dart';

/// Currently selected app persona. Drives which shell is shown.
final roleProvider = StateProvider<UserRole?>((ref) => null);

final catalogProvider = ChangeNotifierProvider<ContentCatalog>((ref) {
  final catalog = ContentCatalog();
  catalog.load();
  ref.listen(authControllerProvider, (_, __) => catalog.load(force: true));
  return catalog;
});

final lessonsProvider = Provider<List<Lesson>>((ref) {
  ref.watch(catalogProvider);
  return ref.read(catalogProvider).lessons;
});

final assignedLessonsProvider = Provider<List<Lesson>>((ref) {
  ref.watch(catalogProvider);
  return ref.read(catalogProvider).assigned;
});

final learnerProvider = Provider<LearnerProfile>((ref) {
  final auth = ref.watch(authControllerProvider);
  final mock = MockData.learner;

  if (!auth.isAuthenticated || auth.displayName.isEmpty) return mock;

  return LearnerProfile(
    name: auth.displayName,
    avatarEmoji: auth.avatarEmoji,
    level: auth.level,
    xp: auth.xp,
    xpToNextLevel: (auth.level * 500).clamp(500, 999999),
    streakDays: auth.streakDays,
    lessonsCompleted: auth.lessonsCompleted,
    minutesLearned: auth.minutesLearned,
  );
});

final badgesProvider = Provider<List<RewardBadge>>((ref) {
  ref.watch(catalogProvider);
  return ref.read(catalogProvider).badges;
});

final leaderboardProvider = Provider<List<LeaderboardEntry>>((ref) {
  ref.watch(catalogProvider);
  final prefs = ref.watch(userPreferencesProvider).whenOrNull(data: (p) => p);
  if (prefs != null && !prefs.joinLeaderboard) return const [];
  return ref.read(catalogProvider).leaderboard;
});

final teacherLessonsProvider = FutureProvider<List<Lesson>>((ref) async {
  ref.watch(authControllerProvider);
  if (!SupabaseService.instance.isInitialized) {
    return MockData.lessons.take(3).toList();
  }
  final result = await SupabaseService.instance.fetchTeacherLessons();
  return result.data ?? MockData.lessons.take(3).toList();
});

final teacherMetricsProvider = FutureProvider<TeacherMetrics>((ref) async {
  ref.watch(authControllerProvider);
  if (!SupabaseService.instance.isInitialized) {
    return const TeacherMetrics(studentCount: 1, lessonCount: 5, avgMastery: 0.72);
  }
  final result = await SupabaseService.instance.fetchTeacherMetrics();
  return result.data ?? const TeacherMetrics(studentCount: 0, lessonCount: 0, avgMastery: 0);
});

final rosterProvider = FutureProvider<List<StudentPerformance>>((ref) async {
  ref.watch(authControllerProvider);
  if (!SupabaseService.instance.isInitialized) return MockData.classRoster;
  final result = await SupabaseService.instance.fetchClassRoster();
  if (result.isSuccess && result.data!.isNotEmpty) return result.data!;
  return MockData.classRoster;
});

final userPreferencesProvider = FutureProvider<UserPreferences>((ref) async {
  ref.watch(authControllerProvider);
  if (!SupabaseService.instance.isInitialized) return const UserPreferences();
  final result = await SupabaseService.instance.fetchUserPreferences();
  return result.data ?? const UserPreferences();
});

final dailyGoalProvider = FutureProvider<DailyGoalProgress>((ref) async {
  ref.watch(authControllerProvider);
  if (!SupabaseService.instance.isInitialized) {
    return const DailyGoalProgress(completed: 3, target: 5);
  }
  final result = await SupabaseService.instance.fetchDailyGoal();
  return result.data ?? const DailyGoalProgress(completed: 0, target: 5);
});

final subjectSkillsProvider = FutureProvider<List<SubjectSkill>>((ref) async {
  ref.watch(authControllerProvider);
  ref.watch(catalogProvider);
  if (!SupabaseService.instance.isInitialized) {
    return const [
      SubjectSkill(subject: 'Mandarin tones', mastery: 0.82),
      SubjectSkill(subject: 'Reading fluency', mastery: 0.74),
      SubjectSkill(subject: 'Maths reasoning', mastery: 0.68),
      SubjectSkill(subject: 'Science facts', mastery: 0.55),
    ];
  }
  final result = await SupabaseService.instance.fetchSubjectSkills();
  if (result.isSuccess && result.data!.isNotEmpty) return result.data!;
  return const [
    SubjectSkill(subject: 'Getting started', mastery: 0.2),
  ];
});

final teacherRecentTestsProvider = FutureProvider.autoDispose<List<LiveTest>>((ref) async {
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
final liveTestSnapshotProvider = StreamProvider.autoDispose.family<LiveTestSnapshot?, String>((ref, testId) {
  if (!SupabaseService.instance.isInitialized) {
    return Stream.value(null);
  }
  return LiveTestService.instance.watchSnapshot(testId);
});

final liveTestDetailProvider = StreamProvider.autoDispose.family<LiveTest?, String>((ref, testId) async* {
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

Lesson lessonById(WidgetRef ref, String id) =>
    ref.read(lessonsProvider).firstWhere((l) => l.id == id);

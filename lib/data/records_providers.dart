import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/learning_records_models.dart';
import '../services/learning_records_service.dart';
import 'app_state.dart';
import 'auth_state.dart';

final myExamAttemptsProvider = FutureProvider.autoDispose<List<ExamAttempt>>((
  ref,
) {
  ref.watch(authControllerProvider);
  return LearningRecordsService.instance.fetchAttempts(limit: 20);
});

final myMistakeGroupsProvider = FutureProvider.autoDispose<List<MistakeGroup>>((
  ref,
) async {
  ref.watch(authControllerProvider);
  final mistakes = await LearningRecordsService.instance.fetchOpenMistakes();
  return groupMistakes(mistakes);
});

final myMathsResultsProvider = FutureProvider.autoDispose<List<MathsResult>>((
  ref,
) {
  ref.watch(authControllerProvider);
  return LearningRecordsService.instance.fetchMaths();
});

typedef StudentAssignments = ({
  List<ClassAssignment> assignments,
  Map<String, AssignmentSubmission> submissions,
});

final myAssignmentsProvider = FutureProvider.autoDispose<StudentAssignments>((
  ref,
) async {
  ref.watch(authControllerProvider);
  final service = LearningRecordsService.instance;
  final results = await Future.wait([
    service.fetchMyAssignments(),
    service.fetchMySubmissions(),
  ]);
  return (
    assignments: results[0] as List<ClassAssignment>,
    submissions: results[1] as Map<String, AssignmentSubmission>,
  );
});

final classAssignmentsProvider =
    FutureProvider.autoDispose<List<AssignmentProgress>>((ref) async {
      final info = await ref.watch(teacherClassInfoProvider.future);
      if (info == null) return const [];
      return LearningRecordsService.instance.fetchClassAssignments(info.id);
    });

/// Null means the signed-in student's own report.
final progressReportProvider = FutureProvider.autoDispose
    .family<ProgressReport, String?>((ref, userId) {
      ref.watch(authControllerProvider);
      return LearningRecordsService.instance.fetchReport(userId: userId);
    });

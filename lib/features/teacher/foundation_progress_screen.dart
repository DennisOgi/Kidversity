import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_state.dart';
import '../../models/mandarin_content.dart';
import '../../services/foundation_progress_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/error_boundary.dart';

class FoundationProgressScreen extends ConsumerWidget {
  const FoundationProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = ref.watch(mandarinCourseProvider);
    final progress = ref.watch(foundationClassProgressProvider);
    return ShellScrollView(
      children: [
        Text(
          'Foundation progress',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          'See exactly where each learner is on the 30-lesson path.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 22),
        course.when(
          loading: () => const LoadingIndicator(),
          error: (error, _) => ErrorDisplay(
            message: 'The course could not be loaded.',
            error: error,
          ),
          data: (loadedCourse) => progress.when(
            loading: () =>
                const LoadingIndicator(message: 'Loading class progress…'),
            error: (error, _) => ErrorDisplay(
              message: 'Class progress could not be loaded.',
              error: error,
              onRetry: () => ref.invalidate(foundationClassProgressProvider),
            ),
            data: (students) => students.isEmpty
                ? const _NoStudents()
                : Column(
                    children: [
                      _ClassOverview(students: students, course: loadedCourse),
                      const SizedBox(height: 18),
                      for (final student in students) ...[
                        _StudentMap(student: student, course: loadedCourse),
                        const SizedBox(height: 14),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _ClassOverview extends StatelessWidget {
  final List<FoundationStudentProgress> students;
  final MandarinCourse course;

  const _ClassOverview({required this.students, required this.course});

  @override
  Widget build(BuildContext context) {
    final completed = students.fold<int>(
      0,
      (sum, student) => sum + student.completedLessonIds.length,
    );
    final possible = students.length * course.lessons.length;
    final averageProgress = possible == 0 ? 0 : completed / possible;
    final averageScore =
        students.fold<double>(0, (sum, student) => sum + student.averageScore) /
        students.length;
    final stalled = students.where((student) => student.isStalled).length;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _Metric(
          label: 'Class completion',
          value: '${(averageProgress * 100).round()}%',
        ),
        _Metric(label: 'Average score', value: '${averageScore.round()}%'),
        _Metric(label: 'Need a check-in', value: '$stalled'),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 190,
    child: GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 5),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
        ],
      ),
    ),
  );
}

class _StudentMap extends StatelessWidget {
  final FoundationStudentProgress student;
  final MandarinCourse course;

  const _StudentMap({required this.student, required this.course});

  @override
  Widget build(BuildContext context) {
    final completed = student.completedLessonIds.length;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(student.avatarEmoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '$completed/30 lessons · ${student.averageScore.round()}% average',
                    ),
                    if (student.isStalled)
                      const Text(
                        'May need a check-in',
                        style: TextStyle(
                          color: AppColors.cinnabar,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${((completed / 30) * 100).round()}%',
                style: const TextStyle(
                  color: AppColors.cinnabar,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: completed / 30,
              minHeight: 9,
              backgroundColor: AppColors.backgroundAlt,
              color: AppColors.jade,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final module in course.modules)
                Text(
                  '${module.title}: '
                  '${module.lessons.where((lesson) => student.completedLessonIds.contains(lesson.id)).length}'
                  '/${module.lessons.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (student.weakItemIds.isNotEmpty)
                Text(
                  '${student.weakItemIds.length} answers to revisit',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.cinnabar,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final lesson in course.lessons)
                Tooltip(
                  message:
                      '${lesson.sequence}. ${lesson.title}'
                      '${student.scoresByLesson[lesson.id] == null ? '' : ' · ${student.scoresByLesson[lesson.id]}%'}',
                  child: Container(
                    width: 31,
                    height: 31,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: student.completedLessonIds.contains(lesson.id)
                          ? AppColors.jade
                          : AppColors.backgroundAlt,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Text(
                      '${lesson.sequence}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: student.completedLessonIds.contains(lesson.id)
                            ? Colors.white
                            : AppColors.muted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoStudents extends StatelessWidget {
  const _NoStudents();

  @override
  Widget build(BuildContext context) => const GlassCard(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 30),
      child: Center(
        child: Text(
          'Share your class code to add learners and see their Foundation path.',
        ),
      ),
    ),
  );
}

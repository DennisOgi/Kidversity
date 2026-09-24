import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../data/auth_state.dart';
import '../../data/records_providers.dart';
import '../../models/learning_records_models.dart';
import '../../models/mandarin_content.dart';
import '../../router/navigation.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/live_test_widgets.dart';
import '../../widgets/labs_entry_card.dart';
import '../../widgets/surfaces.dart';

class StudentHomeScreen extends ConsumerWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(authControllerProvider).displayName.trim();
    final greeting = name.isEmpty ? 'Welcome back' : 'Hello, $name';
    final course = ref.watch(mandarinCourseProvider);
    final completed =
        ref
            .watch(foundationCompletedLessonIdsProvider)
            .whenOrNull(data: (ids) => ids) ??
        const <String>{};

    return ShellScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _LiveQuizBanner(),
                PageIntro(
                  eyebrow: 'Your learning home',
                  title: greeting,
                  body: 'Pick up where you left off, or open a world.',
                ),
                const SizedBox(height: 18),
                const _TeacherWork(),
                course.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(),
                  ),
                  error: (_, _) => const _ResumeFallback(),
                  data: (value) =>
                      _ResumeCard(course: value, completedLessonIds: completed),
                ),
                const SizedBox(height: 28),
                const PageIntro(
                  eyebrow: 'Learning worlds',
                  title: 'Five doors. One home.',
                  body:
                      'Mandarin, exams, play, mental maths, and a bench of experiments.',
                ),
                const SizedBox(height: 14),
                const _WorldGrid(),
                const SizedBox(height: 14),
                LabsEntryCard(onTap: () => context.go(AppRoutes.studentLabs)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LiveQuizBanner extends ConsumerWidget {
  const _LiveQuizBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(activeLiveTestProvider)
        .when(
          data: (test) {
            if (test == null || !test.isActive) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: LiveTestAlertBanner(
                test: test,
                onJoin: () => context.go(AppRoutes.studentLiveTest(test.id)),
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        );
  }
}

class _TeacherWork extends ConsumerWidget {
  const _TeacherWork();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref
        .watch(myAssignmentsProvider)
        .whenOrNull(data: (value) => value);
    if (data == null || data.assignments.isEmpty) {
      return const SizedBox.shrink();
    }
    final lessonsDone =
        ref
            .watch(foundationCompletedLessonIdsProvider)
            .whenOrNull(data: (ids) => ids) ??
        const <String>{};
    bool done(ClassAssignment a) => a.kind == AssignmentKind.lesson
        ? lessonsDone.contains(a.lessonId)
        : data.submissions.containsKey(a.id);

    final open = data.assignments.where((a) => !done(a)).toList()
      ..sort((a, b) {
        final ad = a.dueAt ?? DateTime(9999);
        final bd = b.dueAt ?? DateTime(9999);
        return ad.compareTo(bd);
      });
    final finished = data.assignments.length - open.length;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('From your teacher', style: text.titleLarge),
                  const Spacer(),
                  Text(
                    open.isEmpty
                        ? 'All $finished done'
                        : '${open.length} to do · $finished done',
                    style: text.bodyMedium?.copyWith(
                      color: open.isEmpty
                          ? AppColors.success
                          : AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (open.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Nothing waiting. New work shows up here.',
                    style: text.bodyMedium,
                  ),
                ),
              for (final assignment in open.take(5))
                _AssignmentRow(assignment: assignment),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssignmentRow extends StatelessWidget {
  final ClassAssignment assignment;

  const _AssignmentRow({required this.assignment});

  void _open(BuildContext context) {
    switch (assignment.kind) {
      case AssignmentKind.exam:
        final config = assignment.examConfig;
        if (config != null) {
          context.push(AppRoutes.studentExamSession, extra: config);
        }
      case AssignmentKind.lesson:
        final id = assignment.lessonId;
        if (id != null) context.go(AppRoutes.mandarinLesson(id));
      case AssignmentKind.maths:
        context.go(
          '${AppRoutes.studentMaths}?level=${assignment.mathsLevel ?? 1}'
          '&assignment=${assignment.id}',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final due = assignment.dueAt;
    final icon = switch (assignment.kind) {
      AssignmentKind.exam => Icons.assignment_outlined,
      AssignmentKind.lesson => Icons.translate_rounded,
      AssignmentKind.maths => Icons.calculate_outlined,
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        foregroundColor: AppColors.primary,
        child: Icon(icon, size: 20),
      ),
      title: Text(assignment.title),
      subtitle: Text(
        due == null
            ? assignment.kind.label
            : '${assignment.kind.label} · due ${due.day}/${due.month}',
        style: text.bodySmall?.copyWith(
          color: assignment.isOverdue ? AppColors.danger : AppColors.inkSoft,
        ),
      ),
      trailing: FilledButton(
        onPressed: () => _open(context),
        child: const Text('Start'),
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  final MandarinCourse course;
  final Set<String> completedLessonIds;

  const _ResumeCard({required this.course, required this.completedLessonIds});

  @override
  Widget build(BuildContext context) {
    final lessons = [...course.lessons]
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    MandarinCourseLesson? next;
    for (final lesson in lessons) {
      if (lesson.isPlayable &&
          isFoundationLessonUnlocked(lesson, completedLessonIds, lessons) &&
          !completedLessonIds.contains(lesson.id)) {
        next = lesson;
        break;
      }
    }
    final done = lessons
        .where((lesson) => completedLessonIds.contains(lesson.id))
        .length;
    final text = Theme.of(context).textTheme;

    if (next == null && done == 0) {
      return const _ResumeFallback();
    }

    final title = next == null
        ? 'Mandarin Foundation complete'
        : next.sequence == 1 && done == 0
        ? 'Start Mandarin Lesson 1'
        : 'Continue lesson ${next.sequence}';
    final detail = next == null
        ? 'You finished the sequenced path. Practice and exams are still open.'
        : next.title;
    final action = next == null ? 'Open the path' : 'Continue lesson';
    final route = next == null
        ? AppRoutes.studentMandarin
        : AppRoutes.mandarinLesson(next.id);

    return Material(
      color: AppColors.primary,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: () => context.go(route),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final split = constraints.maxWidth >= 720;
            final copy = Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NEXT STEP',
                    style: text.labelLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 11,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: text.headlineSmall?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: text.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  if (lessons.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: done / lessons.length,
                        minHeight: 7,
                        backgroundColor: Colors.white.withValues(alpha: 0.22),
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$done of ${lessons.length} Mandarin lessons complete',
                      style: text.bodySmall?.copyWith(color: Colors.white70),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                    ),
                    onPressed: () => context.go(route),
                    child: Text(action),
                  ),
                ],
              ),
            );
            if (!split) return copy;
            return Row(
              children: [
                Expanded(flex: 6, child: copy),
                const Expanded(
                  flex: 4,
                  child: SizedBox(
                    height: 228,
                    child: WarmAssetImage(
                      'assets/illustrations/world-mandarin.png',
                      alignment: Alignment.centerRight,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ResumeFallback extends StatelessWidget {
  const _ResumeFallback();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose where to start',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Open a learning world below. Your progress will show here once a lesson is underway.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _WorldGrid extends StatelessWidget {
  const _WorldGrid();

  static const _worlds = [
    (
      'assets/illustrations/world-mandarin.png',
      'Language',
      'Mandarin Foundation',
      'Sequenced lessons with audio, practice, and quests.',
      AppColors.worldLanguage,
      AppRoutes.studentMandarin,
      false,
    ),
    (
      'assets/illustrations/world-exams.png',
      'Exams',
      'Nigerian past questions',
      'UTME, WASSCE, NECO, Post-UTME, and university screening.',
      AppColors.worldExams,
      AppRoutes.studentExams,
      true,
    ),
    (
      'assets/rope_pull/environment/campus-court.png',
      'Play',
      'Rope Pull',
      'Indigo and Teal pull. Words, past questions, or mental maths.',
      AppColors.worldPlay,
      AppRoutes.studentPlay,
      false,
    ),
    (
      'assets/illustrations/world-maths.png',
      'Maths',
      'Mental maths',
      'Twenty levels across number, fractions, money, measure, and algebra.',
      AppColors.accentTeal,
      AppRoutes.studentMaths,
      false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          for (final world in _worlds)
            _WorldEntry(
              asset: world.$1,
              label: world.$2,
              title: world.$3,
              body: world.$4,
              color: world.$5,
              route: world.$6,
              push: world.$7,
            ),
        ];
        if (constraints.maxWidth < 720) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                cards[i],
                if (i != cards.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final card in cards)
              SizedBox(width: (constraints.maxWidth - 14) / 2, child: card),
          ],
        );
      },
    );
  }
}

class _WorldEntry extends StatelessWidget {
  final String asset;
  final String label;
  final String title;
  final String body;
  final Color color;
  final String route;
  final bool push;

  const _WorldEntry({
    required this.asset,
    required this.label,
    required this.title,
    required this.body,
    required this.color,
    required this.route,
    this.push = false,
  });

  @override
  Widget build(BuildContext context) {
    return WorldTile(
      asset: asset,
      label: label,
      title: title,
      body: body,
      color: color,
      artHeight: 128,
      onTap: () => push ? context.push(route) : context.go(route),
    );
  }
}

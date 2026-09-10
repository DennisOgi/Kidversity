import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../data/auth_state.dart';
import '../../models/mandarin_content.dart';
import '../../router/navigation.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/error_boundary.dart';
import '../../widgets/live_test_widgets.dart';

class FoundationPathScreen extends ConsumerWidget {
  const FoundationPathScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = ref.watch(mandarinCourseProvider);
    final name = ref.watch(authControllerProvider).displayName;
    final completedLessonIds =
        ref
            .watch(foundationCompletedLessonIdsProvider)
            .whenOrNull(data: (value) => value) ??
        const <String>{};

    return course.when(
      loading: () => const Center(
        child: LoadingIndicator(message: 'Opening your Mandarin path…'),
      ),
      error: (error, _) => ErrorDisplay(
        message: 'The course path could not be loaded.',
        error: error,
        onRetry: () => ref.invalidate(mandarinCourseProvider),
      ),
      data: (value) {
        final lessons = [...value.lessons]
          ..sort((a, b) => a.sequence.compareTo(b.sequence));
        final unlocked = {
          for (final lesson in lessons)
            if (isFoundationLessonUnlocked(lesson, completedLessonIds, lessons))
              lesson.id,
        };
        MandarinCourseLesson? next;
        for (final lesson in lessons) {
          if (lesson.isPlayable &&
              unlocked.contains(lesson.id) &&
              !completedLessonIds.contains(lesson.id)) {
            next = lesson;
            break;
          }
        }
        final done = lessons
            .where((lesson) => completedLessonIds.contains(lesson.id))
            .length;

        return ShellScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            const _ActiveLiveSection(),
            _WelcomeHeader(
              name: name,
              done: done,
              total: lessons.length,
              next: next,
            ),
            const SizedBox(height: 18),
            if (next != null) ...[
              _ContinueCard(lesson: next, isFirstLesson: next.sequence == 1),
              const SizedBox(height: 22),
            ] else
              const _CourseCompleteCard(),
            const _HowItWorks(),
            const SizedBox(height: 22),
            for (final module in value.modules)
              _ModuleSection(
                module: _sortedModule(module),
                completedLessonIds: completedLessonIds,
                unlockedLessonIds: unlocked,
                nextLessonId: next?.id,
              ),
          ],
        );
      },
    );
  }

  MandarinModule _sortedModule(MandarinModule module) {
    final lessons = [...module.lessons]
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    return MandarinModule(
      sequence: module.sequence,
      title: module.title,
      subtitle: module.subtitle,
      lessons: lessons,
    );
  }
}

class _ActiveLiveSection extends ConsumerWidget {
  const _ActiveLiveSection();

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

class _WelcomeHeader extends StatelessWidget {
  final String name;
  final int done;
  final int total;
  final MandarinCourseLesson? next;

  const _WelcomeHeader({
    required this.name,
    required this.done,
    required this.total,
    required this.next,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final greeting = name.trim().isEmpty ? 'Welcome' : 'Hi, ${name.trim()}';
    final progress = total == 0 ? 0.0 : done / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: text.headlineSmall?.copyWith(fontSize: 26, height: 1.1),
        ),
        const SizedBox(height: 6),
        Text(
          next == null
              ? 'You have finished the Mandarin Foundation path.'
              : next!.sequence == 1
              ? 'Start Lesson 1. Each lesson unlocks the next one.'
              : 'You are on Lesson ${next!.sequence} of $total.',
          style: text.bodyLarge?.copyWith(color: AppColors.inkSoft),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: AppColors.line,
            color: AppColors.cinnabar,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$done of $total lessons complete',
          style: text.labelLarge?.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }
}

class _ContinueCard extends StatelessWidget {
  final MandarinCourseLesson lesson;
  final bool isFirstLesson;

  const _ContinueCard({required this.lesson, required this.isFirstLesson});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: AppColors.ink,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.go(AppRoutes.mandarinLesson(lesson.id)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.cinnabar,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.paper,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFirstLesson ? 'START HERE' : 'CONTINUE',
                      style: text.labelLarge?.copyWith(
                        color: AppColors.gold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lesson ${lesson.sequence}. ${lesson.title}',
                      style: text.titleLarge?.copyWith(color: AppColors.paper),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lesson.objective,
                      style: text.bodyMedium?.copyWith(
                        color: AppColors.paper.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: AppColors.paper),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseCompleteCard extends StatelessWidget {
  const _CourseCompleteCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.jade.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.jade.withValues(alpha: 0.28)),
      ),
      child: Text(
        'The full 30-lesson path is complete. Use Practice to keep the words warm.',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.replay_rounded,
        'Warm-up recycles yesterday, last week, and earlier',
      ),
      (Icons.record_voice_over_rounded, 'Say it out loud before the quiz'),
      (Icons.school_outlined, 'Daily review keeps the path warm'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.$1, size: 16, color: AppColors.cinnabar),
                const SizedBox(width: 6),
                Text(
                  item.$2,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ModuleSection extends StatefulWidget {
  final MandarinModule module;
  final Set<String> completedLessonIds;
  final Set<String> unlockedLessonIds;
  final String? nextLessonId;

  const _ModuleSection({
    required this.module,
    required this.completedLessonIds,
    required this.unlockedLessonIds,
    required this.nextLessonId,
  });

  @override
  State<_ModuleSection> createState() => _ModuleSectionState();
}

class _ModuleSectionState extends State<_ModuleSection> {
  bool _showLocked = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final lessons = widget.module.lessons;
    final hasUnlocked = lessons.any(
      (lesson) => widget.unlockedLessonIds.contains(lesson.id),
    );
    final visible = lessons.where((lesson) {
      final unlocked = widget.unlockedLessonIds.contains(lesson.id);
      final done = widget.completedLessonIds.contains(lesson.id);
      if (unlocked || done) return true;
      return _showLocked;
    }).toList();
    final hiddenCount = lessons.length - visible.length;
    final doneCount = lessons
        .where((lesson) => widget.completedLessonIds.contains(lesson.id))
        .length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 2.4,
                  child: WarmAssetImage(_coverPath),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          AppColors.ink.withValues(alpha: 0.72),
                          AppColors.ink.withValues(alpha: 0.18),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MODULE ${widget.module.sequence}',
                        style: text.labelLarge?.copyWith(
                          color: AppColors.gold,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        widget.module.title,
                        style: text.titleLarge?.copyWith(
                          color: AppColors.paper,
                        ),
                      ),
                      Text(
                        '$doneCount / ${lessons.length} complete',
                        style: text.bodyMedium?.copyWith(
                          color: AppColors.paper.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          if (!hasUnlocked)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
              child: Text(
                'Opens after you finish the previous module quest.',
                style: text.bodyMedium?.copyWith(color: AppColors.muted),
              ),
            )
          else ...[
            for (final lesson in visible)
              _LessonRow(
                lesson: lesson,
                completed: widget.completedLessonIds.contains(lesson.id),
                unlocked: widget.unlockedLessonIds.contains(lesson.id),
                isNext: lesson.id == widget.nextLessonId,
              ),
            if (hiddenCount > 0)
              TextButton(
                onPressed: () => setState(() => _showLocked = true),
                child: Text('Show $hiddenCount upcoming lessons'),
              ),
          ],
        ],
      ),
    );
  }

  String get _coverPath => switch (widget.module.sequence) {
    1 => 'assets/mandarin/module_1_first_contact.png',
    2 => 'assets/mandarin/module_2_my_world.png',
    _ => 'assets/mandarin/module_3_everyday_mandarin.png',
  };
}

class _LessonRow extends StatelessWidget {
  final MandarinCourseLesson lesson;
  final bool completed;
  final bool unlocked;
  final bool isNext;

  const _LessonRow({
    required this.lesson,
    required this.completed,
    required this.unlocked,
    required this.isNext,
  });

  @override
  Widget build(BuildContext context) {
    final playable = lesson.isPlayable && unlocked;
    final text = Theme.of(context).textTheme;
    final status = completed
        ? 'Done'
        : isNext
        ? 'Up next'
        : playable
        ? '${lesson.xpReward} XP'
        : 'Finish the lesson above to unlock';

    return InkWell(
      onTap: playable
          ? () => context.go(AppRoutes.mandarinLesson(lesson.id))
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: completed
                    ? AppColors.jade
                    : playable
                    ? AppColors.cinnabar
                    : AppColors.line,
                shape: BoxShape.circle,
              ),
              child: Icon(
                completed
                    ? Icons.check_rounded
                    : playable
                    ? Icons.play_arrow_rounded
                    : Icons.lock_outline_rounded,
                size: 20,
                color: playable || completed
                    ? AppColors.paper
                    : AppColors.muted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${lesson.sequence}. ${lesson.title}',
                    style: text.titleMedium?.copyWith(
                      color: playable || completed
                          ? AppColors.ink
                          : AppColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status,
                    style: text.bodyMedium?.copyWith(
                      color: isNext ? AppColors.cinnabar : AppColors.muted,
                      fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (playable)
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

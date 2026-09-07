import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../models/mandarin_content.dart';
import '../../router/navigation.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/error_boundary.dart';
import '../../widgets/live_test_widgets.dart';

class FoundationPathScreen extends ConsumerWidget {
  const FoundationPathScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = ref.watch(mandarinCourseProvider);
    final completedLessonIds =
        ref
            .watch(foundationCompletedLessonIdsProvider)
            .whenOrNull(data: (value) => value) ??
        const <String>{};
    return ShellScrollView(
      children: [
        const _ActiveLiveSection(),
        const _CourseHero(),
        const SizedBox(height: 24),
        course.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 64),
            child: LoadingIndicator(message: 'Opening your Mandarin path…'),
          ),
          error: (error, _) => ErrorDisplay(
            message: 'The course path could not be loaded.',
            error: error,
            onRetry: () => ref.invalidate(mandarinCourseProvider),
          ),
          data: (value) {
            final unlockedLessonIds = {
              for (final lesson in value.lessons)
                if (isFoundationLessonUnlocked(
                  lesson,
                  completedLessonIds,
                  value.lessons,
                ))
                  lesson.id,
            };
            return Column(
              children: [
                for (final module in value.modules) ...[
                  _ModulePath(
                    module: module,
                    completedLessonIds: completedLessonIds,
                    unlockedLessonIds: unlockedLessonIds,
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            );
          },
        ),
      ],
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
              padding: const EdgeInsets.only(bottom: 20),
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

class _CourseHero extends StatelessWidget {
  const _CourseHero();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.mandarinGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.paper.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.8)),
            ),
            clipBehavior: Clip.antiAlias,
            child: const FoxMascotImage(),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mandarin Foundation',
                  style: text.headlineSmall?.copyWith(color: AppColors.paper),
                ),
                const SizedBox(height: 5),
                Text(
                  '30 lessons · 3 learning quests · complete beginner',
                  style: text.bodyMedium?.copyWith(
                    color: AppColors.paper.withValues(alpha: 0.86),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModulePath extends StatelessWidget {
  final MandarinModule module;
  final Set<String> completedLessonIds;
  final Set<String> unlockedLessonIds;

  const _ModulePath({
    required this.module,
    required this.completedLessonIds,
    required this.unlockedLessonIds,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            child: AspectRatio(
              aspectRatio: 16 / 6,
              child: Image.asset(_coverPath, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cinnabarSoft,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  'MODULE ${module.sequence}',
                  style: text.labelLarge?.copyWith(
                    color: AppColors.cinnabar,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(module.title, style: text.titleLarge),
                    const SizedBox(height: 3),
                    Text(module.subtitle, style: text.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < module.lessons.length; i++)
            _PathNode(
              lesson: module.lessons[i],
              completed: completedLessonIds.contains(module.lessons[i].id),
              unlocked: unlockedLessonIds.contains(module.lessons[i].id),
              isLast: i == module.lessons.length - 1,
            ),
        ],
      ),
    );
  }

  String get _coverPath => switch (module.sequence) {
    1 => 'assets/mandarin/module_1_first_contact.png',
    2 => 'assets/mandarin/module_2_my_world.png',
    _ => 'assets/mandarin/module_3_everyday_mandarin.png',
  };
}

class _PathNode extends StatelessWidget {
  final MandarinCourseLesson lesson;
  final bool completed;
  final bool unlocked;
  final bool isLast;

  const _PathNode({
    required this.lesson,
    required this.completed,
    required this.unlocked,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final playable = lesson.isPlayable && unlocked;
    final isQuest = lesson.sequence % 10 == 0;
    final nodeColor = playable ? AppColors.cinnabar : AppColors.muted;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 52,
            child: Column(
              children: [
                Material(
                  color: playable
                      ? AppColors.cinnabar
                      : AppColors.backgroundAlt,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: playable
                        ? () => context.go(AppRoutes.mandarinLesson(lesson.id))
                        : null,
                    child: SizedBox(
                      width: 46,
                      height: 46,
                      child: Icon(
                        playable
                            ? (completed
                                  ? Icons.check_rounded
                                  : isQuest
                                  ? Icons.flag_rounded
                                  : Icons.play_arrow_rounded)
                            : Icons.lock_outline_rounded,
                        color: playable ? AppColors.paper : AppColors.muted,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.ink.withValues(alpha: 0.12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                onTap: playable
                    ? () => context.go(AppRoutes.mandarinLesson(lesson.id))
                    : null,
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: playable ? AppColors.paper : AppColors.backgroundAlt,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: nodeColor.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${lesson.sequence}. ${lesson.title}',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: playable
                                        ? AppColors.ink
                                        : AppColors.inkSoft,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              lesson.objective,
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        completed
                            ? 'DONE'
                            : playable
                            ? '${lesson.xpReward} XP'
                            : lesson.isPlayable
                            ? 'LOCKED'
                            : lesson.status == CourseLessonStatus.shell
                            ? 'COMING'
                            : 'IN REVIEW',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: nodeColor,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

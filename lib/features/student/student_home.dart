import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../models/user_preferences.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../router/navigation.dart';
import '../../widgets/common.dart';
import '../../widgets/lesson_card.dart';
import '../../widgets/live_test_widgets.dart';
import '../../widgets/progress_ring.dart';

class StudentHome extends ConsumerWidget {
  const StudentHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learner = ref.watch(learnerProvider);
    final assigned = ref.watch(assignedLessonsProvider);
    final activeLive = ref.watch(activeLiveTestProvider).value;
    final cardWidth = (MediaQuery.sizeOf(context).width - 54).clamp(260.0, 300.0);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.paddingOf(context).bottom + 100,
      ),
      children: [
        _TopBar(learner: learner),
        if (activeLive != null && activeLive.isActive) ...[
          const SizedBox(height: 16),
          LiveTestAlertBanner(
            test: activeLive,
            onJoin: () => context.go(AppRoutes.studentLiveTest(activeLive.id)),
          ),
        ],
        const SizedBox(height: 20),
        _HeroCard(learner: learner),
        const SizedBox(height: 24),
        _QuickStats(learner: learner),
        const SizedBox(height: 24),
        SectionHeader(
          title: 'Continue learning',
          subtitle: 'Pick up where you left off',
          action: TextButton(
            onPressed: () => context.go('/student/explore'),
            child: const Text('See all'),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 270,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: assigned.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final lesson = assigned[i];
              return SizedBox(
                width: cardWidth,
                child: LessonCard(
                  lesson: lesson,
                  onTap: () => openStudentLesson(context, ref, lesson.id),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        const _DailyGoal(),
        const SizedBox(height: 20),
        const _RecommendedBanner(),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  final dynamic learner;
  const _TopBar({required this.learner});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final narrow = MediaQuery.sizeOf(context).width < 420;

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hi, ${learner.name}! 👋',
            style: text.headlineSmall?.copyWith(fontSize: 22),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text('Ready for today’s adventure?', style: text.bodyMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: AppColors.sunsetGradient,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    EmojiText('🔥', size: 16),
                    const SizedBox(width: 5),
                    Text('${learner.streakDays}',
                        style: text.titleMedium?.copyWith(color: Colors.white, fontSize: 15)),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
                alignment: Alignment.center,
                child: Text(learner.avatarEmoji, style: emojiTextStyle(size: 24)),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hi, ${learner.name}! 👋',
              style: text.headlineSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text('Ready for today’s adventure?', style: text.bodyMedium),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: AppColors.sunsetGradient,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: [
              EmojiText('🔥', size: 16),
              const SizedBox(width: 5),
              Text('${learner.streakDays}',
                  style: text.titleMedium?.copyWith(color: Colors.white, fontSize: 15)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
          alignment: Alignment.center,
          child: Text(learner.avatarEmoji, style: emojiTextStyle(size: 24)),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final dynamic learner;
  const _HeroCard({required this.learner});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      gradient: AppColors.brandGradient,
      padding: const EdgeInsets.all(22),
      shadow: AppTheme.softShadow,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Level ${learner.level} Explorer',
                    style: text.titleMedium?.copyWith(color: Colors.white, fontSize: 18)),
                const SizedBox(height: 6),
                Text('${learner.xpToNextLevel - learner.xp} XP to Level ${learner.level + 1}',
                    style: text.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: learner.levelProgress),
                    duration: const Duration(milliseconds: 900),
                    builder: (context, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 10,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      valueColor: const AlwaysStoppedAnimation(AppColors.accentYellow),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          ProgressRing(
            progress: learner.levelProgress,
            size: 78,
            color: AppColors.accentYellow,
            trackColor: Colors.white.withValues(alpha: 0.25),
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⭐', style: TextStyle(fontSize: 18)),
                Text('${learner.xp}',
                    style: text.titleMedium?.copyWith(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStats extends StatelessWidget {
  final dynamic learner;
  const _QuickStats({required this.learner});

  @override
  Widget build(BuildContext context) {
    final stats = [
      (Icons.menu_book_rounded, '${learner.lessonsCompleted}', 'Lessons', AppColors.primary),
      (Icons.timer_rounded, '${learner.minutesLearned ~/ 60}h', 'Learned', AppColors.accentTeal),
      (Icons.local_fire_department_rounded, '${learner.streakDays}', 'Day streak', AppColors.secondary),
    ];
    return Row(
      children: [
        for (int i = 0; i < stats.length; i++) ...[
          Expanded(
            child: GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              child: Column(
                children: [
                  SoftIcon(icon: stats[i].$1, color: stats[i].$4, size: 40),
                  const SizedBox(height: 8),
                  Text(stats[i].$2, style: Theme.of(context).textTheme.titleLarge),
                  Text(stats[i].$3, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
                ],
              ),
            ),
          ),
          if (i != stats.length - 1) const SizedBox(width: 12),
        ]
      ],
    );
  }
}

class _DailyGoal extends ConsumerWidget {
  const _DailyGoal();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(dailyGoalProvider).value ?? const DailyGoalProgress(completed: 0, target: 5);
    final text = Theme.of(context).textTheme;
    return GlassCard(
      child: Row(
        children: [
          ProgressRing(
            progress: goal.ratio,
            size: 58,
            color: AppColors.success,
            center: Text('${goal.completed}/${goal.target}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Today’s goal', style: text.titleMedium),
                const SizedBox(height: 2),
                Text(
                  goal.completed >= goal.target
                      ? 'Goal complete — amazing work today!'
                      : 'Finish ${goal.target - goal.completed} more checkpoints to keep your streak alive!',
                  style: text.bodyMedium?.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendedBanner extends ConsumerWidget {
  const _RecommendedBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      gradient: AppColors.tealGradient,
      child: Row(
        children: [
          const Text('🧭', style: TextStyle(fontSize: 36)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Next recommended step', style: text.titleMedium?.copyWith(color: Colors.white)),
                const SizedBox(height: 2),
                Text('Practice Mandarin tones — you’re 80% to Polyglot!',
                    style: text.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.95), fontSize: 13)),
              ],
            ),
          ),
          const Icon(Icons.arrow_circle_right_rounded, color: Colors.white, size: 30),
        ],
      ),
    );
  }
}

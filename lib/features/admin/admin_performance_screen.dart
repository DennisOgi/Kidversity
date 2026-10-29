import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../models/admin_models.dart';
import '../../router/navigation.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/empty_panel.dart';
import '../../widgets/error_boundary.dart';
import '../../widgets/surfaces.dart';

class AdminPerformanceScreen extends ConsumerStatefulWidget {
  final String? userId;

  const AdminPerformanceScreen({super.key, this.userId});

  @override
  ConsumerState<AdminPerformanceScreen> createState() =>
      _AdminPerformanceScreenState();
}

class _AdminPerformanceScreenState extends ConsumerState<AdminPerformanceScreen> {
  String? _pickedId;
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _pickedId = widget.userId;
    _search = TextEditingController();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = widget.userId ?? _pickedId;
    final users = ref.watch(adminUsersProvider);

    return ShellScrollView(
      children: [
        const PageIntro(
          eyebrow: 'Platform',
          title: 'Performance',
          body:
              'Open any learner to see Mandarin lessons covered, exam and maths averages, and recent activity.',
        ),
        const SizedBox(height: 14),
        if (selectedId == null) ...[
          TextField(
            controller: _search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Find a learner by name or email',
            ),
            onChanged: (value) {
              ref.read(adminUserSearchProvider.notifier).state = value;
            },
          ),
          const SizedBox(height: 14),
          users.when(
            loading: () => const LoadingIndicator(message: 'Loading users…'),
            error: (error, _) => ErrorDisplay(
              message: 'Users could not be loaded.',
              error: error,
              onRetry: () => ref.invalidate(adminUsersProvider),
            ),
            data: (page) {
              final learners = page.users
                  .where((u) => u.role == 'student' || u.role == 'teacher')
                  .toList();
              if (learners.isEmpty) {
                return const EmptyPanel(
                  icon: Icons.insights_rounded,
                  title: 'No users to show',
                  body: 'Search for a learner, or open one from Users.',
                );
              }
              return Column(
                children: [
                  for (final user in learners.take(30)) ...[
                    GlassCard(
                      onTap: () =>
                          context.go(AppRoutes.adminUserPerformance(user.userId)),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Text(
                            user.avatarEmoji,
                            style: const TextStyle(fontSize: 26),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.displayName,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                Text(
                                  '${user.lessonsCompleted} lessons · ${user.xp} XP'
                                  '${user.email == null ? '' : ' · ${user.email}'}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: AppColors.inkSoft),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        ] else
          _PerformanceDetail(userId: selectedId),
      ],
    );
  }
}

class _PerformanceDetail extends ConsumerWidget {
  final String userId;

  const _PerformanceDetail({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final performance = ref.watch(adminUserPerformanceProvider(userId));
    return performance.when(
      loading: () =>
          const LoadingIndicator(message: 'Loading performance…'),
      error: (error, _) => ErrorDisplay(
        message: 'Performance could not be loaded.',
        error: error,
        onRetry: () => ref.invalidate(adminUserPerformanceProvider(userId)),
      ),
      data: (data) => _PerformanceBody(data: data),
    );
  }
}

class _PerformanceBody extends StatelessWidget {
  final AdminUserPerformance data;

  const _PerformanceBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final maxDay = data.weeklyActivity.fold<int>(
      1,
      (m, d) => d.count > m ? d.count : m,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: () => context.go(AppRoutes.adminPerformance),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('All users'),
        ),
        const SizedBox(height: 14),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(data.avatarEmoji, style: const TextStyle(fontSize: 36)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.displayName, style: text.titleLarge),
                    Text(
                      '${data.role ?? 'user'}'
                      '${data.email == null ? '' : ' · ${data.email}'}'
                      '${data.active ? '' : ' · inactive'}',
                      style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                    ),
                    if (data.schools.isNotEmpty)
                      Text(
                        data.schools.map((s) => s.name).join(', '),
                        style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatChip(
              label: 'Foundation lessons',
              value: '${data.foundationCompleted}',
            ),
            _StatChip(
              label: 'Avg Mandarin score',
              value: '${data.foundationAvgScore.round()}%',
            ),
            _StatChip(
              label: 'This week',
              value: '+${data.lessonsThisWeek}',
            ),
            _StatChip(label: 'XP', value: '${data.xp}'),
            _StatChip(label: 'Streak', value: '${data.streakDays}d'),
            _StatChip(
              label: 'Minutes learned',
              value: '${data.minutesLearned}',
            ),
            _StatChip(
              label: 'Exam attempts',
              value: '${data.examAttempts} · ${data.examAvgScore.round()}%',
            ),
            _StatChip(
              label: 'Maths attempts',
              value: '${data.mathsAttempts} · ${data.mathsAvgScore.round()}%',
            ),
          ],
        ),
        const SizedBox(height: 24),
        const SectionHeader(
          title: 'Last 14 days',
          subtitle: 'Mandarin lessons completed per day',
        ),
        if (data.weeklyActivity.isEmpty)
          Text(
            'No recent lesson completions.',
            style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
          )
        else
          GlassCard(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
            child: SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final day in data.weeklyActivity) ...[
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: FractionallySizedBox(
                              heightFactor: (day.count / maxDay).clamp(0.08, 1),
                              widthFactor: 1,
                              alignment: Alignment.bottomCenter,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppColors.jade,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${day.count}',
                            style: text.labelSmall?.copyWith(
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        SectionHeader(
          title: 'Completed lesson IDs',
          subtitle: '${data.completedLessonIds.length} foundation results stored',
        ),
        if (data.completedLessonIds.isEmpty)
          Text(
            'No foundation lessons completed yet.',
            style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in data.completedLessonIds.take(40))
                Pill(label: id, color: AppColors.inkSoft),
            ],
          ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: 160,
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 6),
            Text(value, style: text.titleMedium),
          ],
        ),
      ),
    );
  }
}

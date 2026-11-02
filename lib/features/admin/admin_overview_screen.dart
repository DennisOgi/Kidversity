import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/features.dart';
import '../../data/app_state.dart';
import '../../models/admin_models.dart';
import '../../router/navigation.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/error_boundary.dart';
import '../../widgets/stat_grid.dart';
import '../../widgets/surfaces.dart';

class AdminOverviewScreen extends ConsumerWidget {
  const AdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(adminOverviewProvider);

    return ShellScrollView(
      children: [
        const PageIntro(
          eyebrow: 'Platform',
          title: 'Admin overview',
          body:
              'Schools, learners, and weekly learning activity across Kidversity.',
        ),
        const SizedBox(height: 18),
        overview.when(
          loading: () => const LoadingIndicator(message: 'Loading platform…'),
          error: (error, _) => ErrorDisplay(
            message: 'Overview could not be loaded.',
            error: error,
            onRetry: () => ref.invalidate(adminOverviewProvider),
          ),
          data: (data) => _OverviewBody(data: data),
        ),
      ],
    );
  }
}

class _OverviewBody extends StatelessWidget {
  final AdminOverview data;

  const _OverviewBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final activeShare = data.studentCount == 0
        ? 0
        : (data.active7d * 100 / data.studentCount).round();
    final week = [
      (
        'Mandarin lessons completed',
        data.lessonsThisWeek,
        AppColors.worldLanguage,
      ),
      ('Exam attempts', data.examAttemptsThisWeek, AppColors.worldExams),
      (
        'Mental maths attempts',
        data.mathsAttemptsThisWeek,
        AppColors.accentTeal,
      ),
      ('Live quiz sessions', data.liveSessionsThisWeek, AppColors.worldPlay),
    ];
    final weekMax = week.fold<int>(0, (m, row) => row.$2 > m ? row.$2 : m);
    final weekTotal = week.fold<int>(0, (sum, row) => sum + row.$2);

    final shortcuts = [
      (
        Icons.apartment_rounded,
        'Schools',
        'Create schools, add admins and teachers',
        AppRoutes.adminSchools,
      ),
      (
        Icons.people_rounded,
        'Users',
        'Find anyone, change roles, fix accounts',
        AppRoutes.adminUsers,
      ),
      (
        Icons.insights_rounded,
        'Performance',
        'Top learners and school comparisons',
        AppRoutes.adminPerformance,
      ),
      if (Features.payments)
        (
          Icons.payments_rounded,
          'Payments',
          'Pack sales, families, repeat buyers',
          AppRoutes.adminPayments,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatGrid(
          maxColumns: 3,
          tiles: [
            StatTile.count(
              label: 'Students',
              count: data.studentCount,
              icon: Icons.school_rounded,
            ),
            StatTile.count(
              label: 'Active in 7 days',
              count: data.active7d,
              icon: Icons.bolt_rounded,
              color: AppColors.success,
              caption: '$activeShare% of students',
            ),
            StatTile.count(
              label: 'Schools',
              count: data.schoolCount,
              icon: Icons.apartment_rounded,
              color: AppColors.ink,
            ),
            StatTile.count(
              label: 'Classes',
              count: data.classCount,
              icon: Icons.groups_rounded,
              color: AppColors.worldExams,
            ),
            StatTile.count(
              label: 'Teachers',
              count: data.teacherCount,
              icon: Icons.badge_rounded,
              color: AppColors.secondary,
            ),
            StatTile.count(
              label: 'Reviewers',
              count: data.reviewerCount,
              icon: Icons.fact_check_rounded,
              color: AppColors.accentPink,
            ),
          ],
        ),
        const SizedBox(height: 28),
        SectionHeader(
          title: 'This week',
          subtitle: weekTotal == 0
              ? 'No learning activity since Monday yet'
              : '$weekTotal learning actions since Monday',
        ),
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              for (var i = 0; i < week.length; i++) ...[
                if (i > 0) const SizedBox(height: 16),
                ShareBar(
                  label: week[i].$1,
                  value: week[i].$2,
                  max: weekMax,
                  color: week[i].$3,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 28),
        const SectionHeader(
          title: 'Shortcuts',
          subtitle: 'Jump into the ops you use most',
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? shortcuts.length.clamp(1, 4)
                : constraints.maxWidth >= 560
                ? 2
                : 1;
            final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final item in shortcuts)
                  SizedBox(
                    width: width,
                    child: LiftCard(
                      onTap: () => context.go(item.$4),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          SoftIcon(icon: item.$1, size: 40),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.$2,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                Text(
                                  item.$3,
                                  maxLines: 2,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: AppColors.inkSoft),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../models/admin_models.dart';
import '../../router/navigation.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/error_boundary.dart';
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
          body: 'Schools, learners, and weekly learning activity across Kidversity.',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Kpi(
              label: 'Schools',
              value: '${data.schoolCount}',
              icon: Icons.apartment_rounded,
              color: AppColors.ink,
            ),
            _Kpi(
              label: 'Students',
              value: '${data.studentCount}',
              icon: Icons.school_rounded,
              color: AppColors.primary,
            ),
            _Kpi(
              label: 'Teachers',
              value: '${data.teacherCount}',
              icon: Icons.badge_rounded,
              color: AppColors.secondary,
            ),
            _Kpi(
              label: 'Active 7d',
              value: '${data.active7d}',
              icon: Icons.bolt_rounded,
              color: AppColors.jade,
            ),
            _Kpi(
              label: 'Classes',
              value: '${data.classCount}',
              icon: Icons.groups_rounded,
              color: AppColors.accentBlue,
            ),
            _Kpi(
              label: 'Reviewers',
              value: '${data.reviewerCount}',
              icon: Icons.fact_check_rounded,
              color: AppColors.cinnabar,
            ),
          ],
        ),
        const SizedBox(height: 28),
        const SectionHeader(
          title: 'This week',
          subtitle: 'Learning activity since Monday',
        ),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _WeekRow(
                label: 'Mandarin lessons completed',
                value: '${data.lessonsThisWeek}',
              ),
              const Divider(height: 22),
              _WeekRow(
                label: 'Live quiz sessions',
                value: '${data.liveSessionsThisWeek}',
              ),
              const Divider(height: 22),
              _WeekRow(
                label: 'Exam attempts',
                value: '${data.examAttemptsThisWeek}',
              ),
              const Divider(height: 22),
              _WeekRow(
                label: 'Mental maths attempts',
                value: '${data.mathsAttemptsThisWeek}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const SectionHeader(
          title: 'Shortcuts',
          subtitle: 'Jump into the ops you use most',
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.adminSchools),
              icon: const Icon(Icons.apartment_rounded),
              label: const Text('Schools'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go(AppRoutes.adminUsers),
              icon: const Icon(Icons.people_rounded),
              label: const Text('Users'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go(AppRoutes.adminPerformance),
              icon: const Icon(Icons.insights_rounded),
              label: const Text('Performance'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _Kpi({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: 160,
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(value, style: text.headlineSmall?.copyWith(fontSize: 26)),
            const SizedBox(height: 2),
            Text(
              label,
              style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekRow extends StatelessWidget {
  final String label;
  final String value;

  const _WeekRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(child: Text(label, style: text.bodyMedium)),
        Text(
          value,
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

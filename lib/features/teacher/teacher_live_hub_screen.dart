import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../models/live_test_models.dart';
import '../../services/live_test_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/live_test_widgets.dart';

/// Teacher hub for approved Mandarin live-quiz templates.
class TeacherLiveHubScreen extends ConsumerStatefulWidget {
  const TeacherLiveHubScreen({super.key});

  @override
  ConsumerState<TeacherLiveHubScreen> createState() =>
      _TeacherLiveHubScreenState();
}

class _TeacherLiveHubScreenState extends ConsumerState<TeacherLiveHubScreen> {
  bool _busy = false;
  static const int _duration = 300;

  Future<void> _launch(LiveQuizTemplate template) async {
    setState(() => _busy = true);
    try {
      final result = await LiveTestService.instance.createFromTemplate(
        template,
        durationSeconds: _duration,
      );

      if (!mounted) return;
      if (result.isFailure || result.data == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.error ?? 'Failed')));
        return;
      }

      final start = await LiveTestService.instance.startTest(result.data!.id);
      if (!mounted) return;
      if (start.isFailure || start.data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(start.error ?? 'Could not start')),
        );
        return;
      }

      context.go('/teacher/live/${start.data!.id}/monitor');
      ref.invalidate(teacherRecentTestsProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final roster = ref.watch(rosterProvider).whenOrNull(data: (d) => d) ?? [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.bolt_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Live Quiz', style: text.headlineSmall),
                  Text(
                    'Timed tests with real-time student responses',
                    style: text.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        GlassCard(
          gradient: LinearGradient(
            colors: [
              AppColors.danger.withValues(alpha: 0.12),
              AppColors.secondarySoft,
            ],
          ),
          child: Row(
            children: [
              const LivePulseBadge(),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  roster.isEmpty
                      ? 'Students in your class will get an instant alert when you go live.'
                      : '${roster.length} students ready — they\'ll see a banner as soon as you start.',
                  style: text.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SectionHeader(
          title: 'Quick start templates',
          subtitle: 'One tap to go live',
        ),
        const SizedBox(height: 12),
        for (final t in LiveQuizTemplate.all) ...[
          _TemplateCard(template: t, busy: _busy, onLaunch: () => _launch(t)),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 28),
        const SectionHeader(
          title: 'Recent sessions',
          subtitle: 'Review past live quizzes',
        ),
        const SizedBox(height: 12),
        _RecentSessionsList(busy: _busy),
      ],
    );
  }
}

class _RecentSessionsList extends ConsumerWidget {
  final bool busy;

  const _RecentSessionsList({required this.busy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final recent = ref.watch(teacherRecentTestsProvider);

    return recent.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, _) => GlassCard(
        child: Text('Could not load recent sessions', style: text.bodyMedium),
      ),
      data: (tests) {
        if (tests.isEmpty) {
          return GlassCard(
            child: Text(
              'No live quizzes yet — launch your first one above!',
              style: text.bodyMedium,
            ),
          );
        }
        return Column(
          children: [
            for (final t in tests) ...[
              _RecentTestRow(test: t, busy: busy),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _RecentTestRow extends StatelessWidget {
  final LiveTest test;
  final bool busy;

  const _RecentTestRow({required this.test, required this.busy});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final statusLabel = switch (test.status) {
      LiveTestStatus.live => 'Live now',
      LiveTestStatus.ended => 'Ended',
      LiveTestStatus.draft => 'Draft',
    };
    final statusColor = switch (test.status) {
      LiveTestStatus.live => AppColors.danger,
      LiveTestStatus.ended => AppColors.muted,
      LiveTestStatus.draft => AppColors.warning,
    };
    final durationMin = test.durationSeconds ~/ 60;

    return GlassCard(
      onTap: busy
          ? null
          : () {
              if (test.status == LiveTestStatus.live) {
                context.go('/teacher/live/${test.id}/monitor');
              } else if (test.status == LiveTestStatus.ended) {
                context.go('/teacher/live/${test.id}/monitor');
              }
            },
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              test.status == LiveTestStatus.live
                  ? Icons.sensors_rounded
                  : Icons.history_rounded,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  test.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(fontSize: 15),
                ),
                Text(
                  '${test.questions.length} Q · $durationMin min · ${test.subject}',
                  style: text.bodySmall?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusLabel,
              style: text.labelSmall?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final LiveQuizTemplate template;
  final bool busy;
  final VoidCallback onLaunch;

  const _TemplateCard({
    required this.template,
    required this.busy,
    required this.onLaunch,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      onTap: busy ? null : onLaunch,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: template.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(template.emoji, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(template.title, style: text.titleMedium),
                Text(
                  '${template.questions.length} questions · ${template.subject}',
                  style: text.bodyMedium,
                ),
              ],
            ),
          ),
          Icon(Icons.rocket_launch_rounded, color: template.color),
        ],
      ),
    );
  }
}

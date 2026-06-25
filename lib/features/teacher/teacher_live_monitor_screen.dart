import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../models/live_test_models.dart';
import '../../services/live_test_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/live_test_widgets.dart';

/// Real-time teacher dashboard — participant progress + answer heatmap.
class TeacherLiveMonitorScreen extends ConsumerWidget {
  final String testId;

  const TeacherLiveMonitorScreen({super.key, required this.testId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(liveTestSnapshotProvider(testId));
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go('/teacher/live'),
        ),
        title: const Text('Live monitor'),
        actions: [
          snapshotAsync.whenOrNull(
            data: (snap) => snap != null && snap.test.status == LiveTestStatus.live
                ? TextButton.icon(
                    onPressed: () async {
                      await LiveTestService.instance.endTest(testId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quiz ended')));
                      }
                    },
                    icon: const Icon(Icons.stop_circle_outlined, color: AppColors.danger),
                    label: const Text('End quiz', style: TextStyle(color: AppColors.danger)),
                  )
                : null,
          ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: snapshotAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load: $e')),
        data: (snap) {
          if (snap == null) return const Center(child: Text('Test not found'));
          final test = snap.test;
          final joined = snap.participants.length;
          final submitted = snap.submittedCount;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            children: [
              Row(
                children: [
                  if (test.status == LiveTestStatus.live) const LivePulseBadge(),
                  if (test.status == LiveTestStatus.live) const SizedBox(width: 12),
                  Expanded(child: Text(test.title, style: text.headlineSmall)),
                ],
              ),
              if (test.joinCode != null) ...[
                const SizedBox(height: 8),
                JoinCodeChip(code: test.joinCode!),
              ],
              const SizedBox(height: 16),
              LiveCountdownTimer(
                endsAt: test.endsAt,
                onExpired: () async {
                  if (test.status == LiveTestStatus.live) {
                    await LiveTestService.instance.endTest(testId);
                  }
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _StatTile(label: 'Joined', value: '$joined', icon: Icons.people_rounded, color: AppColors.primary)),
                  const SizedBox(width: 10),
                  Expanded(child: _StatTile(label: 'Submitted', value: '$submitted', icon: Icons.check_rounded, color: AppColors.success)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      label: 'Avg score',
                      value: joined == 0 ? '—' : snap.averageScore.toStringAsFixed(1),
                      icon: Icons.leaderboard_rounded,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (snap.participants.isNotEmpty) ...[
                const SectionHeader(title: 'Live leaderboard', subtitle: 'Top scores update instantly'),
                const SizedBox(height: 12),
                GlassCard(child: LiveLeaderboard(participants: snap.leaderboard)),
                const SizedBox(height: 24),
              ],
              const SectionHeader(title: 'Students', subtitle: 'Updates in real time'),
              const SizedBox(height: 10),
              if (snap.participants.isEmpty)
                GlassCard(child: Text('Waiting for students to join…', style: text.bodyLarge))
              else
                for (final p in snap.leaderboard)
                  _ParticipantRow(participant: p, snapshot: snap),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Answer breakdown', subtitle: 'See class understanding instantly'),
              const SizedBox(height: 10),
              for (final q in test.questions) ...[
                GlassCard(
                  child: AnswerDistributionBar(
                    question: q,
                    counts: snap.optionCounts(q.id),
                    total: snap.participants.where((p) => p.status != ParticipantStatus.waiting).length,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (test.status == LiveTestStatus.ended) ...[
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => context.go('/teacher/live'),
                  child: const Text('Back to Live Quiz hub'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 6),
          Text(value, style: text.titleLarge),
          Text(label, style: text.bodySmall),
        ],
      ),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  final LiveTestParticipant participant;
  final LiveTestSnapshot snapshot;

  const _ParticipantRow({required this.participant, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final totalQuestions = snapshot.test.questions.length;
    final answered = snapshot.answeredCount(participant.userId);
    final progress = snapshot.participantProgress(participant);
    final statusLabel = switch (participant.status) {
      ParticipantStatus.submitted => 'Done',
      ParticipantStatus.active => 'In progress',
      ParticipantStatus.waiting => 'Waiting',
    };
    final statusColor = switch (participant.status) {
      ParticipantStatus.submitted => AppColors.success,
      ParticipantStatus.active => AppColors.primary,
      ParticipantStatus.waiting => AppColors.muted,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text(participant.avatarEmoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(participant.displayName, style: text.titleMedium?.copyWith(fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('$answered / $totalQuestions answered', style: text.bodySmall?.copyWith(color: AppColors.muted)),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: progress.clamp(0, 1), minHeight: 6, backgroundColor: AppColors.line),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${participant.score}/$totalQuestions', style: text.titleMedium),
                Text(statusLabel, style: text.bodySmall?.copyWith(color: statusColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

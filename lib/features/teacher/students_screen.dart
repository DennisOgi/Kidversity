import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_state.dart';
import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/progress_ring.dart';

class StudentsScreen extends ConsumerWidget {
  const StudentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rosterAsync = ref.watch(rosterProvider);
    final roster = rosterAsync.whenOrNull(data: (d) => d) ?? const <StudentPerformance>[];
    final text = Theme.of(context).textTheme;
    final avg = roster.isEmpty
        ? 0.0
        : roster.map((s) => s.overallMastery).reduce((a, b) => a + b) / roster.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
      children: [
        Text('My class', style: text.headlineSmall),
        Text('Progress, strengths & growth areas', style: text.bodyMedium),
        const SizedBox(height: 18),
        GlassCard(
          child: Row(
            children: [
              ProgressRing(progress: avg, size: 56, color: AppColors.success),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Class mastery', style: text.titleMedium?.copyWith(fontSize: 14)),
                    Text('${roster.length} students enrolled', style: text.bodyMedium?.copyWith(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const SectionHeader(title: 'Students'),
        if (rosterAsync.isLoading)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else if (roster.isEmpty)
          GlassCard(child: Text('No students in your class yet.', style: text.bodyLarge))
        else
          for (final s in roster) ...[
            _StudentCard(student: s),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _StudentCard extends StatelessWidget {
  final StudentPerformance student;
  const _StudentCard({required this.student});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
                alignment: Alignment.center,
                child: Text(student.avatarEmoji, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.name, style: text.titleMedium?.copyWith(fontSize: 16)),
                    Text('${student.lessonsDone} lessons done', style: text.bodyMedium?.copyWith(fontSize: 12.5)),
                  ],
                ),
              ),
              ProgressRing(progress: student.overallMastery, size: 50, stroke: 6, color: _masteryColor(student.overallMastery)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _tag(context, '💪 Strength', student.strength, AppColors.success)),
              const SizedBox(width: 10),
              Expanded(child: _tag(context, '🎯 Focus next', student.growthArea, AppColors.warning)),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('This week', style: text.bodyMedium?.copyWith(fontSize: 12, color: AppColors.muted)),
          ),
          const SizedBox(height: 8),
          MiniBarChart(values: student.weeklyActivity, color: _masteryColor(student.overallMastery), height: 44),
        ],
      ),
    );
  }

  Color _masteryColor(double v) =>
      v >= 0.75 ? AppColors.success : v >= 0.5 ? AppColors.primary : AppColors.warning;

  Widget _tag(BuildContext context, String label, String value, Color color) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.bodyMedium?.copyWith(fontSize: 11.5, color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(value, style: text.titleMedium?.copyWith(fontSize: 14)),
        ],
      ),
    );
  }
}

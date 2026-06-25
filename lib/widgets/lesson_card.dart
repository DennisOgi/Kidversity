import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'common.dart';

String sourceLabel(ContentSource s) => switch (s) {
      ContentSource.uploaded => 'Uploaded',
      ContentSource.aiGenerated => 'AI-Generated',
      ContentSource.hybrid => 'Hybrid',
    };

IconData sourceIcon(ContentSource s) => switch (s) {
      ContentSource.uploaded => Icons.upload_file_rounded,
      ContentSource.aiGenerated => Icons.auto_awesome_rounded,
      ContentSource.hybrid => Icons.blender_rounded,
    };

/// Rich lesson tile used across student & teacher views.
class LessonCard extends StatelessWidget {
  final Lesson lesson;
  final VoidCallback? onTap;
  final bool compact;
  const LessonCard({super.key, required this.lesson, this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [lesson.color, lesson.color.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                alignment: Alignment.center,
                child: Text(lesson.emoji, style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lesson.subject.toUpperCase(),
                        style: text.labelLarge?.copyWith(
                            color: lesson.color, fontSize: 11, letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    Text(lesson.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium?.copyWith(fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 12),
            Text(lesson.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium?.copyWith(fontSize: 13.5)),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              _meta(context, Icons.collections_bookmark_rounded, '${lesson.slideCount} slides'),
              const SizedBox(width: 14),
              _meta(context, Icons.schedule_rounded, '${lesson.estimatedTime.inMinutes} min'),
            ],
          ),
          const SizedBox(height: 12),
          if (lesson.progress > 0) ...[
            _ProgressBar(value: lesson.progress, color: lesson.color),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Pill(
                label: sourceLabel(lesson.source),
                icon: sourceIcon(lesson.source),
                color: lesson.source == ContentSource.aiGenerated
                    ? AppColors.primary
                    : lesson.source == ContentSource.hybrid
                        ? AppColors.accentTeal
                        : AppColors.secondary,
              ),
              const Spacer(),
              Pill(label: '+${lesson.xpReward} XP', icon: Icons.bolt_rounded, color: AppColors.accentYellow),
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(BuildContext context, IconData icon, String label) => Row(
        children: [
          Icon(icon, size: 15, color: AppColors.muted),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5, color: AppColors.muted)),
        ],
      );
}

class _ProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  const _ProgressBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 8,
              backgroundColor: AppColors.line,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(value >= 1 ? 'Completed 🎉' : '${(value * 100).round()}% complete',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 12, color: value >= 1 ? AppColors.success : AppColors.muted, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../models/class_board_models.dart';
import '../theme/app_colors.dart';
import 'common.dart';

class ClassBoardCard extends StatelessWidget {
  final ClassBoardSnapshot snapshot;
  final bool teacherView;
  final ValueChanged<bool>? onOptInChanged;

  const ClassBoardCard({
    super.key,
    required this.snapshot,
    this.teacherView = false,
    this.onOptInChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (!snapshot.hasClass && !teacherView) {
      return GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Class board', style: text.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Join your class to see this week’s lessons and XP.',
              style: text.bodyMedium,
            ),
          ],
        ),
      );
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Class board', style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      teacherView
                          ? 'Learning movement this week · ${snapshot.weekLabel}'
                          : 'Lessons finished and XP earned this week · ${snapshot.weekLabel}',
                      style: text.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Pill(
                label: 'MOVEMENT',
                color: AppColors.gold,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (snapshot.entries.isEmpty)
            Row(
              children: [
                for (var seat = 0; seat < 3; seat++) ...[
                  if (seat > 0) const SizedBox(width: 8),
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.paper,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.line),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      size: 18,
                      color: AppColors.muted,
                    ),
                  ),
                ],
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    teacherView
                        ? 'Waiting for the first learner. Names appear after someone joins and finishes a lesson.'
                        : 'Be the first this week. Turn on the class board below.',
                    style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
                  ),
                ),
              ],
            )
          else
            for (final entry in snapshot.entries)
              _BoardRow(
                entry: entry,
                teacherView: teacherView,
              ),
          if (teacherView && snapshot.hiddenCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              snapshot.hiddenCount == 1
                  ? '1 learner is hidden from the student board.'
                  : '${snapshot.hiddenCount} learners are hidden from the student board.',
              style: text.bodySmall?.copyWith(color: AppColors.muted),
            ),
          ],
          if (!teacherView && onOptInChanged != null) ...[
            const Divider(height: 28),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Show me on the class board',
                        style: text.titleMedium?.copyWith(fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Your teacher and classmates who opted in can see your name, XP, and lessons this week.',
                        style: text.bodySmall?.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: snapshot.viewerOptedIn,
                  activeThumbColor: AppColors.primary,
                  onChanged: onOptInChanged,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BoardRow extends StatelessWidget {
  final ClassBoardEntry entry;
  final bool teacherView;

  const _BoardRow({required this.entry, required this.teacherView});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final medal = switch (entry.rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => null,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: entry.isYou
            ? AppColors.gold.withValues(alpha: 0.12)
            : AppColors.backgroundAlt.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: entry.isYou
            ? Border.all(color: AppColors.gold.withValues(alpha: 0.4))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: medal != null
                ? EmojiText(medal, size: 18)
                : Text(
                    '${entry.rank}',
                    textAlign: TextAlign.center,
                    style: text.titleMedium?.copyWith(fontSize: 15),
                  ),
          ),
          const SizedBox(width: 8),
          EmojiText(entry.avatar, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.isYou ? '${entry.displayName} (you)' : entry.displayName,
                  style: text.titleMedium?.copyWith(fontSize: 15),
                ),
                Text(
                  '${entry.weeklyLessons} lesson${entry.weeklyLessons == 1 ? '' : 's'} moved · ${entry.weeklyXp} XP',
                  style: text.bodySmall?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          if (teacherView && !entry.optedIn)
            Text(
              'Hidden',
              style: text.labelLarge?.copyWith(
                color: AppColors.muted,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_state.dart';
import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(badgesProvider);
    final board = ref.watch(leaderboardProvider);
    final text = Theme.of(context).textTheme;
    final unlocked = badges.where((b) => b.unlocked).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
      children: [
            Text('Rewards', style: text.headlineSmall),
            Text('Celebrate your effort and streaks', style: text.bodyMedium),
            const SizedBox(height: 18),
            GlassCard(
              gradient: AppColors.goldGradient,
              child: Row(
                children: [
                  const Text('🏅', style: TextStyle(fontSize: 40)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$unlocked of ${badges.length} badges earned',
                            style: text.titleMedium?.copyWith(color: Colors.white, fontSize: 17)),
                        const SizedBox(height: 2),
                        Text('Keep your streak going to unlock more!',
                            style: text.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.95), fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const SectionHeader(title: 'Your badges'),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.82,
              children: [for (final b in badges) _BadgeTile(badge: b)],
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Class leaderboard', subtitle: 'Opt-in & privacy protected'),
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  for (int i = 0; i < board.length; i++) ...[
                    _LeaderRow(entry: board[i]),
                    if (i != board.length - 1) const Divider(indent: 16, endIndent: 16, height: 1),
                  ]
                ],
              ),
            ),
          ],
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final RewardBadge badge;
  const _BadgeTile({required this.badge});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      padding: const EdgeInsets.all(10),
      onTap: () => _showBadge(context),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: badge.unlocked
                      ? LinearGradient(colors: [badge.color, badge.color.withValues(alpha: 0.6)])
                      : null,
                  color: badge.unlocked ? null : AppColors.line,
                ),
                alignment: Alignment.center,
                child: Opacity(
                  opacity: badge.unlocked ? 1 : 0.4,
                  child: Text(badge.emoji, style: const TextStyle(fontSize: 28)),
                ),
              ),
              if (!badge.unlocked)
                const Icon(Icons.lock_rounded, size: 20, color: AppColors.muted),
            ],
          ),
          const SizedBox(height: 8),
          Text(badge.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleMedium?.copyWith(fontSize: 12.5)),
          if (!badge.unlocked) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: badge.progress,
                minHeight: 5,
                backgroundColor: AppColors.line,
                valueColor: AlwaysStoppedAnimation(badge.color),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showBadge(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: badge.unlocked
                    ? LinearGradient(colors: [badge.color, badge.color.withValues(alpha: 0.6)])
                    : null,
                color: badge.unlocked ? null : AppColors.line,
              ),
              alignment: Alignment.center,
              child: Text(badge.emoji, style: TextStyle(fontSize: 50, color: badge.unlocked ? null : Colors.white)),
            ),
            const SizedBox(height: 16),
            Text(badge.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(badge.description,
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 12),
            Pill(
              label: badge.unlocked ? 'Unlocked 🎉' : '${(badge.progress * 100).round()}% there',
              color: badge.unlocked ? AppColors.success : badge.color,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _LeaderRow extends StatelessWidget {
  final LeaderboardEntry entry;
  const _LeaderRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final medal = switch (entry.rank) { 1 => '🥇', 2 => '🥈', 3 => '🥉', _ => '${entry.rank}' };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: entry.isCurrentUser ? AppColors.primarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          SizedBox(width: 28, child: Text(medal, style: text.titleMedium, textAlign: TextAlign.center)),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppColors.backgroundAlt,
            child: Text(entry.avatarEmoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.isCurrentUser ? '${entry.name} (You)' : entry.name,
                    style: text.titleMedium?.copyWith(fontSize: 15)),
                if (entry.tag.isNotEmpty)
                  Text(entry.tag, style: text.bodyMedium?.copyWith(fontSize: 12, color: AppColors.secondary)),
              ],
            ),
          ),
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: AppColors.accentYellow, size: 18),
              Text('${entry.xp}', style: text.titleMedium?.copyWith(fontSize: 15)),
            ],
          ),
        ],
      ),
    );
  }
}

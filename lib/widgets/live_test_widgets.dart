import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/live_test_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Animated countdown for live tests.
class LiveCountdownTimer extends StatefulWidget {
  final DateTime? endsAt;
  final VoidCallback? onExpired;
  final bool compact;

  const LiveCountdownTimer({
    super.key,
    required this.endsAt,
    this.onExpired,
    this.compact = false,
  });

  @override
  State<LiveCountdownTimer> createState() => _LiveCountdownTimerState();
}

class _LiveCountdownTimerState extends State<LiveCountdownTimer> {
  Duration _remaining = Duration.zero;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  @override
  void didUpdateWidget(LiveCountdownTimer old) {
    super.didUpdateWidget(old);
    if (old.endsAt != widget.endsAt) _tick();
  }

  void _tick() {
    if (!mounted) return;
    final ends = widget.endsAt;
    if (ends == null) return;

    final left = ends.difference(DateTime.now());
    setState(() {
      _remaining = left.isNegative ? Duration.zero : left;
      if (left.isNegative && !_expired) {
        _expired = true;
        widget.onExpired?.call();
      }
    });

    if (_remaining > Duration.zero) {
      Future.delayed(const Duration(seconds: 1), _tick);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final mins = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    final urgent = _remaining.inSeconds <= 60;

    if (widget.compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: urgent ? AppColors.dangerSoft : AppColors.primarySoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_rounded, size: 16, color: urgent ? AppColors.danger : AppColors.primary),
            const SizedBox(width: 6),
            Text('$mins:$secs', style: text.titleMedium?.copyWith(
              color: urgent ? AppColors.danger : AppColors.primary,
              fontFeatures: const [FontFeature.tabularFigures()],
            )),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: urgent ? AppColors.sunsetGradient : AppColors.brandGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          Text(_remaining > Duration.zero ? 'Time remaining' : 'Time\'s up!',
              style: text.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
          const SizedBox(height: 8),
          Text('$mins:$secs',
              style: text.displayMedium?.copyWith(
                color: Colors.white,
                fontSize: 42,
                fontFeatures: const [FontFeature.tabularFigures()],
              )),
        ],
      ),
    );
  }
}

/// Pulsing "LIVE" badge for monitor screens.
class LivePulseBadge extends StatefulWidget {
  const LivePulseBadge({super.key});

  @override
  State<LivePulseBadge> createState() => _LivePulseBadgeState();
}

class _LivePulseBadgeState extends State<LivePulseBadge> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.12 + _c.value * 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: AppColors.danger, shape: BoxShape.circle, boxShadow: [
                BoxShadow(color: AppColors.danger.withValues(alpha: 0.6), blurRadius: 6 + _c.value * 4),
              ]),
            ),
            const SizedBox(width: 8),
            Text('LIVE', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.danger, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// Student banner when a live test is active.
class LiveTestAlertBanner extends StatelessWidget {
  final LiveTest test;
  final VoidCallback onJoin;

  const LiveTestAlertBanner({super.key, required this.test, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.danger.withValues(alpha: 0.9), AppColors.secondary]),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(color: AppColors.danger.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onJoin,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const LivePulseBadge(),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Live quiz in progress!', style: text.titleMedium?.copyWith(color: Colors.white)),
                      Text(test.title, style: text.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
                    ],
                  ),
                ),
                LiveCountdownTimer(endsAt: test.endsAt, compact: true),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal bar showing answer distribution per option.
class AnswerDistributionBar extends StatelessWidget {
  final LiveTestQuestion question;
  final Map<String, int> counts;
  final int total;

  const AnswerDistributionBar({
    super.key,
    required this.question,
    required this.counts,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question.prompt, style: text.titleMedium?.copyWith(fontSize: 15)),
        const SizedBox(height: 10),
        for (final opt in question.options) ...[
          _OptionBar(
            label: opt.label,
            count: counts[opt.id] ?? 0,
            total: total,
            isCorrect: opt.isCorrect,
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _OptionBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final bool isCorrect;

  const _OptionBar({
    required this.label,
    required this.count,
    required this.total,
    required this.isCorrect,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : count / total;
    final color = isCorrect ? AppColors.success : AppColors.primary;
    return Row(
      children: [
        SizedBox(width: 72, child: Text('$count', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14))),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 32,
                decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(8)),
              ),
              FractionallySizedBox(
                widthFactor: fraction.clamp(0.05, 1.0),
                child: Container(
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isCorrect ? 0.85 : 0.45),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isCorrect ? Colors.white : AppColors.ink)),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isCorrect) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18)),
      ],
    );
  }
}

/// Copyable join code for students joining manually.
class JoinCodeChip extends StatelessWidget {
  final String code;

  const JoinCodeChip({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        onTap: () {
          Clipboard.setData(ClipboardData(text: code));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Join code copied'), duration: Duration(seconds: 2)),
          );
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tag_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Code: $code', style: text.titleMedium?.copyWith(color: AppColors.primary, letterSpacing: 2)),
              const SizedBox(width: 8),
              Icon(Icons.copy_rounded, size: 16, color: AppColors.primary.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Top scorers podium for the live monitor.
class LiveLeaderboard extends StatelessWidget {
  final List<LiveTestParticipant> participants;

  const LiveLeaderboard({super.key, required this.participants});

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final top = participants.take(3).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < top.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _PodiumTile(
              rank: i + 1,
              participant: top[i],
              height: i == 0 ? 92 : (i == 1 ? 72 : 58),
              text: text,
            ),
          ),
        ],
      ],
    );
  }
}

class _PodiumTile extends StatelessWidget {
  final int rank;
  final LiveTestParticipant participant;
  final double height;
  final TextTheme text;

  const _PodiumTile({
    required this.rank,
    required this.participant,
    required this.height,
    required this.text,
  });

  Color get _rankColor => switch (rank) {
        1 => const Color(0xFFFFD700),
        2 => const Color(0xFFC0C0C0),
        _ => const Color(0xFFCD7F32),
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(participant.avatarEmoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 4),
        Text(participant.displayName, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: text.labelLarge?.copyWith(fontSize: 12)),
        Text('${participant.score} pts', style: text.bodySmall?.copyWith(color: AppColors.muted)),
        const SizedBox(height: 8),
        Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_rankColor.withValues(alpha: 0.35), _rankColor.withValues(alpha: 0.12)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: _rankColor.withValues(alpha: 0.5)),
          ),
          alignment: Alignment.center,
          child: Text('#$rank', style: text.titleLarge?.copyWith(color: _rankColor)),
        ),
      ],
    );
  }
}

/// Question progress dots for student quiz navigation.
class QuestionProgressDots extends StatelessWidget {
  final int total;
  final int current;
  final Set<int> answered;

  const QuestionProgressDots({
    super.key,
    required this.total,
    required this.current,
    required this.answered,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          Container(
            width: i == current ? 22 : 10,
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: i == current
                  ? AppColors.primary
                  : answered.contains(i)
                      ? AppColors.success.withValues(alpha: 0.7)
                      : AppColors.line,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/motion.dart';
import 'common.dart';

/// One number on a dashboard: icon, value, label, optional caption.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? caption;
  final VoidCallback? onTap;

  /// When set, the value counts up from zero on first build.
  final int? countTo;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.primary,
    this.caption,
    this.onTap,
    this.countTo,
  });

  /// Numeric tile that counts up to [count].
  const StatTile.count({
    super.key,
    required this.label,
    required int count,
    required this.icon,
    this.color = AppColors.primary,
    this.caption,
    this.onTap,
  }) : value = '$count',
       countTo = count;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final valueStyle = text.headlineSmall?.copyWith(
      fontSize: 26,
      height: 1.1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final target = countTo;
    final valueText = target == null || target <= 0
        ? Text(value, style: valueStyle, maxLines: 1)
        : TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: target.toDouble()),
            duration: AppMotion.of(context, const Duration(milliseconds: 700)),
            curve: AppMotion.easeOut,
            builder: (context, v, _) =>
                Text('${v.round()}', style: valueStyle, maxLines: 1),
          );

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          SoftIcon(icon: icon, color: color, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: valueText,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (caption != null)
                  Text(
                    caption!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: AppColors.muted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lays tiles out in even columns: 2 on phones, 3 on tablets, up to
/// [maxColumns] on wide screens. Rows share one height.
class StatGrid extends StatelessWidget {
  final List<Widget> tiles;
  final int maxColumns;
  final double gap;

  const StatGrid({
    super.key,
    required this.tiles,
    this.maxColumns = 4,
    this.gap = 12,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final fit = width >= 900
            ? maxColumns
            : width >= 600
            ? 3
            : 2;
        final columns = fit.clamp(1, tiles.isEmpty ? 1 : tiles.length);
        final rows = <Widget>[];
        for (var start = 0; start < tiles.length; start += columns) {
          final cells = <Widget>[];
          for (var c = 0; c < columns; c++) {
            final i = start + c;
            if (c > 0) cells.add(SizedBox(width: gap));
            cells.add(
              Expanded(child: i < tiles.length ? tiles[i] : const SizedBox()),
            );
          }
          if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: cells,
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}

/// Horizontal bar for "how much of X" lists (weekly activity, subjects).
class ShareBar extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final Color color;

  const ShareBar({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final share = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: text.bodyMedium)),
            Text(
              '$value',
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: share),
            duration: AppMotion.of(context, const Duration(milliseconds: 600)),
            curve: AppMotion.easeOut,
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 8,
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
        ),
      ],
    );
  }
}

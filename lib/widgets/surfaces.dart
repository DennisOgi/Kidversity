import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Eyebrow label used above page titles.
class Eyebrow extends StatelessWidget {
  final String text;
  final Color color;

  const Eyebrow(
    this.text, {
    super.key,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: color,
        height: 1.2,
      ),
    );
  }
}

/// Title + supporting line used at the top of most student pages.
class PageIntro extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? body;
  final Widget? trailing;

  const PageIntro({
    super.key,
    required this.eyebrow,
    required this.title,
    this.body,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow(eyebrow),
              const SizedBox(height: 8),
              Text(title, style: text.headlineSmall),
              if (body != null) ...[
                const SizedBox(height: 6),
                Text(
                  body!,
                  style: text.bodyLarge?.copyWith(color: AppColors.inkSoft),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 16), trailing!],
      ],
    );
  }
}

/// White card that lifts on hover and presses in on tap.
class LiftCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Color? borderColor;
  final Color? hoverBorder;

  const LiftCard({
    super.key,
    required this.child,
    this.onTap,
    this.color = AppColors.surface,
    this.padding,
    this.radius = 18,
    this.borderColor,
    this.hoverBorder,
  });

  @override
  State<LiftCard> createState() => _LiftCardState();
}

class _LiftCardState extends State<LiftCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.985 : (_hovered ? 1.012 : 1.0);
    final border = _hovered
        ? (widget.hoverBorder ?? AppColors.primary.withValues(alpha: 0.35))
        : (widget.borderColor ?? AppColors.line);

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: border),
        boxShadow: _hovered
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ]
            : AppTheme.cardShadow,
      ),
      child: widget.child,
    );

    return MouseRegion(
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = true),
        onTapUp: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = false),
        onTapCancel: widget.onTap == null
            ? null
            : () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: card,
        ),
      ),
    );
  }
}

/// A learning-world tile: illustration, eyebrow, title, one line of body.
class WorldTile extends StatelessWidget {
  final String asset;
  final String label;
  final String title;
  final String body;
  final Color color;
  final VoidCallback onTap;
  final double artHeight;

  const WorldTile({
    super.key,
    required this.asset,
    required this.label,
    required this.title,
    required this.body,
    required this.color,
    required this.onTap,
    this.artHeight = 118,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return LiftCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      hoverBorder: color.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
            child: SizedBox(
              height: artHeight,
              width: double.infinity,
              child: asset.isEmpty
                  ? ColoredBox(
                      color: color.withValues(alpha: 0.12),
                      child: Icon(Icons.door_front_door_rounded, color: color),
                    )
                  : WarmAssetImage(
                      asset,
                      alignment: Alignment.topCenter,
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(label, color: color),
                const SizedBox(height: 6),
                Text(title, style: text.titleLarge),
                const SizedBox(height: 4),
                Text(body, style: text.bodyMedium, maxLines: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Three door-chips used on splash and landing to preview the worlds.
class WorldHintRow extends StatelessWidget {
  final bool compact;

  const WorldHintRow({super.key, this.compact = false});

  static const items = [
    (Icons.translate_rounded, 'Mandarin', AppColors.worldLanguage),
    (Icons.menu_book_rounded, 'Exams', AppColors.worldExams),
    (Icons.sports_esports_rounded, 'Play', AppColors.worldPlay),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final item in items)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 12,
              vertical: compact ? 6 : 8,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.$1, size: 15, color: item.$3),
                const SizedBox(width: 6),
                Text(
                  item.$2,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 12,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

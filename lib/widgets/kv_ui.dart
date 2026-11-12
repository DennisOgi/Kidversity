import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../theme/role_style.dart';

/// Building blocks for the colorful dashboards: a hero banner, tinted cards,
/// metric tiles, status chips, and a responsive page frame.

/// Gradients for each role's hero banner. White text passes 4.5:1 on the
/// left two thirds of each, where the copy sits.
abstract final class HeroColors {
  static const student = [
    Color(0xFF3B2BC0),
    Color(0xFF5B3FE0),
    Color(0xFF8A5CF0),
  ];
  static const teacher = [
    Color(0xFF0A5E46),
    Color(0xFF0F7A5A),
    Color(0xFF15916B),
  ];
  static const parent = [
    Color(0xFFB8332A),
    Color(0xFFD9483A),
    Color(0xFFE8613F),
  ];
  static const school = [
    Color(0xFF20213B),
    Color(0xFF2E2B6B),
    Color(0xFF4433CC),
  ];
}

/// A scrolling page with a centered column and even gaps between sections.
class KvPage extends StatelessWidget {
  final List<Widget> children;
  final double maxWidth;
  final double gap;
  final Future<void> Function()? onRefresh;

  const KvPage({
    super.key,
    required this.children,
    this.maxWidth = 1200,
    this.gap = 24,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final side = width < 600 ? 16.0 : 28.0;
    final spaced = <Widget>[];
    for (final child in children) {
      if (spaced.isNotEmpty) spaced.add(SizedBox(height: gap));
      spaced.add(child);
    }
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        side,
        width < 600 ? 16 : 26,
        side,
        MediaQuery.paddingOf(context).bottom + 40,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: spaced,
            ),
          ),
        ),
      ],
    );
    final refresh = onRefresh;
    if (refresh == null) return list;
    return RefreshIndicator(onRefresh: refresh, child: list);
  }
}

/// Side by side from [breakpoint] wide, stacked below it.
class AdaptiveRow extends StatelessWidget {
  final List<Widget> children;
  final List<int>? flex;
  final double breakpoint;
  final double gap;

  const AdaptiveRow({
    super.key,
    required this.children,
    this.flex,
    this.breakpoint = 860,
    this.gap = 20,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: gap),
                children[i],
              ],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                Expanded(flex: flex?[i] ?? 1, child: children[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A grid whose column count follows the width: each tile is at least
/// [minTileWidth] wide, never more than [maxColumns] per row.
class AdaptiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minTileWidth;
  final int maxColumns;
  final double gap;

  const AdaptiveGrid({
    super.key,
    required this.children,
    this.minTileWidth = 220,
    this.maxColumns = 4,
    this.gap = 16,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        var columns = ((width + gap) / (minTileWidth + gap)).floor();
        columns = columns.clamp(1, maxColumns);
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += columns) {
          final slice = children.sublist(
            i,
            (i + columns).clamp(0, children.length),
          );
          if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < columns; j++) ...[
                    if (j > 0) SizedBox(width: gap),
                    Expanded(
                      child: j < slice.length
                          ? slice[j]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}

/// A bold gradient banner with playful shapes. Copy is white.
class HeroBanner extends StatelessWidget {
  final List<Color> colors;
  final String? eyebrow;
  final String title;
  final String? body;
  final List<Widget> actions;
  final Widget? child;

  const HeroBanner({
    super.key,
    required this.colors,
    required this.title,
    this.eyebrow,
    this.body,
    this.actions = const [],
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return ClipRRect(
      borderRadius: BorderRadius.circular(compact ? 20 : 24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: Stack(
          children: [
            // On phones the copy spans the full width, so the sun shape
            // shrinks into the corner where it cannot sit behind text.
            Positioned(
              right: compact ? -46 : -60,
              top: compact ? -58 : -70,
              child: _Blob(
                size: compact ? 104 : 220,
                color: const Color(0xFFFFC845),
              ),
            ),
            Positioned(
              right: compact ? 10 : 140,
              bottom: -80,
              child: _Blob(
                size: compact ? 120 : 160,
                color:
                    (colors == HeroColors.parent
                            ? const Color(0xFF8A5CF0)
                            : const Color(0xFFFF6B5B))
                        .withValues(alpha: 0.9),
              ),
            ),
            if (!compact)
              Positioned(
                right: 50,
                top: 130,
                child: Transform.rotate(
                  angle: 0.32,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: colors == HeroColors.teacher
                          ? const Color(0xFF2F8FEA)
                          : const Color(0xFF22B07D),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.all(compact ? 20 : 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (eyebrow != null)
                    Text(
                      eyebrow!,
                      style: const TextStyle(
                        color: Color(0xFFF1EEFF),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  const SizedBox(height: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: compact ? 23 : 29,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (body != null) ...[
                    const SizedBox(height: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Text(
                        body!,
                        style: const TextStyle(
                          color: Color(0xFFF7F5FF),
                          fontSize: 15,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                  if (child != null) ...[
                    const SizedBox(height: 18),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 580),
                      child: child,
                    ),
                  ],
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Wrap(spacing: 10, runSpacing: 10, children: actions),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;

  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
}

/// The yellow call-to-action used on hero banners.
class SunButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const SunButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      backgroundColor: AppTint.sun.strong,
      foregroundColor: AppColors.ink,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Color(0xFFD9A21C), offset: Offset(0, 5)),
        ],
      ),
      child: icon == null
          ? FilledButton(onPressed: onPressed, style: style, child: Text(label))
          : FilledButton.icon(
              onPressed: onPressed,
              style: style,
              iconAlignment: IconAlignment.end,
              icon: Icon(icon, size: 20),
              label: Text(label),
            ),
    );
  }
}

/// Outlined white button for use on a hero banner.
class HeroGhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const HeroGhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: Colors.white.withValues(alpha: 0.12),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
    return icon == null
        ? OutlinedButton(onPressed: onPressed, style: style, child: Text(label))
        : OutlinedButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: 20),
            label: Text(label),
          );
  }
}

/// A white or tinted card with a soft border. Tappable when [onTap] is set.
class KvCard extends StatelessWidget {
  final Widget child;
  final AppTint? tint;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const KvCard({
    super.key,
    required this.child,
    this.tint,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final t = tint;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(
        color: t == null
            ? const Color(0xFFE6E4F0)
            : Color.alphaBlend(t.strong.withValues(alpha: 0.28), t.soft),
      ),
    );
    final body = Padding(padding: padding, child: child);
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: Material(
        color: t?.soft ?? AppColors.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? body
            : InkWell(
                onTap: onTap,
                hoverColor: (t?.strong ?? AppColors.primary).withValues(
                  alpha: 0.06,
                ),
                child: body,
              ),
      ),
    );
  }
}

/// A rounded square holding an icon or a short glyph.
class TintIcon extends StatelessWidget {
  final AppTint tint;
  final IconData? icon;
  final String? glyph;
  final double size;
  final bool solid;

  const TintIcon({
    super.key,
    required this.tint,
    this.icon,
    this.glyph,
    this.size = 44,
    this.solid = true,
  });

  @override
  Widget build(BuildContext context) {
    final fg = solid
        ? (tint == AppTint.sun ? AppColors.ink : Colors.white)
        : tint.ink;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: solid ? tint.strong : tint.soft,
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: icon != null
            ? Icon(icon, color: fg, size: size * 0.48)
            : Text(
                glyph ?? '',
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  fontSize: size * 0.42,
                ),
              ),
      ),
    );
  }
}

/// A rounded progress bar in a tint.
class KvBar extends StatelessWidget {
  final double value;
  final AppTint tint;
  final double height;
  final Color? track;

  const KvBar({
    super.key,
    required this.value,
    required this.tint,
    this.height = 8,
    this.track,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1).toDouble(),
        minHeight: height,
        color: tint.strong,
        backgroundColor:
            track ??
            Color.alphaBlend(tint.strong.withValues(alpha: 0.18), tint.soft),
      ),
    );
  }
}

/// A pill that names a state in words, never by color alone.
class StatusChip extends StatelessWidget {
  final String label;
  final AppTint tint;
  final IconData? icon;

  const StatusChip({
    super.key,
    required this.label,
    required this.tint,
    this.icon,
  });

  /// Red-pink for things that need action now.
  static const alert = AppTint(
    Color(0xFFE0457B),
    Color(0xFFFDECEE),
    Color(0xFFA61F2D),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tint.soft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: tint.ink),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: tint.ink,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// A tinted number tile: label, big value, and a caption.
class MetricTile extends StatelessWidget {
  final AppTint tint;
  final String label;
  final String value;
  final String? caption;
  final IconData? icon;
  final Widget? footer;
  final VoidCallback? onTap;

  const MetricTile({
    super.key,
    required this.tint,
    required this.label,
    required this.value,
    this.caption,
    this.icon,
    this.footer,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return KvCard(
      tint: tint,
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                TintIcon(tint: tint, icon: icon, size: 32),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: tint.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              height: 1.1,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 4),
            Text(
              caption!,
              style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
            ),
          ],
          if (footer != null) ...[const SizedBox(height: 10), footer!],
        ],
      ),
    );
  }
}

/// One row in a list card: leading tile, title and detail, then trailing.
class KvListRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? detail;
  final List<Widget> trailing;
  final bool divider;

  const KvListRow({
    super.key,
    required this.leading,
    required this.title,
    this.detail,
    this.trailing = const [],
    this.divider = true,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: AppColors.ink,
          ),
        ),
        if (detail != null)
          Text(
            detail!,
            style: const TextStyle(fontSize: 14, color: AppColors.inkSoft),
          ),
      ],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: divider
            ? const Border(top: BorderSide(color: Color(0xFFEEEDF5)))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: compact && trailing.length > 1
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  leading,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        copy,
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: trailing,
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  leading,
                  const SizedBox(width: 14),
                  Expanded(child: copy),
                  for (final widget in trailing) ...[
                    const SizedBox(width: 10),
                    widget,
                  ],
                ],
              ),
      ),
    );
  }
}

/// A plain heading for a page section.
class KvSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;

  const KvSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.inkSoft,
                    ),
                  ),
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// "Good morning" / "Good afternoon" / "Good evening".
String timeGreeting([DateTime? now]) {
  final hour = (now ?? DateTime.now()).hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

String firstName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '';
  return trimmed.split(RegExp(r'\s+')).first;
}

/// "Overdue", "Due today", "Due tomorrow", or "Due 14/11".
StatusChip? dueChip(DateTime? due, {bool overdue = false}) {
  if (due == null) return null;
  if (overdue) {
    return const StatusChip(
      label: 'Overdue',
      tint: StatusChip.alert,
      icon: Icons.error_outline_rounded,
    );
  }
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final days = DateTime(due.year, due.month, due.day).difference(today).inDays;
  if (days <= 0) return const StatusChip(label: 'Due today', tint: AppTint.sun);
  if (days == 1) {
    return const StatusChip(label: 'Due tomorrow', tint: AppTint.sun);
  }
  return StatusChip(label: 'Due ${due.day}/${due.month}', tint: AppTint.violet);
}

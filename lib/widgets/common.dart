import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Font stack for emoji — avoids Google Fonts (Nunito/Fredoka) rendering tofu boxes on web.
const kEmojiFontFallbacks = [
  'Noto Color Emoji',
  'Apple Color Emoji',
  'Segoe UI Emoji',
  'Segoe UI Symbol',
  'sans-serif',
];

TextStyle emojiTextStyle({double size = 24, Color? color, double? height}) => TextStyle(
      fontSize: size,
      height: height ?? 1.1,
      color: color,
      fontFamily: 'Noto Color Emoji',
      fontFamilyFallback: kEmojiFontFallbacks,
    );

/// Renders emoji with a system/color emoji font (required on Flutter web).
class EmojiText extends StatelessWidget {
  final String text;
  final double size;
  final TextAlign? textAlign;
  final Color? color;

  const EmojiText(this.text, {super.key, this.size = 24, this.textAlign, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      style: emojiTextStyle(size: size, color: color),
    );
  }
}

/// A frosted, rounded surface used as the base for most cards.
///
/// Set [frosted] to true to render a translucent glassmorphism surface with a
/// backdrop blur — looks great layered over the aurora background.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;
  final double radius;
  final List<BoxShadow>? shadow;
  final Border? border;
  final bool frosted;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.color,
    this.gradient,
    this.radius = AppTheme.radiusLg,
    this.shadow,
    this.border,
    this.frosted = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null
            ? (color ?? (frosted ? Colors.white.withValues(alpha: 0.62) : AppColors.surface))
            : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow ?? AppTheme.cardShadow,
        border: border ??
            (frosted ? Border.all(color: Colors.white.withValues(alpha: 0.65), width: 1.4) : null),
      ),
      child: child,
    );

    if (frosted && !kIsWeb) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: content,
        ),
      );
    }

    if (onTap == null) return content;
    return _Pressable(onTap: onTap!, radius: radius, child: content);
  }
}

/// Adds a subtle scale-on-press feel to any child.
class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double radius;
  const _Pressable({required this.child, required this.onTap, required this.radius});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.97 : (_hovered ? 1.02 : 1.0);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          borderRadius: BorderRadius.circular(widget.radius),
          splashColor: AppColors.primary.withValues(alpha: 0.08),
          highlightColor: AppColors.primary.withValues(alpha: 0.04),
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.radius),
                boxShadow: _hovered
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.16),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                        ),
                      ]
                    : null,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill label, optionally with an icon and custom colors.
class Pill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final Color? background;
  const Pill({super.key, required this.label, this.icon, this.color = AppColors.primary, this.background});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 15, color: color), const SizedBox(width: 6)],
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: color, fontSize: 12.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/// Big gradient call-to-action button with optional leading icon.
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Gradient gradient;
  final bool expand;
  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.gradient = AppColors.brandGradient,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap ?? () {},
      radius: AppTheme.radiusMd,
      child: Container(
        width: expand ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 17),
        decoration: BoxDecoration(
          gradient: onTap == null ? null : gradient,
          color: onTap == null ? AppColors.line : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: onTap == null
              ? null
              : [
                  BoxShadow(
                    color: gradient.colors.last.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  )
                ],
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: onTap == null ? AppColors.muted : Colors.white, size: 20),
              const SizedBox(width: 10),
            ],
            Text(label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: onTap == null ? AppColors.muted : Colors.white, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

/// Tappable Kidversity logo — use on auth and dashboard shells.
class KidversityBrandMark extends StatelessWidget {
  final VoidCallback? onTap;
  final bool compact;
  final bool showLabel;

  const KidversityBrandMark({
    super.key,
    this.onTap,
    this.compact = false,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? 38.0 : 44.0;
    final emojiSize = compact ? 20.0 : 24.0;
    final labelStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontSize: compact ? 16 : 18,
          fontWeight: FontWeight.w800,
        );

    final mark = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(compact ? 12 : 14),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.28),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: EmojiText('🎓', size: emojiSize),
        ),
        if (showLabel) ...[
          const SizedBox(width: 10),
          Text('Kidversity', style: labelStyle),
        ],
      ],
    );

    if (onTap == null) return mark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        splashColor: AppColors.primary.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: mark,
        ),
      ),
    );
  }
}

/// Top app bar for student/teacher dashboard shells.
class DashboardAppBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Color accent;
  final IconData? icon;
  final VoidCallback? onBrandTap;

  const DashboardAppBar({
    super.key,
    required this.title,
    this.subtitle,
    required this.accent,
    this.icon,
    this.onBrandTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.2),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            KidversityBrandMark(onTap: onBrandTap, compact: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleLarge?.copyWith(fontSize: 20)),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: text.bodyMedium?.copyWith(fontSize: 12.5, color: AppColors.muted),
                    ),
                ],
              ),
            ),
            if (icon != null)
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
          ],
        ),
      ),
    );
  }
}

/// Section header with a title and optional trailing action.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  const SectionHeader({super.key, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
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

/// Soft circular icon container, used widely for stat tiles.
class SoftIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const SoftIcon({super.key, required this.icon, this.color = AppColors.primary, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

/// A simple seven-bar weekly activity chart.
class MiniBarChart extends StatelessWidget {
  final List<double> values; // 0..1
  final Color color;
  final double height;
  const MiniBarChart({super.key, required this.values, this.color = AppColors.primary, this.height = 56});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int i = 0; i < values.length; i++) ...[
            Expanded(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: values[i].clamp(0.06, 1)),
                duration: Duration(milliseconds: 500 + i * 80),
                curve: Curves.easeOutBack,
                builder: (context, v, _) => Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: height * v,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [color, color.withValues(alpha: 0.55)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
            if (i != values.length - 1) const SizedBox(width: 6),
          ]
        ],
      ),
    );
  }
}

/// Decorative soft blobs used behind hero sections.
class BlobBackground extends StatelessWidget {
  final Widget child;
  const BlobBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -80,
          right: -60,
          child: _blob(220, AppColors.primary.withValues(alpha: 0.10)),
        ),
        Positioned(
          top: 120,
          left: -70,
          child: _blob(180, AppColors.accentTeal.withValues(alpha: 0.10)),
        ),
        Positioned(
          bottom: -60,
          right: 40,
          child: _blob(160, AppColors.secondary.withValues(alpha: 0.10)),
        ),
        child,
      ],
    );
  }

  Widget _blob(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

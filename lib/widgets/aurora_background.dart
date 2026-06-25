import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Soft animated colour orbs over a base wash.
class AuroraBackground extends StatefulWidget {
  final Widget child;
  final List<Color>? orbColors;
  final Color base;

  const AuroraBackground({
    super.key,
    required this.child,
    this.orbColors,
    this.base = AppColors.background,
  });

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.orbColors ??
        const [AppColors.primary, AppColors.accentTeal, AppColors.secondary, AppColors.accentBlue];

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: ColoredBox(color: widget.base)),
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(
                painter: _AuroraPainter(_c.value, colors, blurOrbs: !kIsWeb),
              ),
            ),
          ),
        ),
        Positioned.fill(child: widget.child),
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double t;
  final List<Color> colors;
  final bool blurOrbs;

  _AuroraPainter(this.t, this.colors, {required this.blurOrbs});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final w = size.width;
    final h = size.height;
    final angle = t * 2 * math.pi;

    final orbs = <_Orb>[
      _Orb(
        center: Offset(w * (0.18 + 0.06 * math.cos(angle)), h * (0.12 + 0.05 * math.sin(angle))),
        radius: math.max(w, h) * 0.42,
        color: colors[0],
      ),
      _Orb(
        center: Offset(w * (0.88 + 0.05 * math.sin(angle * 1.3)), h * (0.08 + 0.05 * math.cos(angle))),
        radius: math.max(w, h) * 0.36,
        color: colors[1 % colors.length],
      ),
      _Orb(
        center: Offset(w * (0.8 + 0.06 * math.cos(angle * 0.8)), h * (0.85 + 0.05 * math.sin(angle * 1.1))),
        radius: math.max(w, h) * 0.40,
        color: colors[2 % colors.length],
      ),
      _Orb(
        center: Offset(w * (0.1 + 0.05 * math.sin(angle * 0.9)), h * (0.9 + 0.04 * math.cos(angle * 1.2))),
        radius: math.max(w, h) * 0.32,
        color: colors[3 % colors.length],
      ),
    ];

    for (final orb in orbs) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            orb.color.withValues(alpha: blurOrbs ? 0.22 : 0.14),
            orb.color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: orb.center, radius: orb.radius));
      if (blurOrbs) {
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
      }
      canvas.drawCircle(orb.center, orb.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.t != t || old.blurOrbs != blurOrbs;
}

class _Orb {
  final Offset center;
  final double radius;
  final Color color;
  _Orb({required this.center, required this.radius, required this.color});
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Deep navy backdrop with slowly drifting light and a faint grid of maths
/// and physics symbols. Used behind the splash, hero sections and sign in.
class AuroraBackdrop extends StatefulWidget {
  final Widget? child;
  final bool symbols;

  const AuroraBackdrop({super.key, this.child, this.symbols = true});

  @override
  State<AuroraBackdrop> createState() => _AuroraBackdropState();
}

class _AuroraBackdropState extends State<AuroraBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Clipped so the glow never spills onto the content below.
    return ClipRect(
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, _) => CustomPaint(
                  painter: _AuroraPainter(_c.value, widget.symbols),
                ),
              ),
            ),
          ),
          ?widget.child,
        ],
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double t;
  final bool symbols;

  _AuroraPainter(this.t, this.symbols);

  static const _glyphs = [
    '∫',
    'Σ',
    'π',
    'λ',
    'Δ',
    '√',
    'θ',
    'ω',
    '∞',
    'φ',
    '∂',
    'Ω',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF071530), Ace.navy, Color(0xFF13305F)],
        ).createShader(rect),
    );

    void blob(Color color, double cx, double cy, double r) {
      final c = Offset(cx * size.width, cy * size.height);
      canvas.drawCircle(
        c,
        r * size.shortestSide,
        Paint()
          ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
              .createShader(
                Rect.fromCircle(center: c, radius: r * size.shortestSide),
              ),
      );
    }

    final a = t * 2 * math.pi;
    blob(
      const Color(0x55F2A900),
      0.82 + 0.06 * math.cos(a),
      0.18 + 0.05 * math.sin(a),
      0.75,
    );
    blob(
      const Color(0x442F6FED),
      0.12 + 0.05 * math.sin(a),
      0.85 + 0.04 * math.cos(a),
      0.8,
    );
    blob(
      const Color(0x330E9F8A),
      0.55 + 0.08 * math.sin(a + 1.5),
      0.6 + 0.06 * math.cos(a + 1),
      0.55,
    );

    // Fine grid.
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    const step = 44.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // A slow sine curve, like a graph being drawn across the page.
    final wave = Path();
    for (var x = 0.0; x <= size.width; x += 6) {
      final y =
          size.height * 0.72 +
          math.sin(x / size.width * 4 * math.pi + a) * size.height * 0.06;
      x == 0 ? wave.moveTo(x, y) : wave.lineTo(x, y);
    }
    canvas.drawPath(
      wave,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Ace.amber.withValues(alpha: 0.16),
    );

    if (!symbols) return;
    final rnd = math.Random(7);
    for (var i = 0; i < 18; i++) {
      final g = _glyphs[i % _glyphs.length];
      final x = rnd.nextDouble() * size.width;
      final baseY = rnd.nextDouble() * size.height;
      final y =
          (baseY - t * size.height * 0.25 * (0.4 + rnd.nextDouble())) %
          size.height;
      final tp = TextPainter(
        text: TextSpan(
          text: g,
          style: TextStyle(
            fontSize: 18 + rnd.nextDouble() * 22,
            color: Colors.white.withValues(
              alpha: 0.05 + rnd.nextDouble() * 0.06,
            ),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.t != t;
}

/// Fades and slides its child in, after [delay].
class Reveal extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Offset from;

  const Reveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.from = const Offset(0, 0.06),
  });

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(begin: widget.from, end: Offset.zero).animate(curve),
        child: widget.child,
      ),
    );
  }
}

/// Gentle up-and-down float, for hero illustrations.
class Floating extends StatefulWidget {
  final Widget child;
  final double amplitude;
  final Duration period;

  const Floating({
    super.key,
    required this.child,
    this.amplitude = 8,
    this.period = const Duration(seconds: 5),
  });

  @override
  State<Floating> createState() => _FloatingState();
}

class _FloatingState extends State<Floating>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Transform.translate(
        offset: Offset(
          0,
          Curves.easeInOut.transform(_c.value) * widget.amplitude * 2 -
              widget.amplitude,
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Circular progress that animates from 0 to [value] on first build.
class ProgressRing extends StatelessWidget {
  final double value;
  final double size;
  final double stroke;
  final Color color;
  final Color? track;
  final Widget? center;

  const ProgressRing({
    super.key,
    required this.value,
    required this.color,
    this.size = 64,
    this.stroke = 7,
    this.track,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1)),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            v,
            color,
            track ?? color.withValues(alpha: 0.15),
            stroke,
          ),
          child: Center(child: center),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;
  final Color track;
  final double stroke;

  _RingPainter(this.value, this.color, this.track, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final rect =
        Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, base..color = track);
    if (value > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * value,
        false,
        base..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color;
}

/// A number that counts up from zero.
class CountUp extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final String suffix;

  const CountUp(this.value, {super.key, this.style, this.suffix = ''});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text('${v.round()}$suffix', style: style),
    );
  }
}

/// Lifts slightly and casts a deeper shadow on hover.
class HoverLift extends StatefulWidget {
  final Widget child;

  const HoverLift({super.key, required this.child});

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hover ? -4 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Ace.navy.withValues(alpha: _hover ? 0.16 : 0.06),
              blurRadius: _hover ? 30 : 16,
              offset: Offset(0, _hover ? 14 : 6),
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

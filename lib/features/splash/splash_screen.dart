import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors.dart';

/// Mandarin Foundation launch experience while authentication bootstraps.
/// Routing remains owned by GoRouter so this screen never races auth state.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _entrance.dispose();
    _ambient.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 560;
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: AnimatedBuilder(
        animation: Listenable.merge([_entrance, _ambient, _pulse]),
        builder: (context, _) {
          final entrance = Curves.easeOutCubic.transform(_entrance.value);
          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _InkWashPainter(
                  progress: _ambient.value,
                  pulse: _pulse.value,
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 24 : 52,
                    vertical: 28,
                  ),
                  child: Column(
                    children: [
                      _TopMark(opacity: entrance),
                      const Spacer(),
                      Transform.translate(
                        offset: Offset(0, 28 * (1 - entrance)),
                        child: Opacity(
                          opacity: entrance,
                          child: _FoundationSeal(
                            pulse: _pulse.value,
                            compact: compact,
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? 24 : 34),
                      Opacity(
                        opacity: entrance,
                        child: Column(
                          children: [
                            Text(
                              'MANDARIN FOUNDATION',
                              style: TextStyle(
                                color: AppColors.cinnabar,
                                fontSize: compact ? 12 : 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3.1,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'A clear first path into Mandarin',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color: AppColors.ink,
                                    fontSize: compact ? 28 : 38,
                                    height: 1.08,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '30 sequenced lessons · clear audio · carefully reviewed',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: AppColors.inkSoft),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      _PipelineLoader(progress: _ambient.value),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TopMark extends StatelessWidget {
  final double opacity;

  const _TopMark({required this.opacity});

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: opacity,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: const BoxDecoration(
            color: AppColors.cinnabar,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 9),
        const Text(
          'KIDVERSITY',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ],
    ),
  );
}

class _FoundationSeal extends StatelessWidget {
  final double pulse;
  final bool compact;

  const _FoundationSeal({required this.pulse, required this.compact});

  @override
  Widget build(BuildContext context) {
    final dimension = compact ? 210.0 : 270.0;
    return SizedBox(
      width: dimension,
      height: dimension,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: pulse * 0.025,
            child: Container(
              width: dimension * 0.91,
              height: dimension * 0.91,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.55),
                  width: 1.4,
                ),
              ),
            ),
          ),
          Container(
            width: dimension * (0.78 + pulse * 0.025),
            height: dimension * (0.78 + pulse * 0.025),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(
                color: AppColors.cinnabar.withValues(alpha: 0.22),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cinnabar.withValues(
                    alpha: 0.12 + pulse * 0.06,
                  ),
                  blurRadius: 45,
                  spreadRadius: 6,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/mandarin/fox_mascot.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            right: compact ? 4 : 8,
            bottom: compact ? 18 : 28,
            child: Transform.rotate(
              angle: -0.08,
              child: Container(
                width: compact ? 60 : 72,
                height: compact ? 60 : 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.cinnabar,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.paper.withValues(alpha: 0.8),
                    width: 3,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33231610),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  '学',
                  style: TextStyle(
                    color: AppColors.paper,
                    fontSize: compact ? 30 : 37,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PipelineLoader extends StatelessWidget {
  final double progress;

  const _PipelineLoader({required this.progress});

  @override
  Widget build(BuildContext context) {
    const stepCount = 4;
    final current = (progress * stepCount).floor() % stepCount;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var index = 0; index < stepCount; index++) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: index == current ? 28 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: index == current
                      ? AppColors.cinnabar
                      : AppColors.ink.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              if (index != stepCount - 1) const SizedBox(width: 7),
            ],
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Getting your Mandarin journey ready…',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.25,
          ),
        ),
      ],
    );
  }
}

class _InkWashPainter extends CustomPainter {
  final double progress;
  final double pulse;

  const _InkWashPainter({required this.progress, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFFAF3), AppColors.paper, Color(0xFFEAF2ED)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    final wave = math.sin(progress * math.pi * 2);
    final redWash = Paint()
      ..color = AppColors.cinnabar.withValues(alpha: 0.055 + pulse * 0.02)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 70);
    canvas.drawCircle(
      Offset(size.width * (0.12 + wave * 0.025), size.height * 0.2),
      size.shortestSide * 0.23,
      redWash,
    );

    final jadeWash = Paint()
      ..color = AppColors.jade.withValues(alpha: 0.06)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 85);
    canvas.drawCircle(
      Offset(size.width * (0.88 - wave * 0.025), size.height * 0.77),
      size.shortestSide * 0.28,
      jadeWash,
    );

    final brush = Paint()
      ..color = AppColors.ink.withValues(alpha: 0.035)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(-20, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * (0.63 + wave * 0.015),
        size.width * 0.72,
        size.height * 0.74,
      )
      ..quadraticBezierTo(
        size.width * 0.9,
        size.height * 0.8,
        size.width + 20,
        size.height * 0.71,
      );
    for (var offset = 0; offset < 4; offset++) {
      canvas.drawPath(path.shift(Offset(0, offset * 5)), brush);
    }
  }

  @override
  bool shouldRepaint(covariant _InkWashPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.pulse != pulse;
}

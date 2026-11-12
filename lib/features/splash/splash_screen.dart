import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../widgets/common.dart';

/// Branded hold screen while authentication bootstraps. Matches the web
/// loading screen in web/index.html so the hand-off is seamless.
/// Routing stays with GoRouter so this screen never races auth state.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 0.4;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Kidversity',
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2A1F8F), Color(0xFF4433CC), Color(0xFF7B4FE8)],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const Positioned(
                right: -120,
                top: -140,
                child: _Blob(size: 360, color: Color(0xFFFFC845)),
              ),
              const Positioned(
                left: -90,
                bottom: -100,
                child: _Blob(size: 240, color: Color(0x99FF6B5B)),
              ),
              Center(
                child: ExcludeSemantics(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF14085A,
                              ).withValues(alpha: 0.35),
                              blurRadius: 50,
                              offset: const Offset(0, 24),
                            ),
                          ],
                        ),
                        child: const KidversityMark(size: 56),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'kidversity',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Learning that feels like play',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFFEDEAFF),
                        ),
                      ),
                      const SizedBox(height: 28),
                      _Dots(animation: _c),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// Three bouncing dots in the sun, coral and mint learning colours.
class _Dots extends AnimatedWidget {
  const _Dots({required Animation<double> animation})
    : super(listenable: animation);

  static const _colors = [
    Color(0xFFFFC845),
    Color(0xFFFF6B5B),
    Color(0xFF22B07D),
  ];

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _colors.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Transform.translate(
            offset: Offset(0, -10 * _bounce((t - i * 0.14) % 1)),
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _colors[i],
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Up and down once in the first 80% of the cycle, then rest.
  static double _bounce(double phase) {
    if (phase > 0.8) return 0;
    final p = phase / 0.8;
    return p < 0.5 ? p * 2 : (1 - p) * 2;
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';
import '../widgets/effects.dart';

/// Opening animation: the ACE mark rises in, the arrow strikes up and out,
/// the wordmark and "Advance. Conquer. Excel." follow, then it fades away.
class SplashOverlay extends StatefulWidget {
  final VoidCallback onDone;

  const SplashOverlay({super.key, required this.onDone});

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2300),
  );
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  Animation<double> _phase(
    double a,
    double b, [
    Curve c = Curves.easeOutCubic,
  ]) => CurvedAnimation(
    parent: _intro,
    curve: Interval(a, b, curve: c),
  );

  @override
  void initState() {
    super.initState();
    _intro.forward().then((_) async {
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      await _exit.forward();
      widget.onDone();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mark = _phase(0.0, 0.35, Curves.easeOutBack);
    final arrow = _phase(0.2, 0.5);
    final word = _phase(0.35, 0.6);
    final tagline = [_phase(0.5, 0.68), _phase(0.6, 0.78), _phase(0.7, 0.88)];
    final bar = _phase(0.3, 1.0, Curves.easeInOut);

    // Material gives the text its proper styling (the overlay sits above
    // the app's Scaffold) and blocks taps while the splash is showing.
    return FadeTransition(
      opacity: ReverseAnimation(_exit),
      child: Material(
        type: MaterialType.transparency,
        child: AuroraBackdrop(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _intro,
                  builder: (_, _) => Transform.scale(
                    scale: 0.6 + 0.4 * mark.value,
                    child: Opacity(
                      opacity: mark.value.clamp(0, 1),
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: Ace.amber,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Ace.amber.withValues(
                                alpha: 0.45 * mark.value,
                              ),
                              blurRadius: 60,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Transform.translate(
                          offset: Offset(
                            -14 * (1 - arrow.value),
                            14 * (1 - arrow.value),
                          ),
                          child: Opacity(
                            opacity: arrow.value,
                            child: const Icon(
                              Icons.north_east_rounded,
                              size: 60,
                              color: Ace.navy,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                FadeTransition(
                  opacity: word,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.4),
                      end: Offset.zero,
                    ).animate(word),
                    child: Text(
                      'ACE',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 54,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (i, w) in const [
                      'Advance.',
                      'Conquer.',
                      'Excel.',
                    ].indexed)
                      FadeTransition(
                        opacity: tagline[i],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            w,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: i == 2
                                  ? Ace.amber
                                  : const Color(0xFFC9D3E6),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: 160,
                  child: AnimatedBuilder(
                    animation: bar,
                    builder: (_, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: bar.value,
                        minHeight: 3,
                        backgroundColor: Colors.white12,
                        color: Ace.amber,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

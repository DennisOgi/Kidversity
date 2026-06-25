import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/aurora_background.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';

/// Brand splash while auth bootstraps. Navigation is handled by [app_router]
/// redirects (splash → home when auth is ready) — do not navigate from here.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat(reverse: true);
  late final AnimationController _orbit =
      AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  late final AnimationController _load =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    _orbit.dispose();
    _load.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: AuroraBackground(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Soft vignette for depth
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.2),
                  radius: 1.1,
                  colors: [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.transparent,
                    AppColors.primary.withValues(alpha: 0.06),
                  ],
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: size.width > 600 ? 48 : 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FadeInUp(
                      child: SizedBox(
                        width: 200,
                        height: 200,
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_pulse, _orbit]),
                          builder: (context, child) {
                            final glow = 0.35 + _pulse.value * 0.25;
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 168 + _pulse.value * 18,
                                  height: 168 + _pulse.value * 18,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        AppColors.primary.withValues(alpha: glow * 0.35),
                                        AppColors.secondary.withValues(alpha: glow * 0.12),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                                for (var i = 0; i < 3; i++)
                                  Transform.rotate(
                                    angle: _orbit.value * math.pi * 2 + (i * math.pi * 2 / 3),
                                    child: Transform.translate(
                                      offset: const Offset(0, -88),
                                      child: _OrbitChip(
                                        emoji: const ['📚', '✨', '🏅'][i],
                                        opacity: 0.75 + _pulse.value * 0.25,
                                      ),
                                    ),
                                  ),
                                Transform.scale(
                                  scale: 1 + _pulse.value * 0.04,
                                  child: Container(
                                    width: 112,
                                    height: 112,
                                    decoration: BoxDecoration(
                                      gradient: AppColors.brandGradient,
                                      borderRadius: BorderRadius.circular(34),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(alpha: 0.5),
                                          blurRadius: 36,
                                          offset: const Offset(0, 18),
                                        ),
                                        BoxShadow(
                                          color: AppColors.secondary.withValues(alpha: 0.25),
                                          blurRadius: 24,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text('🎓', style: TextStyle(fontSize: 52)),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    FadeInUp(
                      delay: const Duration(milliseconds: 100),
                      child: ShaderMask(
                        shaderCallback: (r) => const LinearGradient(
                          colors: [AppColors.primary, AppColors.accentPink, AppColors.secondary],
                        ).createShader(r),
                        child: Text(
                          'Kidversity',
                          style: text.displayMedium?.copyWith(
                            color: Colors.white,
                            fontSize: size.width > 600 ? 46 : 40,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FadeInUp(
                      delay: const Duration(milliseconds: 180),
                      child: Text(
                        'Learn your way',
                        style: text.titleLarge?.copyWith(
                          color: AppColors.ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    FadeInUp(
                      delay: const Duration(milliseconds: 240),
                      child: Text(
                        'Slides, audio & rewards for every learner',
                        textAlign: TextAlign.center,
                        style: text.bodyLarge?.copyWith(
                          color: AppColors.muted,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    FadeInUp(
                      delay: const Duration(milliseconds: 320),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: const [
                          Pill(label: 'Slides + audio', icon: Icons.headphones_rounded, color: AppColors.primary),
                          Pill(label: 'Live quizzes', icon: Icons.bolt_rounded, color: AppColors.secondary),
                          Pill(label: 'Badges & XP', icon: Icons.emoji_events_rounded, color: AppColors.accentTeal),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    FadeInUp(
                      delay: const Duration(milliseconds: 420),
                      child: Column(
                        children: [
                          SizedBox(
                            width: 220,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: AnimatedBuilder(
                                animation: _load,
                                builder: (context, _) {
                                  return LinearProgressIndicator(
                                    value: null,
                                    minHeight: 5,
                                    backgroundColor: AppColors.line,
                                    color: Color.lerp(
                                      AppColors.primary,
                                      AppColors.secondary,
                                      (math.sin(_load.value * math.pi * 2) + 1) / 2,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Getting things ready…',
                            style: text.bodyMedium?.copyWith(
                              color: AppColors.muted,
                              fontSize: 13,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom brand strip
            Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: FadeInUp(
                delay: const Duration(milliseconds: 500),
                child: Center(
                  child: GlassCard(
                    frosted: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shadow: AppTheme.softShadow,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.primary.withValues(alpha: 0.85)),
                        const SizedBox(width: 8),
                        Text(
                          'A friendly digital classroom',
                          style: text.labelLarge?.copyWith(fontSize: 12, color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrbitChip extends StatelessWidget {
  final String emoji;
  final double opacity;

  const _OrbitChip({required this.emoji, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: opacity),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 18)),
    );
  }
}

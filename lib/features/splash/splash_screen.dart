import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors.dart';
import '../../widgets/aurora_background.dart';
import '../../widgets/motion.dart';

/// Brand splash while auth bootstraps. Navigation is handled by [app_router]
/// redirects (splash → home when auth is ready) — do not navigate from here.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: AuroraBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeInUp(
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, child) {
                      final scale = 1 + _pulse.value * 0.06;
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.45),
                            blurRadius: 32,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text('🎓', style: TextStyle(fontSize: 54)),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                FadeInUp(
                  delay: const Duration(milliseconds: 120),
                  child: ShaderMask(
                    shaderCallback: (r) => AppColors.brandGradient.createShader(r),
                    child: Text('Kidversity',
                        style: text.displayMedium?.copyWith(color: Colors.white, fontSize: 42)),
                  ),
                ),
                const SizedBox(height: 10),
                FadeInUp(
                  delay: const Duration(milliseconds: 220),
                  child: Text('Learn your way — slides, audio & rewards',
                      textAlign: TextAlign.center,
                      style: text.bodyLarge?.copyWith(fontSize: 16)),
                ),
                const SizedBox(height: 36),
                FadeInUp(
                  delay: const Duration(milliseconds: 320),
                  child: const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/navigation.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/aurora_background.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';

class LandingScreen extends ConsumerWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > 900;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: wide ? 64 : 22, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FadeInUp(child: _Brand()),
                      const SizedBox(height: 44),
                      Flex(
                        direction: wide ? Axis.horizontal : Axis.vertical,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(flex: wide ? 5 : 0, child: FadeInUp(delay: const Duration(milliseconds: 80), child: _Hero(text: text, wide: wide))),
                          SizedBox(width: wide ? 48 : 0, height: wide ? 0 : 34),
                          Expanded(
                            flex: wide ? 4 : 0,
                            child: FadeInUp(delay: const Duration(milliseconds: 220), child: const _HeroVisual()),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      FadeInUp(delay: const Duration(milliseconds: 360), child: const _FeatureGrid()),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 8))],
          ),
          alignment: Alignment.center,
          child: const Text('🎓', style: TextStyle(fontSize: 25)),
        ),
        const SizedBox(width: 12),
        Text('Kidversity', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 25)),
        const Spacer(),
        TextButton(onPressed: () => context.go(AppRoutes.auth), child: const Text('Sign in')),
        const SizedBox(width: 8),
        const Pill(label: 'Beta', icon: Icons.rocket_launch_rounded, color: AppColors.accentTeal),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  final TextTheme text;
  final bool wide;
  const _Hero({required this.text, required this.wide});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Pill(label: 'A friendly digital classroom', icon: Icons.favorite_rounded, color: AppColors.secondary),
        const SizedBox(height: 20),
        ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            colors: [AppColors.primary, AppColors.accentPink, AppColors.secondary],
          ).createShader(rect),
          child: Text(
            'Learn your way.',
            style: text.displayLarge?.copyWith(
              color: Colors.white,
              fontSize: wide ? 56 : 42,
              height: 1.02,
            ),
          ),
        ),
        Text('Slides, audio & rewards 🎉',
            style: text.displayMedium?.copyWith(fontSize: wide ? 34 : 27, color: AppColors.ink)),
        const SizedBox(height: 18),
        Text(
          'Upload your own PowerPoint & audio, or type a topic and let AI build the '
          'whole lesson in minutes. Students learn at their own pace and celebrate every win.',
          style: text.bodyLarge?.copyWith(fontSize: 16.5),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: const [
            Pill(label: 'Slides + Audio', icon: Icons.slideshow_rounded, color: AppColors.primary),
            Pill(label: 'AI Auto-Generate', icon: Icons.auto_awesome_rounded, color: AppColors.accentTeal),
            Pill(label: 'Badges & Streaks', icon: Icons.emoji_events_rounded, color: AppColors.accentYellow),
            Pill(label: 'Progress Tracking', icon: Icons.insights_rounded, color: AppColors.accentBlue),
          ],
        ),
        const SizedBox(height: 28),
        _AuthCallouts(wide: wide),
      ],
    );
  }
}

class _AuthCallouts extends ConsumerWidget {
  final bool wide;
  const _AuthCallouts({required this.wide});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          onPressed: () => context.go(AppRoutes.auth),
          icon: const Icon(Icons.login_rounded, size: 20),
          label: const Text('Sign in'),
          style: FilledButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: wide ? 28 : 22, vertical: 16),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => context.go('${AppRoutes.auth}?tab=signup'),
          icon: const Icon(Icons.person_add_rounded, size: 20),
          label: const Text('Create account'),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: wide ? 24 : 18, vertical: 16),
          ),
        ),
        Text(
          'Choose student or teacher when you register.',
          style: text.bodyMedium?.copyWith(color: AppColors.muted, fontSize: 13),
        ),
      ],
    );
  }
}

class _HeroVisual extends StatelessWidget {
  const _HeroVisual();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 360,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -0.03,
            child: GlassCard(
              frosted: true,
              padding: const EdgeInsets.all(20),
              shadow: AppTheme.softShadow,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Pill(label: 'MANDARIN', icon: Icons.translate_rounded, color: AppColors.secondary),
                      const Spacer(),
                      Text('Slide 1 / 8', style: text.bodyMedium?.copyWith(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.secondary.withValues(alpha: 0.18), AppColors.primary.withValues(alpha: 0.1)],
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    alignment: Alignment.center,
                    child: const Text('妈妈', style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: AppColors.ink)),
                  ),
                  const SizedBox(height: 14),
                  Text('妈妈 — māma', style: text.titleLarge),
                  Text('"mum" • tap play to hear it', style: text.bodyMedium?.copyWith(fontSize: 13)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        width: 42, height: 42,
                        decoration: const BoxDecoration(gradient: AppColors.sunsetGradient, shape: BoxShape.circle),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: const LinearProgressIndicator(
                                value: 0.42,
                                minHeight: 7,
                                backgroundColor: AppColors.line,
                                valueColor: AlwaysStoppedAnimation(AppColors.secondary),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text('0:07 / 0:16', style: text.bodyMedium?.copyWith(fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(top: -6, right: -4, child: _FloatingChip(emoji: '🔥', label: '12-day streak', color: AppColors.secondary)),
          Positioned(bottom: 22, left: -10, child: _FloatingChip(emoji: '⭐', label: '+150 XP', color: AppColors.accentYellow)),
          Positioned(bottom: -8, right: 16, child: _FloatingChip(emoji: '🏅', label: 'Badge unlocked!', color: AppColors.primary)),
        ],
      ),
    );
  }
}

class _FloatingChip extends StatelessWidget {
  final String emoji, label;
  final Color color;
  const _FloatingChip({required this.emoji, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 8))],
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: emojiTextStyle(size: 17)),
          const SizedBox(width: 7),
          Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 13, color: AppColors.ink)),
        ],
      ),
    );
  }
}

class _FeatureGrid extends ConsumerWidget {
  const _FeatureGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = [
      (Icons.upload_file_rounded, 'Upload or Generate', 'Use your PPT/PDF + audio, or let AI draft it.', AppColors.primary),
      (Icons.headphones_rounded, 'Slides + Audio Sync', 'Play, pause, replay — go at your own pace.', AppColors.accentTeal),
      (Icons.quiz_rounded, 'Smart Quizzes', 'Auto-graded checkpoints reinforce learning.', AppColors.secondary),
      (Icons.insights_rounded, 'Track & Celebrate', 'Visual progress, badges & safe leaderboards.', AppColors.accentBlue),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cross = c.maxWidth > 900 ? 4 : c.maxWidth > 560 ? 2 : 1;
      return GridView.count(
        crossAxisCount: cross,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: cross == 1 ? 3.6 : 1.12,
        children: [
          for (int i = 0; i < items.length; i++)
            FadeInUp(
              delay: Duration(milliseconds: 400 + i * 80),
              child: GlassCard(
                frosted: true,
                onTap: () => openLandingFeature(context, ref, i),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SoftIcon(icon: items[i].$1, color: items[i].$4),
                    const SizedBox(height: 12),
                    Text(items[i].$2, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(items[i].$3, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
                    const SizedBox(height: 8),
                    Text(
                      'Try it →',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: items[i].$4,
                            fontSize: 12,
                          ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}

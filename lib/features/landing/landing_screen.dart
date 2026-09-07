import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
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
    final publishedCountAsync = ref.watch(publishedFoundationLessonCountProvider);
    final publishedCount = publishedCountAsync.when(
      data: (value) => value,
      // Distinguish loading from failure so a bad Supabase env does not look
      // like an endless "Checking availability" state.
      loading: () => null,
      error: (_, _) => 0,
    );
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth > 900;
              final compact = c.maxWidth < 560;
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: wide ? 64 : (compact ? 16 : 22),
                  vertical: compact ? 16 : 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FadeInUp(child: _Brand()),
                        SizedBox(height: compact ? 24 : 44),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 5,
                                child: FadeInUp(
                                  delay: const Duration(milliseconds: 80),
                                  child: _Hero(
                                    text: text,
                                    wide: true,
                                    publishedCount: publishedCount,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 48),
                              const Expanded(
                                flex: 4,
                                child: FadeInUp(
                                  delay: Duration(milliseconds: 220),
                                  child: _HeroVisual(),
                                ),
                              ),
                            ],
                          )
                        else
                          FadeInUp(
                            delay: const Duration(milliseconds: 80),
                            child: _Hero(
                              text: text,
                              wide: false,
                              publishedCount: publishedCount,
                            ),
                          ),
                        const SizedBox(height: 30),
                        const FadeInUp(
                          delay: Duration(milliseconds: 360),
                          child: _FeatureGrid(),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) {
    final showHeaderSignIn = MediaQuery.sizeOf(context).width >= 560;
    return Row(
      children: [
        const Expanded(
          child: KidversityBrandMark(compact: false, showLabel: true),
        ),
        if (showHeaderSignIn)
          TextButton(
            onPressed: () => context.go(AppRoutes.auth),
            child: const Text('Sign in'),
          ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  final TextTheme text;
  final bool wide;
  final int? publishedCount;

  const _Hero({
    required this.text,
    required this.wide,
    required this.publishedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Pill(
          label: 'Mandarin Foundation · Ages 7–12',
          icon: Icons.translate_rounded,
          color: AppColors.cinnabar,
        ),
        const SizedBox(height: 20),
        ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            colors: [AppColors.cinnabar, AppColors.gold, AppColors.jade],
          ).createShader(rect),
          child: Text(
            'Mandarin starts here.',
            style: text.displayLarge?.copyWith(
              color: Colors.white,
              fontSize: wide ? 56 : 36,
              height: 1.05,
            ),
          ),
        ),
        Text(
          'One clear path. Human-reviewed.',
          style: text.displayMedium?.copyWith(
            fontSize: wide ? 34 : 24,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Build a real beginner foundation through 30 sequenced lessons. Every Chinese word, '
          'Pinyin line, meaning, activity, and audio prompt is carefully checked.',
          style: text.bodyLarge?.copyWith(fontSize: 16.5),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            const Pill(
              label: '30-lesson course',
              icon: Icons.route_rounded,
              color: AppColors.cinnabar,
            ),
            Pill(
              label: publishedCount == null
                  ? 'Checking availability'
                  : publishedCount == 0
                  ? 'Lessons publish after review'
                  : '$publishedCount lessons available',
              icon: Icons.verified_rounded,
              color: AppColors.jade,
            ),
            const Pill(
              label: 'Listen & practise',
              icon: Icons.volume_up_rounded,
              color: AppColors.gold,
            ),
            const Pill(
              label: 'Class progress',
              icon: Icons.insights_rounded,
              color: AppColors.accentBlue,
            ),
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
    final buttons = [
      FilledButton.icon(
        onPressed: () => context.go(AppRoutes.auth),
        icon: const Icon(Icons.login_rounded, size: 20),
        label: const Text('Sign in'),
        style: FilledButton.styleFrom(
          minimumSize: wide ? null : const Size(double.infinity, 50),
          padding: EdgeInsets.symmetric(
            horizontal: wide ? 28 : 22,
            vertical: 16,
          ),
        ),
      ),
      OutlinedButton.icon(
        onPressed: () => context.go('${AppRoutes.auth}?tab=signup'),
        icon: const Icon(Icons.person_add_rounded, size: 20),
        label: const Text('Create account'),
        style: OutlinedButton.styleFrom(
          minimumSize: wide ? null : const Size(double.infinity, 50),
          padding: EdgeInsets.symmetric(
            horizontal: wide ? 24 : 18,
            vertical: 16,
          ),
        ),
      ),
    ];
    return Column(
      crossAxisAlignment: wide
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.stretch,
      children: [
        if (wide)
          Wrap(spacing: 12, runSpacing: 12, children: buttons)
        else ...[
          buttons[0],
          const SizedBox(height: 10),
          buttons[1],
        ],
        const SizedBox(height: 12),
        Text(
          'Choose a learner or teacher account when you register.',
          style: text.bodyMedium?.copyWith(
            color: AppColors.muted,
            fontSize: 13,
          ),
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
                      const Pill(
                        label: 'MANDARIN',
                        icon: Icons.translate_rounded,
                        color: AppColors.secondary,
                      ),
                      const Spacer(),
                      Text(
                        'Slide 1 / 8',
                        style: text.bodyMedium?.copyWith(fontSize: 12),
                      ),
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
                        colors: [
                          AppColors.secondary.withValues(alpha: 0.18),
                          AppColors.primary.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '妈妈',
                      style: TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('妈妈 — māma', style: text.titleLarge),
                  Text(
                    '"mum" • tap play to hear it',
                    style: text.bodyMedium?.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          gradient: AppColors.sunsetGradient,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                        ),
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
                                valueColor: AlwaysStoppedAnimation(
                                  AppColors.secondary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '0:07 / 0:16',
                              style: text.bodyMedium?.copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
      (
        Icons.route_rounded,
        'Sequenced Foundation',
        'Three modules guide complete beginners through 30 lessons.',
        AppColors.cinnabar,
      ),
      (
        Icons.headphones_rounded,
        'Clear Mandarin Audio',
        'Listen to every word and phrase as you learn.',
        AppColors.jade,
      ),
      (
        Icons.fact_check_rounded,
        'Carefully Reviewed',
        'Chinese, Pinyin, meanings, and activities are checked for accuracy.',
        AppColors.gold,
      ),
      (
        Icons.insights_rounded,
        'Visible Class Progress',
        'Teachers see each learner’s exact place on the course path.',
        AppColors.accentBlue,
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth <= 560;
        final cross = c.maxWidth > 900
            ? 4
            : compact
            ? 1
            : 2;
        if (compact) {
          return Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                FadeInUp(
                  delay: Duration(milliseconds: 400 + i * 80),
                  child: GlassCard(
                    frosted: true,
                    onTap: () => openLandingFeature(context, ref, i),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SoftIcon(icon: items[i].$1, color: items[i].$4, size: 40),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                items[i].$2,
                                style: Theme.of(
                                  context,
                                ).textTheme.titleMedium?.copyWith(fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                items[i].$3,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (i != items.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }
        return GridView.count(
          crossAxisCount: cross,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: cross == 2 ? 1.35 : 1.12,
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
                      Text(
                        items[i].$2,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[i].$3,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

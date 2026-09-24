import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../models/models.dart';
import '../../router/navigation.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/labs_entry_card.dart';
import '../../widgets/surfaces.dart';

class LandingScreen extends ConsumerWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 960;
            final pad = wide ? 48.0 : 20.0;
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(pad, 12, pad, 0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: const _Header(),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(pad, 20, pad, 40),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (wide)
                              const Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    flex: 6,
                                    child: _HeroCopy(wide: true),
                                  ),
                                  SizedBox(width: 36),
                                  Expanded(
                                    flex: 5,
                                    child: _HeroArt(tall: true),
                                  ),
                                ],
                              )
                            else ...[
                              const _HeroCopy(wide: false),
                              const SizedBox(height: 22),
                              const _HeroArt(tall: false),
                            ],
                            const SizedBox(height: 48),
                            const _WorldDirectory(),
                            const SizedBox(height: 48),
                            const _Proof(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final showSignIn = MediaQuery.sizeOf(context).width >= 560;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: 8),
              child: KidversityBrandMark(),
            ),
          ),
          if (showSignIn)
            TextButton(
              onPressed: () => context.go(AppRoutes.auth),
              child: const Text('Sign in'),
            ),
        ],
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  final bool wide;
  const _HeroCopy({required this.wide});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WorldHintRow(),
        const SizedBox(height: 18),
        Text(
          'Mandarin, past questions,\nand experiments.',
          style: text.displayLarge?.copyWith(
            fontSize: wide ? 48 : 34,
            height: 1.06,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'Students practise on their own phone or computer. '
            'Teachers set the work and follow the class.',
            style: text.bodyLarge?.copyWith(
              fontSize: 17,
              height: 1.55,
              color: AppColors.inkSoft,
            ),
          ),
        ),
        const SizedBox(height: 26),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () => context.go('${AppRoutes.auth}?tab=signup'),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Create account'),
            ),
            if (!wide)
              OutlinedButton(
                onPressed: () => context.go(AppRoutes.auth),
                child: const Text('Sign in'),
              ),
          ],
        ),
      ],
    );
  }
}

class _HeroArt extends StatelessWidget {
  final bool tall;

  const _HeroArt({required this.tall});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: tall ? 1080 / 950 : 1080 / 950,
      child: Lottie.asset(
        'assets/Student.json',
        fit: BoxFit.contain,
        repeat: true,
        animate: !MediaQuery.disableAnimationsOf(context),
      ),
    );
  }
}

class _WorldDirectory extends ConsumerWidget {
  const _WorldDirectory();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worlds = [
      (
        'assets/illustrations/world-mandarin.png',
        'Language',
        'Mandarin Foundation',
        'Thirty sequenced lessons. Listen, practise, then unlock the next one.',
        AppColors.worldLanguage,
        0,
      ),
      (
        'assets/illustrations/world-exams.png',
        'Exams',
        'Nigerian past questions',
        'UTME, WASSCE, NECO, and Post-UTME. Check your answer, then read the solution.',
        AppColors.worldExams,
        1,
      ),
      (
        'assets/rope_pull/environment/campus-court.png',
        'Play',
        'Rope Pull',
        'A live tug-of-war. Each team gets its own question. The rope sits in the middle.',
        AppColors.worldPlay,
        2,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageIntro(
          eyebrow: 'Choose a world',
          title: 'Open a door. Come back to the others.',
          body: 'Start wherever you need to today. Progress stays with you.',
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              for (final world in worlds)
                WorldTile(
                  asset: world.$1,
                  label: world.$2,
                  title: world.$3,
                  body: world.$4,
                  color: world.$5,
                  onTap: () => openLandingFeature(context, ref, world.$6),
                ),
            ];
            if (constraints.maxWidth < 900) {
              return Column(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    cards[i],
                    if (i != cards.length - 1) const SizedBox(height: 12),
                  ],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 14),
                  Expanded(child: cards[i]),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        LabsEntryCard(
          featured: true,
          onTap: () => enterRoleSpace(
            context,
            ref,
            UserRole.student,
            AppRoutes.studentLabs,
          ),
        ),
      ],
    );
  }
}

class _Proof extends StatelessWidget {
  const _Proof();

  @override
  Widget build(BuildContext context) {
    const points = [
      (
        Icons.groups_rounded,
        'A teacher sees the class',
        'Share a class code. Assignments, progress, and live quizzes stay with that group.',
      ),
      (
        Icons.flag_rounded,
        'A learner always has a next step',
        'Home shows the lesson to continue, the paper to retry, or the world to open.',
      ),
      (
        Icons.lightbulb_outline_rounded,
        'Answers are explained',
        'Past questions mark the option you chose, then show why it was right or wrong.',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageIntro(
          eyebrow: 'Built for a real class',
          title: 'What schools actually need.',
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              for (final point in points)
                _ProofCard(icon: point.$1, title: point.$2, body: point.$3),
            ];
            if (constraints.maxWidth < 860) {
              return Column(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    cards[i],
                    if (i != cards.length - 1) const SizedBox(height: 12),
                  ],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 14),
                  Expanded(child: cards[i]),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ProofCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _ProofCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return LiftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SoftIcon(icon: icon, size: 42),
          const SizedBox(height: 14),
          Text(title, style: text.titleMedium),
          const SizedBox(height: 6),
          Text(body, style: text.bodyMedium),
        ],
      ),
    );
  }
}

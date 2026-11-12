import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../../data/auth_state.dart';
import '../../models/models.dart';
import '../../router/navigation.dart';
import '../../theme/app_colors.dart';
import '../../theme/role_style.dart';
import '../../widgets/common.dart';
import '../../widgets/kv_ui.dart';

/// The public home page: what Kidversity is, who it is for, and one clear
/// way in for each role.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFFBFAFF),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Hero()),
          SliverToBoxAdapter(child: _Section(child: _Worlds())),
          SliverToBoxAdapter(child: _Section(tinted: true, child: _Roles())),
          SliverToBoxAdapter(child: _Section(child: _HowItWorks())),
          SliverToBoxAdapter(child: _Section(child: _SchoolCta())),
          SliverToBoxAdapter(child: _Footer()),
        ],
      ),
    );
  }
}

/// Sends signed-out visitors to sign-up, then on to [route]; signed-in ones
/// straight to their space.
void _startAs(
  BuildContext context,
  WidgetRef ref,
  UserRole role,
  String route,
) {
  final auth = ref.read(authControllerProvider);
  if (!auth.isAuthenticated) {
    context.go(
      '${AppRoutes.auth}?tab=signup&redirect=${Uri.encodeComponent(route)}',
    );
    return;
  }
  enterRoleSpace(context, ref, role, route);
}

double _sidePadding(double width) =>
    width < 600 ? 20 : (width < 1000 ? 36 : 56);

class _Section extends StatelessWidget {
  final Widget child;
  final bool tinted;

  const _Section({required this.child, this.tinted = false});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final side = _sidePadding(width);
    return ColoredBox(
      color: tinted ? const Color(0xFFF3F0FF) : Colors.transparent,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          side,
          width < 600 ? 48 : 80,
          side,
          width < 600 ? 48 : 80,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1160),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SectionHead extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? body;
  final AppTint tint;

  const _SectionHead({
    required this.eyebrow,
    required this.title,
    this.body,
    this.tint = AppTint.violet,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatusChip(label: eyebrow.toUpperCase(), tint: tint),
        const SizedBox(height: 14),
        Semantics(
          header: true,
          child: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: compact ? 28 : 38,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.8,
              color: AppColors.ink,
            ),
          ),
        ),
        if (body != null) ...[
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Text(
              body!,
              style: const TextStyle(
                fontSize: 17,
                height: 1.55,
                color: AppColors.inkSoft,
              ),
            ),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------

class _Hero extends ConsumerWidget {
  const _Hero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 960;
    final compact = width < 600;
    final side = _sidePadding(width);
    final signedIn = ref.watch(authControllerProvider).isAuthenticated;

    // Phones and tablets stack: headline, then the animation straight away so
    // it is seen without scrolling, then the copy and buttons.
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact) ...[_newPill(), const SizedBox(height: 22)],
        Text(
          'Learning that\nfeels like play.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: compact ? 36 : (wide ? 64 : 52),
            fontWeight: FontWeight.w800,
            height: 1.04,
            letterSpacing: compact ? -1 : -1.6,
            color: Colors.white,
          ),
        ),
        if (!wide) ...[
          SizedBox(height: compact ? 20 : 28),
          const _HeroArt(),
          SizedBox(height: compact ? 22 : 28),
        ] else
          const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Text(
            compact
                ? 'Mandarin, maths, WAEC and UTME past questions, science labs '
                      'and live Rope Pull, on any phone.'
                : 'Mandarin, mental maths, WAEC and UTME past questions, science '
                      'labs and live Rope Pull matches. On any phone or computer, for '
                      'every learner in your school.',
            style: TextStyle(
              fontSize: compact ? 16 : 18,
              height: 1.55,
              color: const Color(0xFFEDEAFF),
            ),
          ),
        ),
        SizedBox(height: compact ? 22 : 28),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SunButton(
              label: signedIn ? 'Go to my space' : 'Get started free',
              onPressed: () => signedIn
                  ? context.go(AppRoutes.home)
                  : context.go('${AppRoutes.auth}?tab=signup'),
            ),
            if (!signedIn)
              HeroGhostButton(
                label: 'I have an account',
                onPressed: () => context.go(AppRoutes.auth),
              ),
          ],
        ),
        SizedBox(height: compact ? 20 : 26),
        const Wrap(
          spacing: 18,
          runSpacing: 10,
          children: [
            _HeroFact(
              icon: Icons.download_done_rounded,
              text: 'No download needed',
            ),
            _HeroFact(
              icon: Icons.phone_android_rounded,
              text: 'Works on any phone',
            ),
            _HeroFact(
              icon: Icons.lock_outline_rounded,
              text: 'Safe for children',
            ),
          ],
        ),
      ],
    );

    return _heroFrame(
      context,
      side: side,
      compact: compact,
      wide: wide,
      copy: copy,
    );
  }

  Widget _newPill() => Container(
    padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppTint.sun.strong,
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'NEW',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              color: AppColors.ink,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Flexible(
          child: Text(
            'School spaces for admins, teachers and parents',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _heroFrame(
    BuildContext context, {
    required double side,
    required bool compact,
    required bool wide,
    required Widget copy,
  }) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A1F8F), Color(0xFF4433CC), Color(0xFF7B4FE8)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
        child: Stack(
          children: [
            const Positioned.fill(child: _HeroShapes()),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(side, 14, side, compact ? 40 : 72),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1160),
                    child: Column(
                      children: [
                        const _NavBar(),
                        SizedBox(height: compact ? 20 : 56),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(flex: 11, child: copy),
                              const SizedBox(width: 40),
                              const Expanded(flex: 9, child: _HeroArt()),
                            ],
                          )
                        else
                          // The art already sits inside the copy, under the
                          // headline.
                          copy,
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

class _HeroFact extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HeroFact({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppTint.sun.strong),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

/// Soft confetti of brand shapes behind the hero copy.
class _HeroShapes extends StatelessWidget {
  const _HeroShapes();

  @override
  Widget build(BuildContext context) {
    Widget dot(
      double size,
      Color color, {
      double radius = 999,
      double turn = 0,
    }) => Transform.rotate(
      angle: turn,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final h = box.maxHeight;
          // On phones the copy spans the width, so the sun shrinks into the
          // corner and the small confetti stays out of the text.
          if (w < 600) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  right: -70,
                  top: -80,
                  child: dot(170, const Color(0xFFFFC845)),
                ),
                Positioned(
                  left: -70,
                  bottom: -80,
                  child: dot(
                    180,
                    const Color(0xFFFF6B5B).withValues(alpha: 0.55),
                  ),
                ),
              ],
            );
          }
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -120,
                top: -140,
                child: dot(
                  380,
                  const Color(0xFFFFC845).withValues(alpha: 0.95),
                ),
              ),
              Positioned(
                left: -90,
                bottom: -110,
                child: dot(
                  260,
                  const Color(0xFFFF6B5B).withValues(alpha: 0.55),
                ),
              ),
              Positioned(
                left: w * 0.46,
                top: h * 0.12,
                child: dot(22, const Color(0xFF7CC4FF)),
              ),
              Positioned(
                left: w * 0.08,
                top: h * 0.2,
                child: dot(14, const Color(0xFFFFC845)),
              ),
              Positioned(
                right: w * 0.06,
                bottom: h * 0.12,
                child: dot(56, const Color(0xFF22B07D), radius: 14, turn: 0.4),
              ),
              Positioned(
                left: w * 0.38,
                bottom: h * 0.08,
                child: dot(30, const Color(0xFFE85AA8), radius: 8, turn: -0.3),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavBar extends ConsumerWidget {
  const _NavBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final signedIn = ref.watch(authControllerProvider).isAuthenticated;
    return Row(
      children: [
        KidversityBrandMark(
          reversed: true,
          compact: compact,
          onTap: () => context.go(AppRoutes.home),
        ),
        const Spacer(),
        if (!signedIn) ...[
          TextButton(
            onPressed: () => context.go(AppRoutes.auth),
            // On phones it sits over the yellow shape, so it gets a solid
            // white pill to stay readable.
            style: TextButton.styleFrom(
              foregroundColor: compact ? AppColors.primary : Colors.white,
              backgroundColor: compact ? Colors.white : null,
              padding: compact
                  ? const EdgeInsets.symmetric(horizontal: 18, vertical: 12)
                  : null,
              shape: compact ? const StadiumBorder() : null,
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            child: const Text('Sign in'),
          ),
          if (!compact) ...[
            const SizedBox(width: 6),
            FilledButton(
              onPressed: () => context.go('${AppRoutes.auth}?tab=signup'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
              child: const Text('Create account'),
            ),
          ],
        ],
      ],
    );
  }
}

/// The animated learner on a white card, with small cards showing what a
/// learner actually sees.
class _HeroArt extends StatelessWidget {
  const _HeroArt();

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return AspectRatio(
      aspectRatio: compact ? 1.3 : 1.05,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                left: w * 0.06,
                right: w * 0.06,
                top: w * 0.04,
                bottom: w * 0.04,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF14085A).withValues(alpha: 0.35),
                        blurRadius: 50,
                        offset: const Offset(0, 24),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Lottie.asset(
                    'assets/Student.json',
                    fit: BoxFit.contain,
                    repeat: true,
                    animate: !MediaQuery.disableAnimationsOf(context),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: w * 0.1,
                child: _FloatCard(
                  tint: AppTint.coral,
                  icon: Icons.local_fire_department_rounded,
                  title: '12-day streak',
                  caption: 'Keep it going',
                  compact: compact,
                ),
              ),
              Positioned(
                right: 0,
                top: w * 0.42,
                child: _FloatCard(
                  tint: AppTint.mint,
                  icon: Icons.check_rounded,
                  title: '+20 XP',
                  caption: 'Lesson 7 done',
                  compact: compact,
                ),
              ),
              Positioned(
                left: w * 0.1,
                bottom: 0,
                child: _FloatCard(
                  tint: AppTint.pink,
                  icon: Icons.sports_esports_rounded,
                  title: 'Teal wins!',
                  caption: 'Rope Pull · 5 to 3',
                  compact: compact,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FloatCard extends StatelessWidget {
  final AppTint tint;
  final IconData icon;
  final String title;
  final String caption;
  final bool compact;

  const _FloatCard({
    required this.tint,
    required this.icon,
    required this.title,
    required this.caption,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        padding: EdgeInsets.fromLTRB(10, 10, compact ? 12 : 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF14085A).withValues(alpha: 0.22),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TintIcon(tint: tint, icon: icon, size: compact ? 30 : 38),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 13 : 15,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  caption,
                  style: TextStyle(
                    fontSize: compact ? 11 : 12,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Learning worlds
// ---------------------------------------------------------------------------

class _Worlds extends ConsumerWidget {
  const _Worlds();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worlds = [
      (
        AppTint.mandarin,
        'assets/illustrations/world-mandarin.png',
        'Mandarin',
        'Thirty short lessons. Look, listen, say it, then unlock the next one.',
        () => openLandingFeature(context, ref, 0),
      ),
      (
        AppTint.exams,
        'assets/illustrations/world-exams.png',
        'Past questions',
        'UTME, WASSCE, NECO and Post-UTME. Every answer comes with the working.',
        () => openLandingFeature(context, ref, 1),
      ),
      (
        AppTint.maths,
        'assets/illustrations/world-maths.png',
        'Mental maths',
        'Twenty levels, from times tables to fractions, money and algebra.',
        () => enterRoleSpace(
          context,
          ref,
          UserRole.student,
          AppRoutes.studentMaths,
        ),
      ),
      (
        AppTint.pink,
        'assets/rope_pull/scene/tile.jpg',
        'Rope Pull',
        'A live tug-of-war with classmates. Answer fast and pull for your team.',
        () => openLandingFeature(context, ref, 2),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHead(
          eyebrow: 'Learning worlds',
          title: 'Five worlds. One learning home.',
          body:
              'Every subject has its own colour, so children always know where they are. Progress follows them across all of it.',
        ),
        // Phones: a tidy 2 x 2 grid of compact tiles, so every world is
        // visible at once without a clipped sideways row.
        if (MediaQuery.sizeOf(context).width < 600)
          AdaptiveGrid(
            minTileWidth: 140,
            maxColumns: 2,
            gap: 12,
            children: [
              for (final (i, world) in worlds.indexed)
                _WorldTileCompact(
                  tint: world.$1,
                  asset: world.$2,
                  title: world.$3,
                  caption: const [
                    '30 short lessons',
                    'WAEC, UTME, NECO',
                    '20 levels',
                    'Live with classmates',
                  ][i],
                  onTap: world.$5,
                ),
            ],
          )
        else
          AdaptiveGrid(
            minTileWidth: 240,
            maxColumns: 4,
            gap: 18,
            children: [
              for (final world in worlds)
                _WorldCard(
                  tint: world.$1,
                  asset: world.$2,
                  title: world.$3,
                  body: world.$4,
                  onTap: world.$5,
                ),
            ],
          ),
        const SizedBox(height: 18),
        KvCard(
          tint: AppTint.sun,
          onTap: () => enterRoleSpace(
            context,
            ref,
            UserRole.student,
            AppRoutes.studentLabs,
          ),
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              const TintIcon(
                tint: AppTint.sun,
                icon: Icons.science_rounded,
                size: 52,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Science labs',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      MediaQuery.sizeOf(context).width < 600
                          ? 'Experiments that run in the browser.'
                          : 'Hands-on physics and chemistry experiments that run right in the browser.',
                      style: TextStyle(fontSize: 15, color: AppTint.sun.ink),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: AppTint.sun.ink),
            ],
          ),
        ),
      ],
    );
  }
}

/// Phone tile for one learning world: picture, name and one short line.
class _WorldTileCompact extends StatelessWidget {
  final AppTint tint;
  final String asset;
  final String title;
  final String caption;
  final VoidCallback onTap;

  const _WorldTileCompact({
    required this.tint,
    required this.asset,
    required this.title,
    required this.caption,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return KvCard(
      tint: tint,
      onTap: onTap,
      padding: const EdgeInsets.all(8),
      semanticLabel: 'Open $title. $caption',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: ColoredBox(
                color: tint.strong.withValues(alpha: 0.25),
                child: Image.asset(asset, fit: BoxFit.cover),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: tint.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorldCard extends StatelessWidget {
  final AppTint tint;
  final String asset;
  final String title;
  final String body;
  final VoidCallback onTap;

  const _WorldCard({
    required this.tint,
    required this.asset,
    required this.title,
    required this.body,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return KvCard(
      tint: tint,
      onTap: onTap,
      padding: EdgeInsets.zero,
      semanticLabel: 'Open $title',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: ColoredBox(
                  color: tint.strong.withValues(alpha: 0.25),
                  child: Image.asset(asset, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: tint.strong,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: tint.ink,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Roles
// ---------------------------------------------------------------------------

class _Roles extends ConsumerWidget {
  const _Roles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = [
      (
        AppTint.violet,
        Icons.backpack_rounded,
        'Students',
        'A clear next step every day',
        [
          'Short lessons with audio',
          'Streaks, XP and levels',
          'Rope Pull with classmates',
        ],
        'Start learning',
        () => _startAs(context, ref, UserRole.student, AppRoutes.studentPath),
      ),
      (
        AppTint.mint,
        Icons.co_present_rounded,
        'Teachers',
        'Know who needs you, at a glance',
        [
          'Set lessons, maths and past papers',
          'Live quizzes on the board',
          'See who is stuck and why',
        ],
        'Set up my class',
        () => _startAs(
          context,
          ref,
          UserRole.teacher,
          AppRoutes.teacherDashboard,
        ),
      ),
      (
        AppTint.sky,
        Icons.apartment_rounded,
        'Schools',
        'Every class running in minutes',
        [
          'Invite staff with one code',
          'Place every student in a class',
          'Follow activity across the school',
        ],
        'Set up my school',
        () => _startAs(context, ref, UserRole.teacher, AppRoutes.schoolHome),
      ),
      (
        AppTint.coral,
        Icons.family_restroom_rounded,
        'Parents',
        'See your child’s week',
        [
          'Streaks and time learning',
          'Where they are in each subject',
          'One code links every child',
        ],
        'Follow my child',
        () => _startAs(context, ref, UserRole.parent, AppRoutes.parentHome),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHead(
          eyebrow: 'For everyone',
          tint: AppTint.mint,
          title: 'A space for each person in the school.',
          body:
              'Students, teachers, school leaders and parents each get their own home, built around what they need to do.',
        ),
        _RoleLayout(
          tabs: [
            for (final role in roles)
              (tint: role.$1, icon: role.$2, label: role.$3),
          ],
          children: [
            for (final role in roles)
              KvCard(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TintIcon(tint: role.$1, icon: role.$2, size: 52),
                    const SizedBox(height: 18),
                    Text(
                      role.$3,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      role.$4,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: role.$1.ink,
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final point in role.$5)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: role.$1.strong,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                point,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.35,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: role.$7,
                        style: FilledButton.styleFrom(
                          backgroundColor: role.$1.ink,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(role.$6),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Desktop: all role cards in a grid. Phones: coloured chips pick one card,
/// so the page is not four tall cards in a row.
class _RoleLayout extends StatefulWidget {
  final List<({AppTint tint, IconData icon, String label})> tabs;
  final List<Widget> children;

  const _RoleLayout({required this.tabs, required this.children});

  @override
  State<_RoleLayout> createState() => _RoleLayoutState();
}

class _RoleLayoutState extends State<_RoleLayout> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= 600) {
      return AdaptiveGrid(
        minTileWidth: 250,
        maxColumns: 4,
        gap: 18,
        children: widget.children,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < widget.tabs.length; i++)
              _RoleChip(
                tab: widget.tabs[i],
                selected: i == _selected,
                onTap: () => setState(() => _selected = i),
              ),
          ],
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(
            key: ValueKey(_selected),
            child: widget.children[_selected],
          ),
        ),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  final ({AppTint tint, IconData icon, String label}) tab;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChip({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = tab.tint;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? t.ink : t.soft,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  tab.icon,
                  size: 18,
                  color: selected ? Colors.white : t.ink,
                ),
                const SizedBox(width: 6),
                Text(
                  tab.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : t.ink,
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

// ---------------------------------------------------------------------------
// How it works
// ---------------------------------------------------------------------------

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    const steps = [
      (
        AppTint.violet,
        'Create an account',
        'Pick student, teacher, school or parent. It takes about a minute.',
      ),
      (
        AppTint.sun,
        'Join with a code',
        'Students type their class code. Teachers type the staff code. Parents share a family code.',
      ),
      (
        AppTint.mint,
        'Learn a little every day',
        'Home always shows the next lesson, and streaks keep everyone coming back.',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHead(
          eyebrow: 'How it works',
          tint: AppTint.sun,
          title: 'Up and running in three steps.',
        ),
        if (MediaQuery.sizeOf(context).width < 600)
          const _StepTimeline(steps: steps)
        else
          AdaptiveGrid(
            minTileWidth: 260,
            maxColumns: 3,
            gap: 18,
            children: [
              for (var i = 0; i < steps.length; i++)
                KvCard(
                  tint: steps[i].$1,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: steps[i].$1.strong,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: steps[i].$1 == AppTint.sun
                                ? AppColors.ink
                                : Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        steps[i].$2,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        steps[i].$3,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Phones: the three steps as one compact timeline instead of three tall
/// cards.
class _StepTimeline extends StatelessWidget {
  final List<(AppTint, String, String)> steps;

  const _StepTimeline({required this.steps});

  @override
  Widget build(BuildContext context) {
    return KvCard(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 6),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: steps[i].$1.strong,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: steps[i].$1 == AppTint.sun
                                ? AppColors.ink
                                : Colors.white,
                          ),
                        ),
                      ),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 3,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: steps[i].$1.soft,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 18, top: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            steps[i].$2,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            steps[i].$3,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// School call to action and footer
// ---------------------------------------------------------------------------

class _SchoolCta extends ConsumerWidget {
  const _SchoolCta();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Full width, so the banner's shapes stay clear of the copy.
    return SizedBox(width: double.infinity, child: _schoolBanner(context, ref));
  }

  Widget _schoolBanner(BuildContext context, WidgetRef ref) {
    return HeroBanner(
      colors: HeroColors.parent,
      eyebrow: 'For schools',
      title: 'Bring Kidversity to your whole school.',
      body:
          'Create your school, invite teachers with one staff code, and see every class at a glance.',
      actions: [
        SunButton(
          label: 'Set up my school',
          onPressed: () =>
              _startAs(context, ref, UserRole.teacher, AppRoutes.schoolHome),
        ),
        HeroGhostButton(
          label: 'I am a teacher',
          onPressed: () => _startAs(
            context,
            ref,
            UserRole.teacher,
            AppRoutes.teacherDashboard,
          ),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final side = _sidePadding(width);
    TextButton link(String label, String route) => TextButton(
      onPressed: () => context.go(route),
      style: TextButton.styleFrom(foregroundColor: const Color(0xFFD6D3F0)),
      child: Text(label),
    );
    return ColoredBox(
      color: AppColors.ink,
      child: Padding(
        padding: EdgeInsets.fromLTRB(side, 40, side, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1160),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 24,
              runSpacing: 16,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const KidversityBrandMark(reversed: true, compact: true),
                    const SizedBox(height: 8),
                    Text(
                      '© ${DateTime.now().year} Kidversity. Made for Nigerian classrooms.',
                      style: const TextStyle(
                        color: Color(0xFFB7B4D6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    link('Privacy', '/privacy'),
                    link('Terms', '/terms'),
                    link('Guardian consent', '/guardian-consent'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

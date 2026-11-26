import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';
import '../widgets/effects.dart';
import '../widgets/math_text.dart';

/// Public home for ACE: what it is, the four channels, how a study session
/// works and what schools get. Signed-in learners never see this page.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final side = w < 600 ? 20.0 : (w < 1100 ? 40.0 : 72.0);
    return Scaffold(
      backgroundColor: Ace.paper,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Hero(side: side),
          _Section(
            side: side,
            eyebrow: 'Four channels',
            title: 'AS and A2, Mathematics and Physics.',
            body:
                'Each stage has its own channel, so you always study at the right depth. '
                'A2 links back to the AS topics it builds on.',
            child: const _ChannelGrid(),
          ),
          _Section(
            side: side,
            tint: Colors.white,
            eyebrow: 'How it works',
            title: 'Learn it. Write it. Get it right.',
            child: const _Steps(),
          ),
          _Section(
            side: side,
            eyebrow: 'For schools',
            title: 'Built with teachers in the loop.',
            child: const _SchoolPoints(),
          ),
          _Cta(side: side),
          _Footer(side: side),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final double side;

  const _Hero({required this.side});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final wide = w >= 1000;
    final copy = Column(
      crossAxisAlignment: wide
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Reveal(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white24),
            ),
            child: const Text(
              'Cambridge International AS & A Level',
              style: TextStyle(
                color: Color(0xFFDCE4F2),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Reveal(
          delay: const Duration(milliseconds: 120),
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Advance. Conquer.\n'),
                TextSpan(
                  text: 'Excel.',
                  style: TextStyle(color: Ace.amber),
                ),
              ],
            ),
            textAlign: wide ? TextAlign.start : TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              fontSize: w < 600 ? 44 : 72,
              height: 1.02,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -1.5,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Reveal(
          delay: const Duration(milliseconds: 240),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              'A-level Mathematics and Physics, one topic at a time. Write out your working '
              'like you would in the exam, check your answer in seconds and learn from a '
              'clear worked solution.',
              textAlign: wide ? TextAlign.start : TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFC9D3E6),
                fontSize: 18,
                height: 1.6,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Reveal(
          delay: const Duration(milliseconds: 360),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              FilledButton(
                onPressed: () => context.go('/sign-in?create=1'),
                style: FilledButton.styleFrom(
                  backgroundColor: Ace.amber,
                  foregroundColor: Ace.navy,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 20,
                  ),
                ),
                child: const Text('Start learning'),
              ),
              OutlinedButton(
                onPressed: () => context.go('/sign-in'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38, width: 1.5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 20,
                  ),
                ),
                child: const Text('I have an account'),
              ),
            ],
          ),
        ),
      ],
    );

    return AuroraBackdrop(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(side, 20, side, wide ? 96 : 64),
          child: Column(
            children: [
              Row(
                children: [
                  const AceWordmark(onDark: true),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.go('/sign-in'),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    child: const Text('Sign in'),
                  ),
                ],
              ),
              SizedBox(height: wide ? 80 : 48),
              if (wide)
                Row(
                  children: [
                    Expanded(flex: 11, child: copy),
                    const SizedBox(width: 48),
                    const Expanded(flex: 9, child: _PreviewStack()),
                  ],
                )
              else ...[
                copy,
                const SizedBox(height: 48),
                const _PreviewStack(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A floating glimpse of a real lesson: a question, a learner's working and
/// the checked result.
class _PreviewStack extends StatelessWidget {
  const _PreviewStack();

  @override
  Widget build(BuildContext context) {
    return Reveal(
      delay: const Duration(milliseconds: 450),
      from: const Offset(0.06, 0),
      child: Floating(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 50,
                      offset: const Offset(0, 24),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Ace.mathsSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'AS Mathematics · Differentiation',
                            style: TextStyle(
                              color: Ace.maths,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Text('[2]', style: TextStyle(color: Ace.inkSoft)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const MathText(
                      r'For $y=2x^3-3x^2$, find the gradient of the tangent at $x=2$.',
                      style: TextStyle(
                        fontSize: 17,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                        color: Ace.ink,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Ace.paper,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Ace.line),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MathBlock(
                            r'\frac{dy}{dx} = 6x^2 - 6x',
                            style: TextStyle(fontSize: 19, color: Ace.ink),
                          ),
                          SizedBox(height: 10),
                          MathBlock(
                            r'6(2)^2 - 6(2) = 12',
                            style: TextStyle(fontSize: 19, color: Ace.ink),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Ace.goodSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Ace.good),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Your final answer matches: 12',
                              style: TextStyle(
                                color: Ace.good,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: -18,
                top: -26,
                child: Floating(
                  amplitude: 5,
                  period: const Duration(seconds: 4),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Ace.navy,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ProgressRing(
                          value: 0.72,
                          size: 44,
                          stroke: 5,
                          color: Ace.amber,
                          track: Colors.white12,
                          center: Text(
                            '72%',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Topic mastery',
                              style: TextStyle(
                                color: Color(0xFFC9D3E6),
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              'Calculus',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -22,
                bottom: -24,
                child: Floating(
                  amplitude: 6,
                  period: const Duration(seconds: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          color: Color(0xFFF97316),
                        ),
                        SizedBox(width: 6),
                        Text(
                          '5-day streak',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Ace.ink,
                          ),
                        ),
                      ],
                    ),
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

class _Section extends StatelessWidget {
  final double side;
  final String eyebrow;
  final String title;
  final String? body;
  final Widget child;
  final Color? tint;

  const _Section({
    required this.side,
    required this.eyebrow,
    required this.title,
    required this.child,
    this.body,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return Container(
      color: tint,
      padding: EdgeInsets.symmetric(
        horizontal: side,
        vertical: narrow ? 56 : 88,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: const TextStyle(
                  color: Ace.amber,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: narrow ? 30 : 42,
                  fontWeight: FontWeight.w700,
                  color: Ace.ink,
                  height: 1.1,
                  letterSpacing: -0.8,
                ),
              ),
              if (body != null) ...[
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Text(
                    body!,
                    style: const TextStyle(
                      color: Ace.inkSoft,
                      fontSize: 17,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 36),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelGrid extends StatelessWidget {
  const _ChannelGrid();

  static const _channels = [
    ('AS', 'Mathematics', 'Quadratics, calculus, functions and more', '∫'),
    ('AS', 'Physics', 'Motion, forces, waves and circuits', 'Ω'),
    (
      'A2',
      'Mathematics',
      'Vectors, differential equations, complex numbers',
      'Σ',
    ),
    ('A2', 'Physics', 'Fields, orbits, nuclear and quantum physics', 'λ'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth >= 1000 ? 4 : (box.maxWidth >= 560 ? 2 : 1);
        final gap = 18.0;
        final tileW = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (i, c) in _channels.indexed)
              SizedBox(
                width: tileW,
                child: Reveal(
                  delay: Duration(milliseconds: 80 * i),
                  child: HoverLift(
                    child: _ChannelTile(
                      stage: c.$1,
                      subject: c.$2,
                      body: c.$3,
                      glyph: c.$4,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final String stage;
  final String subject;
  final String body;
  final String glyph;

  const _ChannelTile({
    required this.stage,
    required this.subject,
    required this.body,
    required this.glyph,
  });

  @override
  Widget build(BuildContext context) {
    final color = Ace.subject(subject);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 230,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, Color.lerp(color, Ace.navy, 0.55)!],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              bottom: -40,
              child: Text(
                glyph,
                style: TextStyle(
                  fontSize: 190,
                  color: Colors.white.withValues(alpha: 0.14),
                  height: 1,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      stage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    subject,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: const TextStyle(
                      color: Color(0xE6FFFFFF),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps();

  static const _steps = [
    (
      Icons.menu_book_rounded,
      'Study the topic',
      'Short, clear lessons with a worked example and the mistakes to avoid.',
    ),
    (
      Icons.edit_note_rounded,
      'Write your working',
      'Answer like the exam: equations, steps and units, not just a number.',
    ),
    (
      Icons.fact_check_rounded,
      'Check and improve',
      'Your final answer is checked instantly. See the worked solution, then try again.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 860;
    final tiles = [
      for (final (i, s) in _steps.indexed)
        Reveal(
          delay: Duration(milliseconds: 100 * i),
          child: Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: Ace.paper,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Ace.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Ace.navy,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(s.$1, color: Ace.amber),
                    ),
                    const Spacer(),
                    Text(
                      '0${i + 1}',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: Ace.line,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  s.$2,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  s.$3,
                  style: const TextStyle(color: Ace.inkSoft, height: 1.55),
                ),
              ],
            ),
          ),
        ),
    ];
    if (!wide) {
      return Column(
        children: [
          for (final t in tiles)
            Padding(padding: const EdgeInsets.only(bottom: 16), child: t),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 18),
          Expanded(child: tiles[i]),
        ],
      ],
    );
  }
}

class _SchoolPoints extends StatelessWidget {
  const _SchoolPoints();

  static const _points = [
    (
      Icons.rate_review_rounded,
      'Teachers mark the method',
      'A correct final answer never earns full marks on its own. Written working goes to the teacher.',
    ),
    (
      Icons.lock_rounded,
      'Your school, your content',
      'Schools add their own questions and quizzes, kept private to the school.',
    ),
    (
      Icons.insights_rounded,
      'Progress you can act on',
      'See every learner\'s progress by topic and who needs support.',
    ),
    (
      Icons.verified_rounded,
      'Reviewed by subject teachers',
      'Every lesson and question is checked by a Mathematics or Physics specialist before it is published.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth >= 860 ? 2 : 1;
        final tileW = (box.maxWidth - 18 * (cols - 1)) / cols;
        return Wrap(
          spacing: 18,
          runSpacing: 18,
          children: [
            for (final p in _points)
              SizedBox(
                width: tileW,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Ace.amberSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(p.$1, color: Ace.warn),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.$2,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            p.$3,
                            style: const TextStyle(
                              color: Ace.inkSoft,
                              height: 1.55,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Cta extends StatelessWidget {
  final double side;

  const _Cta({required this.side});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(side, 0, side, 72),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: AuroraBackdrop(
              symbols: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 56,
                ),
                child: Column(
                  children: [
                    Text(
                      'Ready to conquer A-level?',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Create your account, then join your school with the code from your teacher.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFC9D3E6), fontSize: 16),
                    ),
                    const SizedBox(height: 26),
                    FilledButton(
                      onPressed: () => context.go('/sign-in?create=1'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Ace.amber,
                        foregroundColor: Ace.navy,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 20,
                        ),
                      ),
                      child: const Text('Create your account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final double side;

  const _Footer({required this.side});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: side, vertical: 28),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          const AceWordmark(),
          Text(
            '© ${DateTime.now().year} ACE · Advance. Conquer. Excel.',
            style: const TextStyle(color: Ace.inkSoft),
          ),
        ],
      ),
    );
  }
}

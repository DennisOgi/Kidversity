import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/api.dart';
import '../theme.dart';
import '../widgets/effects.dart';
import '../widgets/page.dart';

String _greeting() {
  final h = DateTime.now().hour;
  return h < 12 ? 'Good morning' : (h < 17 ? 'Good afternoon' : 'Good evening');
}

/// Learner home: greeting, study stats, "continue", then channels by stage.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<Map<String, dynamic>> _me = AceApi.instance.me();

  void _reload() => setState(() => _me = AceApi.instance.me());

  @override
  Widget build(BuildContext context) {
    return AceAsync<Map<String, dynamic>>(
      future: _me,
      onRetry: _reload,
      message: AceApi.message,
      builder: (me) {
        final name = (me['display_name'] as String? ?? '').split(' ').first;
        final schools = (me['schools'] as List? ?? const []);
        final stats = Map<String, dynamic>.from(
          me['stats'] as Map? ?? const {},
        );
        final resume = me['resume'] == null
            ? null
            : Map<String, dynamic>.from(me['resume'] as Map);
        final channels = [
          for (final c in (me['channels'] as List? ?? const []))
            Map<String, dynamic>.from(c as Map),
        ];
        final school = schools.isEmpty
            ? null
            : (schools.first as Map)['name'] as String?;
        return AcePage(
          onRefresh: () async => _reload(),
          header: HeroBand(
            child: _Greeting(
              name: name,
              school: school,
              stats: stats,
              resume: resume,
            ),
          ),
          children: [
            if (schools.isEmpty) Reveal(child: _JoinSchool(onJoined: _reload)),
            for (final (si, stage) in const ['AS', 'A2'].indexed)
              if (channels.any((c) => c['stage'] == stage))
                Reveal(
                  delay: Duration(milliseconds: 120 + si * 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StageHeader(stage: stage),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, box) {
                          final twoUp = box.maxWidth >= 680;
                          final cards = [
                            for (final c in channels.where(
                              (c) => c['stage'] == stage,
                            ))
                              _ChannelCard(channel: c),
                          ];
                          if (!twoUp) {
                            return Column(
                              children: [
                                for (final card in cards) ...[
                                  card,
                                  const SizedBox(height: 14),
                                ],
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var i = 0; i < cards.length; i++) ...[
                                if (i > 0) const SizedBox(width: 18),
                                Expanded(child: cards[i]),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
            if (schools.isNotEmpty && channels.isEmpty)
              const AceCard(
                child: Text(
                  'Your school has not added any subjects yet. Check back soon.',
                  style: TextStyle(color: Ace.inkSoft),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Greeting extends StatelessWidget {
  final String name;
  final String? school;
  final Map<String, dynamic> stats;
  final Map<String, dynamic>? resume;

  const _Greeting({
    required this.name,
    required this.school,
    required this.stats,
    required this.resume,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final tried = (stats['questions_tried'] as num?)?.toInt() ?? 0;
    final matched = (stats['matched'] as num?)?.toInt() ?? 0;
    final streak = (stats['streak_days'] as num?)?.toInt() ?? 0;
    final review = (stats['awaiting_teacher'] as num?)?.toInt() ?? 0;

    final hello = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Reveal(
          child: Text(
            [_greeting(), ?school].join(' · '),
            style: const TextStyle(
              color: Color(0xFFC9D3E6),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Reveal(
          delay: const Duration(milliseconds: 80),
          child: Text(
            name.isEmpty ? 'Ready to advance?' : 'Ready to advance, $name?',
            style: GoogleFonts.spaceGrotesk(
              fontSize: wide ? 40 : 30,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.1,
              letterSpacing: -0.6,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Reveal(
          delay: const Duration(milliseconds: 160),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Stat(
                icon: Icons.local_fire_department_rounded,
                iconColor: const Color(0xFFF97316),
                value: streak,
                label: streak == 1 ? 'day streak' : 'day streak',
              ),
              _Stat(
                icon: Icons.edit_note_rounded,
                iconColor: Ace.amber,
                value: tried,
                label: 'questions tried',
              ),
              _Stat(
                icon: Icons.check_circle_rounded,
                iconColor: const Color(0xFF34D399),
                value: matched,
                label: 'answers correct',
              ),
              if (review > 0)
                _Stat(
                  icon: Icons.rate_review_rounded,
                  iconColor: const Color(0xFF93C5FD),
                  value: review,
                  label: 'with your teacher',
                ),
            ],
          ),
        ),
      ],
    );

    final cont = resume == null
        ? _ContinueCard(
            title: 'Start your first lesson',
            subtitle: 'Pick a channel below to begin.',
            onTap: null,
          )
        : _ContinueCard(
            title: resume!['title'] as String,
            subtitle: '${resume!['stage']} ${resume!['subject']}',
            onTap: () => context.push('/l/${resume!['lesson_id']}'),
          );

    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [hello, const SizedBox(height: 22), cont],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: hello),
        const SizedBox(width: 32),
        SizedBox(width: 360, child: cont),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final int value;
  final String label;

  const _Stat({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 10),
          CountUp(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Color(0xFFC9D3E6), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ContinueCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Reveal(
      delay: const Duration(milliseconds: 240),
      from: const Offset(0.05, 0),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Ace.amber,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Ace.navy,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        onTap == null ? 'GET STARTED' : 'CONTINUE',
                        style: const TextStyle(
                          fontSize: 11.5,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w800,
                          color: Ace.warn,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: Ace.ink,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Ace.inkSoft,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  const Icon(Icons.arrow_forward_rounded, color: Ace.navy),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StageHeader extends StatelessWidget {
  final String stage;

  const _StageHeader({required this.stage});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Ace.navy,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            stage,
            style: const TextStyle(
              color: Ace.amber,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          stage == 'AS' ? 'AS Level' : 'A2 · completing the A Level',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
  }
}

class _ChannelCard extends StatelessWidget {
  final Map<String, dynamic> channel;

  const _ChannelCard({required this.channel});

  @override
  Widget build(BuildContext context) {
    final subject = channel['subject'] as String;
    final color = Ace.subject(subject);
    final lessons = (channel['lessons'] as num?)?.toInt() ?? 0;
    final questions = (channel['questions'] as num?)?.toInt() ?? 0;
    final attempted = (channel['attempted'] as num?)?.toInt() ?? 0;
    final matched = (channel['matched'] as num?)?.toInt() ?? 0;
    final pct = questions == 0 ? 0.0 : attempted / questions;
    final glyph = subject == 'Physics'
        ? (channel['stage'] == 'AS' ? 'Ω' : 'λ')
        : (channel['stage'] == 'AS' ? '∫' : 'Σ');
    return HoverLift(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/c/${channel['id']}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 118,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, Color.lerp(color, Ace.navy, 0.6)!],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: 12,
                      top: -26,
                      child: Text(
                        glyph,
                        style: TextStyle(
                          fontSize: 150,
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  '${channel['stage']} $subject',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  channel['syllabus'] as String? ?? '',
                                  style: const TextStyle(
                                    color: Color(0xE6FFFFFF),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ProgressRing(
                            value: pct,
                            size: 58,
                            stroke: 6,
                            color: Ace.amber,
                            track: Colors.white24,
                            center: Text(
                              '${(pct * 100).round()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 6,
                        children: [
                          _Mini(
                            icon: Icons.menu_book_rounded,
                            text: '$lessons lesson${lessons == 1 ? '' : 's'}',
                          ),
                          _Mini(
                            icon: Icons.edit_note_rounded,
                            text: '$attempted of $questions tried',
                          ),
                          if (matched > 0)
                            _Mini(
                              icon: Icons.check_circle_outline_rounded,
                              text: '$matched correct',
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.arrow_forward_rounded, color: color),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Mini({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Ace.inkSoft),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(color: Ace.inkSoft, fontSize: 13)),
      ],
    );
  }
}

class _JoinSchool extends StatefulWidget {
  final VoidCallback onJoined;

  const _JoinSchool({required this.onJoined});

  @override
  State<_JoinSchool> createState() => _JoinSchoolState();
}

class _JoinSchoolState extends State<_JoinSchool> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (_code.text.trim().length < 4) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AceApi.instance.joinSchool(_code.text);
      widget.onJoined();
    } catch (e) {
      setState(() => _error = AceApi.message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AceCard(
      accent: Ace.amber,
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Ace.amberSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.school_rounded, color: Ace.warn),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Join your school',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Enter the code from your teacher. Your subjects appear as soon as you join.',
            style: TextStyle(color: Ace.inkSoft),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(labelText: 'School code'),
                  onSubmitted: (_) => _join(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _busy ? null : _join,
                child: const Text('Join'),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Ace.bad)),
          ],
        ],
      ),
    );
  }
}

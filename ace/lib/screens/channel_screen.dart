import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/api.dart';
import '../theme.dart';
import '../widgets/effects.dart';
import '../widgets/page.dart';

/// One channel (e.g. AS Mathematics): a hero with progress, then the lessons
/// as a learning path in teaching order.
class ChannelScreen extends StatefulWidget {
  final String channelId;

  const ChannelScreen({super.key, required this.channelId});

  @override
  State<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen> {
  late Future<(Map<String, dynamic>, Map<String, dynamic>)> _data = _load();

  Future<(Map<String, dynamic>, Map<String, dynamic>)> _load() async {
    final results = await Future.wait([
      AceApi.instance.channel(widget.channelId),
      AceApi.instance.progress(widget.channelId),
    ]);
    return (results[0], results[1]);
  }

  void _reload() => setState(() => _data = _load());

  @override
  Widget build(BuildContext context) {
    return AceAsync(
      future: _data,
      onRetry: _reload,
      message: AceApi.message,
      builder: (data) {
        final (channel, progress) = data;
        final subject = channel['subject'] as String;
        final color = Ace.subject(subject);
        final lessons = [
          for (final l in (channel['lessons'] as List? ?? const []))
            Map<String, dynamic>.from(l as Map),
        ];
        final total = (progress['questions'] as num?)?.toInt() ?? 0;
        final tried = (progress['attempted'] as num?)?.toInt() ?? 0;
        final matched =
            (progress['final_answer_matched'] as num?)?.toInt() ?? 0;
        final review = (progress['awaiting_teacher'] as num?)?.toInt() ?? 0;
        final wide = MediaQuery.sizeOf(context).width >= 760;

        final ring = ProgressRing(
          value: total == 0 ? 0 : tried / total,
          size: wide ? 118 : 92,
          stroke: 10,
          color: Ace.amber,
          track: Colors.white12,
          center: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${total == 0 ? 0 : (tried * 100 / total).round()}%',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: wide ? 28 : 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Text(
                'tried',
                style: TextStyle(color: Color(0xFFC9D3E6), fontSize: 12),
              ),
            ],
          ),
        );

        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () => goBack(context, '/'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFC9D3E6),
                padding: EdgeInsets.zero,
              ),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('My channels'),
            ),
            const SizedBox(height: 6),
            Reveal(
              child: Text(
                '${channel['stage']} $subject',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: wide ? 44 : 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.8,
                ),
              ),
            ),
            Text(
              channel['syllabus'] as String? ?? '',
              style: const TextStyle(color: Color(0xFFC9D3E6)),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Pill(
                  icon: Icons.menu_book_rounded,
                  text: '${lessons.length} lessons',
                ),
                _Pill(
                  icon: Icons.edit_note_rounded,
                  text: '$tried of $total questions tried',
                ),
                _Pill(
                  icon: Icons.check_circle_rounded,
                  text: '$matched correct',
                ),
                if (review > 0)
                  _Pill(
                    icon: Icons.rate_review_rounded,
                    text: '$review with your teacher',
                  ),
              ],
            ),
          ],
        );

        return AcePage(
          backTo: '/',
          onRefresh: () async => _reload(),
          header: HeroBand(
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: title),
                      const SizedBox(width: 24),
                      ring,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [title, const SizedBox(height: 20), ring],
                  ),
          ),
          children: [
            if (channel['prerequisite_channel'] != null)
              Reveal(
                child: AceCard(
                  onTap: () =>
                      context.push('/c/${channel['prerequisite_channel']}'),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Ace.subjectSoft(subject),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.history_edu_rounded, color: color),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Revisit the foundations',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              'The AS lessons this channel builds on',
                              style: TextStyle(color: Ace.inkSoft),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_rounded, color: color),
                    ],
                  ),
                ),
              ),
            Text(
              'Your learning path',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (lessons.isEmpty)
              const AceCard(
                child: Text(
                  'New lessons are on the way.',
                  style: TextStyle(color: Ace.inkSoft),
                ),
              ),
            for (final (i, l) in lessons.indexed)
              Reveal(
                delay: Duration(milliseconds: 90 * i),
                child: _PathStep(
                  index: i,
                  last: i == lessons.length - 1,
                  lesson: l,
                  color: color,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Pill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Ace.amber),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PathStep extends StatelessWidget {
  final int index;
  final bool last;
  final Map<String, dynamic> lesson;
  final Color color;

  const _PathStep({
    required this.index,
    required this.last,
    required this.lesson,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final answered = (lesson['answered'] as num?)?.toInt() ?? 0;
    final questions = (lesson['questions'] as num?)?.toInt() ?? 0;
    final done = questions > 0 && answered >= questions;
    final started = answered > 0;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 52,
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: done ? color : (started ? Colors.white : Ace.paper),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: started || done ? color : Ace.line,
                      width: 2.5,
                    ),
                    boxShadow: started
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.3),
                              blurRadius: 14,
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: done
                      ? const Icon(Icons.check_rounded, color: Colors.white)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: started ? color : Ace.inkSoft,
                          ),
                        ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 3,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: done ? color : Ace.line,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 16),
              child: AceCard(
                accent: started ? color : null,
                onTap: () => context.push('/l/${lesson['id']}'),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (lesson['topic'] != null)
                            Text(
                              [
                                if (lesson['topic_ref'] != null)
                                  lesson['topic_ref'],
                                lesson['topic'],
                              ].join(' · ').toUpperCase(),
                              style: TextStyle(
                                fontSize: 11.5,
                                letterSpacing: 1.1,
                                fontWeight: FontWeight.w800,
                                color: color,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            lesson['title'] as String,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Ace.ink,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              if (lesson['minutes'] != null) ...[
                                const Icon(
                                  Icons.schedule_rounded,
                                  size: 16,
                                  color: Ace.inkSoft,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${lesson['minutes']} min',
                                  style: const TextStyle(
                                    color: Ace.inkSoft,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 14),
                              ],
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(99),
                                  child: LinearProgressIndicator(
                                    value: questions == 0
                                        ? 0
                                        : answered / questions,
                                    minHeight: 6,
                                    backgroundColor: Ace.line,
                                    color: color,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '$answered/$questions',
                                style: const TextStyle(
                                  color: Ace.inkSoft,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: started ? color : Ace.navy,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        done ? 'Review' : (started ? 'Continue' : 'Start'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

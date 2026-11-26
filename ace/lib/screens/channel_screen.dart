import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/api.dart';
import '../theme.dart';
import '../widgets/page.dart';

/// One channel (e.g. AS Mathematics): its lessons in teaching order, with
/// how many questions you have tried in each.
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
        final total = progress['questions'] as int? ?? 0;
        final tried = progress['attempted'] as int? ?? 0;
        return AcePage(
          onRefresh: () async => _reload(),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('All channels'),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Ace.navy, Color.lerp(Ace.navy, color, 0.55)!],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel['syllabus'] as String? ?? '',
                    style: const TextStyle(color: Color(0xFFC9D3E6)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${channel['stage']} $subject',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : tried / total,
                      minHeight: 8,
                      backgroundColor: Colors.white24,
                      color: Ace.amber,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$tried of $total questions tried · '
                    '${progress['final_answer_matched'] ?? 0} final answers matched · '
                    '${progress['awaiting_teacher'] ?? 0} waiting for your teacher',
                    style: const TextStyle(color: Colors.white, fontSize: 13.5),
                  ),
                ],
              ),
            ),
            if (channel['route_pending'] == true)
              const AceCard(
                accent: Ace.amber,
                child: Text(
                  'Your school has not confirmed its Mathematics paper route yet, so '
                  'every topic in this channel is shown for now.',
                  style: TextStyle(color: Ace.warn),
                ),
              ),
            if (channel['prerequisite_channel'] != null)
              AceCard(
                onTap: () =>
                    context.go('/c/${channel['prerequisite_channel']}'),
                child: Row(
                  children: [
                    const Icon(Icons.history_edu_rounded, color: Ace.inkSoft),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Revisit the AS lessons this channel builds on',
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded, color: color),
                  ],
                ),
              ),
            Text('Lessons', style: Theme.of(context).textTheme.titleLarge),
            if (lessons.isEmpty)
              const AceCard(
                child: Text(
                  'No lessons are available in this channel yet.',
                  style: TextStyle(color: Ace.inkSoft),
                ),
              ),
            for (final (i, l) in lessons.indexed)
              AceCard(
                accent: color,
                onTap: () => context.go('/l/${l['id']}'),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Ace.subjectSoft(subject),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l['title'] as String,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (l['topic_ref'] != null)
                                'Syllabus ${l['topic_ref']}',
                              if (l['topic'] != null) l['topic'],
                              if (l['minutes'] != null) '${l['minutes']} min',
                              '${l['answered']}/${l['questions']} questions tried',
                            ].join(' · '),
                            style: const TextStyle(
                              color: Ace.inkSoft,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (l['review_status'] != 'published') ...[
                      const SizedBox(width: 8),
                      const AceChip(
                        'Draft',
                        color: Ace.warn,
                        background: Ace.warnSoft,
                      ),
                    ],
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, color: color),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

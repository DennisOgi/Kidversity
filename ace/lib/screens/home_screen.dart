import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/api.dart';
import '../theme.dart';
import '../widgets/page.dart';

/// Your channels, grouped AS then A2. With no school yet, a join-code card.
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
        final channels = [
          for (final c in (me['channels'] as List? ?? const []))
            Map<String, dynamic>.from(c as Map),
        ];
        return AcePage(
          onRefresh: () async => _reload(),
          children: [
            Text(
              name.isEmpty ? 'Your study channels' : 'Welcome, $name',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (schools.isNotEmpty)
              Text(
                [for (final s in schools) (s as Map)['name']].join(' · '),
                style: const TextStyle(color: Ace.inkSoft),
              ),
            if (schools.isEmpty) _JoinSchool(onJoined: _reload),
            for (final stage in const ['AS', 'A2'])
              if (channels.any((c) => c['stage'] == stage)) ...[
                _StageHeader(stage: stage),
                LayoutBuilder(
                  builder: (context, box) {
                    final twoUp = box.maxWidth >= 640;
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
                            const SizedBox(height: 12),
                          ],
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < cards.length; i++) ...[
                          if (i > 0) const SizedBox(width: 16),
                          Expanded(child: cards[i]),
                        ],
                      ],
                    );
                  },
                ),
              ],
            if (schools.isNotEmpty && channels.isEmpty)
              const AceCard(
                child: Text(
                  'Your school has not added any ACE channels yet. Ask your teacher.',
                  style: TextStyle(color: Ace.inkSoft),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StageHeader extends StatelessWidget {
  final String stage;

  const _StageHeader({required this.stage});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
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
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            stage == 'AS' ? 'AS Level' : 'A2 · full A Level',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
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
    final lessons = channel['lessons'] ?? 0;
    return AceCard(
      accent: color,
      onTap: () => context.go('/c/${channel['id']}'),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Ace.subjectSoft(subject),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              subject == 'Physics'
                  ? Icons.bolt_rounded
                  : Icons.functions_rounded,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${channel['stage']} $subject',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: 19),
                ),
                const SizedBox(height: 2),
                Text(
                  '${channel['syllabus']} · $lessons lesson${lessons == 1 ? '' : 's'}',
                  style: const TextStyle(color: Ace.inkSoft),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded, color: color),
        ],
      ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Join your school',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            'Enter the code your school gave you. Your channels appear as soon as you join.',
            style: TextStyle(color: Ace.inkSoft),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
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

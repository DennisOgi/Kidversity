import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../data/api.dart';
import '../theme.dart';
import '../widgets/effects.dart';
import '../widgets/math_text.dart';
import 'staff_ui.dart';

String _hello() {
  final h = DateTime.now().hour;
  return h < 12 ? 'Good morning' : (h < 17 ? 'Good afternoon' : 'Good evening');
}

class StaffOverviewScreen extends StatefulWidget {
  const StaffOverviewScreen({super.key});

  @override
  State<StaffOverviewScreen> createState() => _StaffOverviewScreenState();
}

class _StaffOverviewScreenState extends State<StaffOverviewScreen> {
  late Future<Map<String, dynamic>> _data = _load();

  Future<Map<String, dynamic>> _load() async {
    final d = await AceApi.instance.staffOverview();
    StaffSession.info.value = d;
    if (mounted) setState(() {});
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final info = StaffSession.info.value;
    final first = ((info?['display_name'] as String?) ?? '').split(' ').first;
    return StaffShell(
      current: '/staff',
      title: first.isEmpty ? _hello() : '${_hello()}, $first',
      subtitle: 'Here is how your school is learning this week.',
      actions: [
        OutlinedButton.icon(
          onPressed: () => setState(() => _data = _load()),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Refresh'),
        ),
        FilledButton.icon(
          onPressed: () => context.go('/staff/marking'),
          icon: const Icon(Icons.rate_review_rounded, size: 18),
          label: const Text('Start marking'),
        ),
      ],
      child: StaffAsync<Map<String, dynamic>>(
        future: _data,
        onRetry: () => setState(() => _data = _load()),
        builder: (d) => _Body(data: d),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final Map<String, dynamic> data;

  const _Body({required this.data});

  int _n(String k) => ((data['counts'] as Map?)?[k] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1200;
    final channels = [
      for (final c in (data['channels'] as List? ?? const []))
        Map<String, dynamic>.from(c as Map),
    ];
    final attention = [
      for (final c in (data['attention'] as List? ?? const []))
        Map<String, dynamic>.from(c as Map),
    ];
    final recent = [
      for (final c in (data['recent'] as List? ?? const []))
        Map<String, dynamic>.from(c as Map),
    ];
    final activity = [
      for (final c in (data['activity'] as List? ?? const []))
        Map<String, dynamic>.from(c as Map),
    ];
    final school = Map<String, dynamic>.from(
      data['school'] as Map? ?? const {},
    );

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Reveal(child: _ActivityChart(activity: activity)),
        const SizedBox(height: 16),
        Reveal(
          delay: const Duration(milliseconds: 80),
          child: _Subjects(channels: channels),
        ),
        const SizedBox(height: 16),
        Reveal(
          delay: const Duration(milliseconds: 160),
          child: _Recent(items: recent),
        ),
      ],
    );
    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (school['join_code'] != null) ...[
          Reveal(child: _JoinCode(code: school['join_code'] as String)),
          const SizedBox(height: 16),
        ],
        Reveal(
          delay: const Duration(milliseconds: 120),
          child: _Attention(items: attention),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TileGrid(
          minWidth: 160,
          children: [
            Kpi(
              icon: Icons.rate_review_rounded,
              color: Ace.amber,
              label: 'Waiting to be marked',
              value: '${_n('to_mark')}',
              caption: '${_n('marked_7d')} marked this week',
              highlight: true,
              onTap: () => context.go('/staff/marking'),
            ),
            Kpi(
              icon: Icons.groups_rounded,
              color: Ace.maths,
              label: 'Students',
              value: '${_n('students')}',
              caption: '${_n('teachers')} staff',
              onTap: () => context.go('/staff/progress'),
            ),
            Kpi(
              icon: Icons.bolt_rounded,
              color: Ace.physics,
              label: 'Active this week',
              value: '${_n('active_7d')}',
              caption: _n('students') == 0
                  ? 'No students yet'
                  : '${(_n('active_7d') * 100 / _n('students')).round()}% of students',
            ),
            Kpi(
              icon: Icons.edit_note_rounded,
              color: const Color(0xFF8B5CF6),
              label: 'Answers this week',
              value: '${_n('attempts_7d')}',
              caption: 'Practice attempts submitted',
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: left),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: right),
            ],
          )
        else ...[
          right,
          const SizedBox(height: 16),
          left,
        ],
      ],
    );
  }
}

class _ActivityChart extends StatelessWidget {
  final List<Map<String, dynamic>> activity;

  const _ActivityChart({required this.activity});

  @override
  Widget build(BuildContext context) {
    final values = [
      for (final a in activity) (a['attempts'] as num?)?.toInt() ?? 0,
    ];
    final peak = values.fold<int>(0, (m, v) => v > m ? v : m);
    final total = values.fold<int>(0, (s, v) => s + v);
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Panel(
      title: 'Learning activity',
      subtitle: '$total answers in the last 14 days',
      child: SizedBox(
        height: 170,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final (i, a) in activity.indexed)
              Expanded(
                child: Tooltip(
                  message: '${values[i]} answers',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (values[i] > 0)
                          Text(
                            '${values[i]}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Ace.inkSoft,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        const SizedBox(height: 4),
                        TweenAnimationBuilder<double>(
                          tween: Tween(
                            begin: 0,
                            end: peak == 0 ? 0 : values[i] / peak,
                          ),
                          duration: Duration(milliseconds: 600 + i * 40),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, _) => Container(
                            height: 6 + 110 * v,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: i == activity.length - 1
                                    ? [Ace.amber, const Color(0xFFFFCB4D)]
                                    : [Ace.navySoft, Ace.maths],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          days[(DateTime.tryParse('${a['day']}')?.weekday ??
                                  1) -
                              1],
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Ace.inkSoft,
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
    );
  }
}

class _Subjects extends StatelessWidget {
  final List<Map<String, dynamic>> channels;

  const _Subjects({required this.channels});

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Subjects',
      subtitle: 'Correct final answers across all attempts',
      child: Column(
        children: [
          for (final c in channels)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.go('/staff/progress?channel=${c['id']}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 4,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Ace.subjectSoft(c['subject'] as String),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        c['stage'] as String,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Ace.subject(c['subject'] as String),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 150,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${c['stage']} ${c['subject']}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${c['learners']} learners · ${c['attempts']} answers',
                            style: const TextStyle(
                              color: Ace.inkSoft,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(
                            begin: 0,
                            end: ((c['correct_rate'] as num?) ?? 0) / 100,
                          ),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, _) => LinearProgressIndicator(
                            value: v,
                            minHeight: 10,
                            backgroundColor: const Color(0xFFEDEFF5),
                            color: Ace.subject(c['subject'] as String),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 48,
                      child: Text(
                        c['correct_rate'] == null
                            ? '–'
                            : '${c['correct_rate']}%',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
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

class _Attention extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const _Attention({required this.items});

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'May need support',
      subtitle: 'Under 60% correct, or not started',
      child: items.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Everyone is on track. 🎉',
                style: TextStyle(color: Ace.inkSoft),
              ),
            )
          : Column(
              children: [
                for (final s in items)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    onTap: () => context.go('/staff/students/${s['user_id']}'),
                    leading: Avatar(s['name'] as String? ?? '?'),
                    title: Text(
                      s['name'] as String? ?? 'Student',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      (s['attempts'] as num? ?? 0) == 0
                          ? 'Has not started yet'
                          : 'Last active ${timeAgo(s['last_active'])}',
                    ),
                    trailing: s['rate'] == null
                        ? const Icon(
                            Icons.hourglass_empty_rounded,
                            color: Ace.inkSoft,
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Ace.badSoft,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              '${s['rate']}%',
                              style: const TextStyle(
                                color: Ace.bad,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                  ),
              ],
            ),
    );
  }
}

class _Recent extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const _Recent({required this.items});

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Recent work',
      action: TextButton(
        onPressed: () => context.go('/staff/marking?state=all'),
        child: const Text('See all'),
      ),
      child: items.isEmpty
          ? const Text('No answers yet.', style: TextStyle(color: Ace.inkSoft))
          : Column(
              children: [
                for (final r in items)
                  InkWell(
                    onTap: () =>
                        context.go('/staff/marking/${r['attempt_id']}'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Avatar(r['name'] as String? ?? '?', radius: 16),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${r['name']} · ${r['lesson'] ?? ''}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                MathText(
                                  r['question'] as String? ?? '',
                                  style: const TextStyle(
                                    color: Ace.inkSoft,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              StatusPill(
                                status: r['status'] as String?,
                                state: r['state'] as String?,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                timeAgo(r['at']),
                                style: const TextStyle(
                                  color: Ace.inkSoft,
                                  fontSize: 12,
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

class _JoinCode extends StatelessWidget {
  final String code;

  const _JoinCode({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(colors: [Ace.navy, Ace.navySoft]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Student join code',
            style: TextStyle(
              color: Color(0xFFC9D3E6),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  code,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                  ),
                ),
              ),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: Ace.amber,
                  foregroundColor: Ace.navy,
                ),
                tooltip: 'Copy code',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Join code copied')),
                  );
                },
                icon: const Icon(Icons.copy_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Students enter this after creating their ACE account.',
            style: TextStyle(color: Color(0xFFC9D3E6), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

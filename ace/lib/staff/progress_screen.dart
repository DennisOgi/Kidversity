import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/api.dart';
import '../theme.dart';
import 'staff_ui.dart';

/// Class progress: every student against every lesson in a channel, as a
/// colour-coded grid.
class ProgressScreen extends StatefulWidget {
  final String? channel;

  const ProgressScreen({super.key, this.channel});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  String? _channel;
  Future<Map<String, dynamic>>? _grid;

  @override
  void initState() {
    super.initState();
    _channel = widget.channel;
    StaffSession.ensure().then((_) {
      if (!mounted) return;
      final channels =
          (StaffSession.info.value?['channels'] as List?) ?? const [];
      setState(() {
        _channel ??= channels.isEmpty
            ? null
            : (channels.first as Map)['id'] as String;
        if (_channel != null) _grid = AceApi.instance.classProgress(_channel!);
      });
    });
  }

  void _pick(String id) => setState(() {
    _channel = id;
    _grid = AceApi.instance.classProgress(id);
  });

  @override
  Widget build(BuildContext context) {
    final channels = [
      for (final c
          in (StaffSession.info.value?['channels'] as List? ?? const []))
        Map<String, dynamic>.from(c as Map),
    ];
    return StaffShell(
      current: '/staff/progress',
      title: 'Class progress',
      subtitle:
          'Each square is a lesson: how many questions a student tried and got right.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in channels)
                ChoiceChip(
                  label: Text('${c['stage']} ${c['subject']}'),
                  selected: c['id'] == _channel,
                  onSelected: (_) => _pick(c['id'] as String),
                  selectedColor: Ace.navy,
                  labelStyle: TextStyle(
                    color: c['id'] == _channel ? Colors.white : Ace.ink,
                    fontWeight: FontWeight.w700,
                  ),
                  showCheckmark: false,
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_grid == null)
            const Padding(
              padding: EdgeInsets.all(60),
              child: Center(child: CircularProgressIndicator(color: Ace.amber)),
            )
          else
            StaffAsync<Map<String, dynamic>>(
              key: ValueKey(_channel),
              future: _grid!,
              onRetry: () => _pick(_channel!),
              builder: (g) => _Grid(data: g),
            ),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _Legend(color: Color(0xFFEDEFF5), label: 'Not started'),
              _Legend(
                color: Color(0xFFFFE3C2),
                label: 'Tried, mostly incorrect',
              ),
              _Legend(color: Color(0xFFB9E5CB), label: 'Some correct'),
              _Legend(color: Ace.good, label: 'All tried, all correct'),
            ],
          ),
        ],
      ),
    );
  }
}

Color _cellColor(int tried, int correct, int total) {
  if (tried == 0) return const Color(0xFFEDEFF5);
  if (total > 0 && correct >= total) return Ace.good;
  if (correct * 2 >= tried) return const Color(0xFFB9E5CB);
  return const Color(0xFFFFE3C2);
}

class _Grid extends StatelessWidget {
  final Map<String, dynamic> data;

  const _Grid({required this.data});

  @override
  Widget build(BuildContext context) {
    final lessons = [
      for (final l in (data['lessons'] as List? ?? const []))
        Map<String, dynamic>.from(l as Map),
    ];
    final students = [
      for (final s in (data['students'] as List? ?? const []))
        Map<String, dynamic>.from(s as Map),
    ];
    if (students.isEmpty) {
      return const Panel(
        child: Text(
          'No students have joined yet. Share your school join code.',
          style: TextStyle(color: Ace.inkSoft),
        ),
      );
    }
    return Panel(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          headingRowHeight: 64,
          dataRowMinHeight: 60,
          dataRowMaxHeight: 64,
          columnSpacing: 18,
          headingTextStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Ace.inkSoft,
            fontSize: 12.5,
          ),
          columns: [
            const DataColumn(label: Text('Student')),
            for (final (i, l) in lessons.indexed)
              DataColumn(
                label: SizedBox(
                  width: 120,
                  child: Text(
                    '${i + 1}. ${l['title']}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            const DataColumn(label: Text('Last active')),
          ],
          rows: [
            for (final s in students)
              DataRow(
                onSelectChanged: (_) =>
                    context.go('/staff/students/${s['user_id']}'),
                cells: [
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Avatar(s['name'] as String? ?? '?', radius: 16),
                        const SizedBox(width: 10),
                        Text(
                          s['name'] as String? ?? 'Student',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  for (final l in lessons)
                    DataCell(() {
                      final cell = Map<String, dynamic>.from(
                        ((s['cells'] as Map?) ?? const {})[l['id']] as Map? ??
                            const {},
                      );
                      final tried = (cell['tried'] as num?)?.toInt() ?? 0;
                      final correct = (cell['correct'] as num?)?.toInt() ?? 0;
                      final total = (l['questions'] as num?)?.toInt() ?? 0;
                      final bg = _cellColor(tried, correct, total);
                      return Tooltip(
                        message: '$tried of $total tried, $correct correct',
                        child: Container(
                          width: 120,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            tried == 0 ? '–' : '$correct/$total',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: bg == Ace.good ? Colors.white : Ace.ink,
                            ),
                          ),
                        ),
                      );
                    }()),
                  DataCell(
                    Text(
                      timeAgo(s['last_active']),
                      style: const TextStyle(color: Ace.inkSoft),
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

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(5),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: Ace.inkSoft, fontSize: 13)),
    ],
  );
}

/// One student: headline numbers, progress by subject, and recent work.
class StudentDetailScreen extends StatefulWidget {
  final String userId;

  const StudentDetailScreen({super.key, required this.userId});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  late Future<Map<String, dynamic>> _data = AceApi.instance.studentDetail(
    widget.userId,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _data,
      builder: (context, snap) {
        final d = snap.data;
        return StaffShell(
          current: '/staff/progress',
          title: d?['name'] as String? ?? 'Student',
          subtitle: d == null ? null : 'Joined ${timeAgo(d['joined'])}',
          actions: [
            OutlinedButton.icon(
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go('/staff/progress'),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Back'),
            ),
          ],
          child: StaffAsync<Map<String, dynamic>>(
            future: _data,
            onRetry: () => setState(
              () => _data = AceApi.instance.studentDetail(widget.userId),
            ),
            builder: (d) => _StudentBody(d: d),
          ),
        );
      },
    );
  }
}

class _StudentBody extends StatelessWidget {
  final Map<String, dynamic> d;

  const _StudentBody({required this.d});

  @override
  Widget build(BuildContext context) {
    int n(String k) => (d[k] as num?)?.toInt() ?? 0;
    final rate = n('tried') == 0
        ? null
        : (n('correct') * 100 / n('tried')).round();
    final channels = [
      for (final c in (d['channels'] as List? ?? const []))
        Map<String, dynamic>.from(c as Map),
    ];
    final history = [
      for (final h in (d['history'] as List? ?? const []))
        Map<String, dynamic>.from(h as Map),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TileGrid(
          minWidth: 200,
          children: [
            Kpi(
              icon: Icons.edit_note_rounded,
              color: Ace.maths,
              label: 'Questions tried',
              value: '${n('tried')}',
              caption: '${n('attempts')} attempts',
            ),
            Kpi(
              icon: Icons.check_circle_rounded,
              color: Ace.good,
              label: 'Correct',
              value: '${n('correct')}',
              caption: rate == null
                  ? 'No answers yet'
                  : '$rate% of questions tried',
            ),
            Kpi(
              icon: Icons.rate_review_rounded,
              color: Ace.amber,
              label: 'Waiting for marking',
              value: '${n('to_mark')}',
              highlight: n('to_mark') > 0,
              onTap: n('to_mark') > 0
                  ? () => context.go('/staff/marking')
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Panel(
          title: 'Progress by subject',
          child: Column(
            children: [
              for (final c in channels)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 150,
                        child: Text(
                          '${c['stage']} ${c['subject']}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: ((c['questions'] as num?) ?? 0) == 0
                                ? 0
                                : ((c['tried'] as num?) ?? 0) /
                                      (c['questions'] as num),
                            minHeight: 10,
                            backgroundColor: const Color(0xFFEDEFF5),
                            color: Ace.subject(c['subject'] as String),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 150,
                        child: Text(
                          '${c['tried']}/${c['questions']} tried · ${c['correct']} correct',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Ace.inkSoft,
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
        const SizedBox(height: 16),
        Panel(
          title: 'Recent work',
          child: history.isEmpty
              ? const Text(
                  'No answers yet.',
                  style: TextStyle(color: Ace.inkSoft),
                )
              : Column(
                  children: [
                    for (final h in history)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        onTap: () =>
                            context.go('/staff/marking/${h['attempt_id']}'),
                        title: Text(
                          h['lesson'] as String? ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          h['question'] as String? ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (h['awarded'] != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  '${h['awarded']}/${h['max']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            StatusPill(
                              status: h['status'] as String?,
                              state: h['state'] as String?,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

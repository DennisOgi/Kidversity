import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/api.dart';
import '../theme.dart';
import '../widgets/effects.dart';
import '../widgets/math_text.dart';
import 'staff_ui.dart';

const _filters = [
  ('needs_review', 'To mark'),
  ('teacher_marked', 'Marked'),
  ('all', 'All work'),
];

/// Marking workspace: queue on the left, the selected answer on the right
/// (on phones the answer opens on its own page).
class MarkingScreen extends StatefulWidget {
  final String state;
  final String? selected;

  const MarkingScreen({super.key, this.state = 'needs_review', this.selected});

  @override
  State<MarkingScreen> createState() => _MarkingScreenState();
}

class _MarkingScreenState extends State<MarkingScreen> {
  late String _state = widget.state;
  late String? _selected = widget.selected;
  late Future<List<Map<String, dynamic>>> _queue = _load();

  Future<List<Map<String, dynamic>>> _load() =>
      AceApi.instance.reviewQueue(state: _state);

  void _reload() => setState(() => _queue = _load());

  void _marked() {
    StaffSession.refresh();
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final narrowDetail = !wide && _selected != null;
    return StaffShell(
      current: '/staff/marking',
      title: narrowDetail ? 'Mark answer' : 'Marking',
      subtitle: narrowDetail
          ? null
          : 'Award method marks against the marking guide.',
      scroll: !wide,
      actions: [
        if (narrowDetail)
          OutlinedButton.icon(
            onPressed: () => setState(() => _selected = null),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Back to queue'),
          )
        else
          Wrap(
            spacing: 8,
            children: [
              for (final f in _filters)
                ChoiceChip(
                  label: Text(f.$2),
                  selected: _state == f.$1,
                  showCheckmark: false,
                  selectedColor: Ace.navy,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _state == f.$1 ? Colors.white : Ace.ink,
                  ),
                  onSelected: (_) => setState(() {
                    _state = f.$1;
                    _selected = null;
                    _queue = _load();
                  }),
                ),
            ],
          ),
      ],
      child: narrowDetail
          ? AttemptMarker(
              key: ValueKey(_selected),
              attemptId: _selected!,
              onMarked: () {
                _marked();
                setState(() => _selected = null);
              },
            )
          : StaffAsync<List<Map<String, dynamic>>>(
              future: _queue,
              onRetry: _reload,
              builder: (items) {
                final list = _QueueList(
                  items: items,
                  selected: _selected,
                  state: _state,
                  onSelect: (id) => setState(() => _selected = id),
                );
                if (!wide) return list;
                final current =
                    _selected ??
                    (items.isEmpty
                        ? null
                        : items.first['attempt_id'] as String);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 400,
                      child: SingleChildScrollView(child: list),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: current == null
                          ? const Panel(
                              child: Center(
                                child: Padding(
                                  padding: EdgeInsets.all(40),
                                  child: Text(
                                    'Nothing here. Pick another filter.',
                                    style: TextStyle(color: Ace.inkSoft),
                                  ),
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              child: AttemptMarker(
                                key: ValueKey(current),
                                attemptId: current,
                                onMarked: _marked,
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _QueueList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String? selected;
  final String state;
  final ValueChanged<String> onSelect;

  const _QueueList({
    required this.items,
    required this.selected,
    required this.state,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Panel(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Ace.goodSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.task_alt_rounded,
                color: Ace.good,
                size: 34,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              state == 'needs_review' ? 'All caught up' : 'No work yet',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            const SizedBox(height: 4),
            Text(
              state == 'needs_review'
                  ? 'New written answers appear here as students submit them.'
                  : 'Student answers appear here once they start practising.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Ace.inkSoft),
            ),
            const SizedBox(height: 12),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final (i, a) in items.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Reveal(
              delay: Duration(milliseconds: (i * 30).clamp(0, 300)),
              child: _QueueTile(
                item: a,
                selected: a['attempt_id'] == selected,
                onTap: () => onSelect(a['attempt_id'] as String),
              ),
            ),
          ),
      ],
    );
  }
}

class _QueueTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool selected;
  final VoidCallback onTap;

  const _QueueTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final subject = item['subject'] as String? ?? 'Mathematics';
    return Material(
      color: selected ? Ace.navy : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? Ace.navy : const Color(0xFFE4E8F1),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Avatar(item['name'] as String? ?? '?'),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item['name'] as String? ?? 'Student',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: selected ? Colors.white : Ace.ink,
                            ),
                          ),
                        ),
                        Text(
                          timeAgo(item['at']),
                          style: TextStyle(
                            fontSize: 12,
                            color: selected
                                ? const Color(0xFFC9D3E6)
                                : Ace.inkSoft,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item['stage']} $subject · ${item['lesson'] ?? ''}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: selected ? Ace.amber : Ace.subject(subject),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    MathText(
                      item['question'] as String? ?? '',
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: selected ? Colors.white : Ace.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        StatusPill(
                          status: item['status'] as String?,
                          state: item['state'] as String?,
                        ),
                        const SizedBox(width: 8),
                        if (item['awarded'] != null)
                          Text(
                            '${_fmt(item['awarded'])}/${item['max_marks']}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: selected ? Colors.white : Ace.ink,
                            ),
                          ),
                        const Spacer(),
                        Text(
                          'Attempt ${item['attempt_no']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: selected
                                ? const Color(0xFFC9D3E6)
                                : Ace.inkSoft,
                          ),
                        ),
                      ],
                    ),
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

String _fmt(Object? n) {
  final v = n is num ? n : num.tryParse('$n') ?? 0;
  return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

/// One answer with its marking guide, and the controls to award marks.
class AttemptMarker extends StatefulWidget {
  final String attemptId;
  final VoidCallback onMarked;

  const AttemptMarker({
    super.key,
    required this.attemptId,
    required this.onMarked,
  });

  @override
  State<AttemptMarker> createState() => _AttemptMarkerState();
}

class _AttemptMarkerState extends State<AttemptMarker> {
  late Future<Map<String, dynamic>> _detail = AceApi.instance.attemptDetail(
    widget.attemptId,
  );
  final _comment = TextEditingController();
  List<int> _criteria = [];
  num? _total;
  bool _saving = false;
  bool _seeded = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save(Map<String, dynamic> d, int max, List rubric) async {
    final total = _total ?? _criteria.fold<int>(0, (s, v) => s + v);
    setState(() => _saving = true);
    try {
      await AceApi.instance.markAttempt(
        attemptId: widget.attemptId,
        marks: total,
        criteria: [
          for (var i = 0; i < rubric.length; i++)
            {
              'criterion': i,
              'text': (rubric[i] as Map)['criterion'],
              'marks': i < _criteria.length ? _criteria[i] : 0,
            },
        ],
        comment: _comment.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Ace.good,
          content: Text('Saved ${_fmt(total)}/$max for ${d['name']}'),
        ),
      );
      widget.onMarked();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AceApi.message(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StaffAsync<Map<String, dynamic>>(
      future: _detail,
      onRetry: () => setState(
        () => _detail = AceApi.instance.attemptDetail(widget.attemptId),
      ),
      builder: (d) {
        final q = Map<String, dynamic>.from(d['question'] as Map);
        final key = Map<String, dynamic>.from(d['key'] as Map? ?? const {});
        final rubric = (key['rubric'] as List?) ?? const [];
        final max = (q['max_marks'] as num?)?.toInt() ?? 0;
        final resp = Map<String, dynamic>.from(
          d['response'] as Map? ?? const {},
        );
        final reviews = (d['reviews'] as List?) ?? const [];
        if (!_seeded) {
          _seeded = true;
          final last = reviews.isEmpty
              ? null
              : Map<String, dynamic>.from(reviews.first as Map);
          final prev = (last?['criteria'] as List?) ?? const [];
          _criteria = [
            for (var i = 0; i < rubric.length; i++)
              i < prev.length
                  ? ((prev[i] as Map)['marks'] as num? ?? 0).toInt()
                  : 0,
          ];
          if (rubric.isEmpty && last != null) _total = last['marks'] as num?;
          _comment.text = last?['comment'] as String? ?? '';
        }
        final total = rubric.isEmpty
            ? (_total ?? 0)
            : _criteria.fold<int>(0, (s, v) => s + v);
        final working = (resp['working_text'] as String? ?? '').trim();
        final subject = q['subject'] as String? ?? 'Mathematics';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Avatar(d['name'] as String? ?? '?', radius: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () =>
                                  context.go('/staff/students/${d['user_id']}'),
                              child: Text(
                                d['name'] as String? ?? 'Student',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              '${q['stage']} $subject · ${q['lesson'] ?? ''} · attempt ${d['attempt_no']} · ${timeAgo(d['at'])}',
                              style: const TextStyle(
                                color: Ace.inkSoft,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusPill(
                        status: d['status'] as String?,
                        state: d['state'] as String?,
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  const _Label('Question'),
                  MathText(
                    q['prompt'] as String? ?? '',
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.55,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, box) {
                final two = box.maxWidth >= 760;
                final student = Panel(
                  title: "Student's answer",
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (working.isNotEmpty) ...[
                        const _Label('Working'),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Ace.paper,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final line in working.split('\n'))
                                if (line.trim().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: line.contains(r'$')
                                        ? MathText(
                                            line,
                                            style: const TextStyle(
                                              fontSize: 15.5,
                                            ),
                                          )
                                        : MathBlock(
                                            line,
                                            style: const TextStyle(
                                              fontSize: 16.5,
                                            ),
                                          ),
                                  ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ] else
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            'No working was written.',
                            style: TextStyle(
                              color: Ace.inkSoft,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      if (resp['final_answer'] != null) ...[
                        const _Label('Final answer'),
                        Row(
                          children: [
                            Text(
                              '${resp['final_answer']}${resp['unit'] == null ? '' : ' ${resp['unit']}'}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 10),
                            StatusPill(status: d['status'] as String?),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
                final reference = Panel(
                  title: 'Approved answer',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (key['answer'] != null)
                        MathText(
                          '${key['answer']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      const SizedBox(height: 10),
                      for (final (i, s)
                          in ((key['worked_solution'] as List?) ?? const [])
                              .indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${i + 1}.  ',
                                style: TextStyle(
                                  color: Ace.subject(subject),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Expanded(
                                child: MathText(
                                  '$s',
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
                if (!two) {
                  return Column(
                    children: [student, const SizedBox(height: 14), reference],
                  );
                }
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: student),
                      const SizedBox(width: 14),
                      Expanded(child: reference),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            Panel(
              title: 'Award marks',
              subtitle:
                  'A correct final answer alone does not earn method marks.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (rubric.isEmpty)
                    Row(
                      children: [
                        const Expanded(child: Text('Total marks')),
                        _Stepper(
                          value: (_total ?? 0).toInt(),
                          max: max,
                          onChanged: (v) => setState(() => _total = v),
                        ),
                      ],
                    )
                  else
                    for (var i = 0; i < rubric.length; i++)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _criteria[i] > 0 ? Ace.goodSoft : Ace.paper,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: MathText(
                                '${(rubric[i] as Map)['criterion']}',
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _Stepper(
                              value: _criteria[i],
                              max:
                                  ((rubric[i] as Map)['marks'] as num?)
                                      ?.toInt() ??
                                  1,
                              onChanged: (v) =>
                                  setState(() => _criteria[i] = v),
                            ),
                          ],
                        ),
                      ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _comment,
                    minLines: 2,
                    maxLines: 5,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      labelText: 'Comment for the student (optional)',
                      hintText: 'What went well, and what to fix next time.',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        'Total  ',
                        style: const TextStyle(color: Ace.inkSoft),
                      ),
                      Text(
                        '${_fmt(total)} / $max',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Ace.navy,
                        ),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _saving ? null : () => _save(d, max, rubric),
                        style: FilledButton.styleFrom(
                          backgroundColor: Ace.good,
                        ),
                        icon: const Icon(Icons.check_rounded),
                        label: Text(
                          _saving
                              ? 'Saving…'
                              : (reviews.isEmpty
                                    ? 'Save marks'
                                    : 'Update marks'),
                        ),
                      ),
                    ],
                  ),
                  if (reviews.isNotEmpty) ...[
                    const Divider(height: 30),
                    const _Label('Marking history'),
                    for (final r in reviews)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '${_fmt((r as Map)['marks'])}/$max by ${r['by'] ?? 'a teacher'} · ${timeAgo(r['at'])}'
                          '${(r['comment'] as String?)?.isNotEmpty == true ? ' — "${r['comment']}"' : ''}',
                          style: const TextStyle(
                            color: Ace.inkSoft,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11.5,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w800,
        color: Ace.inkSoft,
      ),
    ),
  );
}

class _Stepper extends StatelessWidget {
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  const _Stepper({
    required this.value,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E8F1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value > 0 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_rounded, size: 18),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '$value/$max',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

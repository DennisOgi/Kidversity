import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/api.dart';
import '../theme.dart';
import '../widgets/effects.dart';
import '../widgets/math_text.dart';
import '../widgets/page.dart';

/// A lesson: explanation, worked example, common errors, then its questions.
/// Each question takes a final answer (with unit) and/or written working,
/// is checked on the server, and shows the worked solution afterwards.
class LessonScreen extends StatefulWidget {
  final String lessonId;

  const LessonScreen({super.key, required this.lessonId});

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  late Future<Map<String, dynamic>> _lesson = AceApi.instance.lesson(
    widget.lessonId,
  );

  Map<String, dynamic> _reviews = const {};

  @override
  void initState() {
    super.initState();
    // Teacher marks and comments; the lesson still works without them.
    AceApi.instance
        .myReviews(widget.lessonId)
        .then((r) {
          if (mounted) setState(() => _reviews = r);
        })
        .catchError((_) {});
  }

  void _reload() =>
      setState(() => _lesson = AceApi.instance.lesson(widget.lessonId));

  @override
  Widget build(BuildContext context) {
    return AceAsync<Map<String, dynamic>>(
      future: _lesson,
      onRetry: _reload,
      message: AceApi.message,
      builder: (l) {
        final example = l['worked_example'] as Map?;
        final topic = l['topic'] as Map?;
        final questions = [
          for (final q in (l['questions'] as List? ?? const []))
            Map<String, dynamic>.from(q as Map),
        ];
        final subject = (l['channel_id'] as String).contains('physics')
            ? 'Physics'
            : 'Mathematics';
        final color = Ace.subject(subject);
        const body = TextStyle(fontSize: 16.5, height: 1.65, color: Ace.ink);
        final qCount = questions.length;
        final tried = questions
            .where((q) => ((q['attempts'] as num?) ?? 0) > 0)
            .length;
        return AcePage(
          backTo: '/c/${l['channel_id']}',
          header: HeroBand(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: () => goBack(context, '/c/${l['channel_id']}'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFC9D3E6),
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: Text('${l['stage']} $subject'),
                ),
                const SizedBox(height: 10),
                if (topic != null)
                  Text(
                    'SYLLABUS ${topic['ref']} · ${topic['title']}'
                        .toUpperCase(),
                    style: const TextStyle(
                      color: Ace.amber,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      fontSize: 12.5,
                    ),
                  ),
                const SizedBox(height: 8),
                Reveal(
                  child: Text(
                    l['title'] as String,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontSize: MediaQuery.sizeOf(context).width < 600
                          ? 28
                          : 38,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (l['minutes'] != null)
                      _HeroPill(Icons.schedule_rounded, '${l['minutes']} min'),
                    _HeroPill(Icons.quiz_rounded, '$qCount practice questions'),
                    _HeroPill(Icons.edit_note_rounded, '$tried tried'),
                  ],
                ),
              ],
            ),
          ),
          children: [
            if ((l['objectives'] as List?)?.isNotEmpty ?? false)
              _Section(
                title: 'By the end you can',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final o in l['objectives'] as List)
                      _Bullet(text: o as String, color: color),
                  ],
                ),
              ),
            AceCard(
              child: MathText(
                l['explanation_markdown'] as String? ?? '',
                style: body,
              ),
            ),
            if (example != null)
              _Section(
                title: 'Worked example',
                tint: Ace.subjectSoft(subject),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MathText(
                      example['prompt'] as String? ?? '',
                      style: body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    for (final (i, s)
                        in ((example['steps'] as List?) ?? const []).indexed)
                      _Step(index: i + 1, text: s as String, color: color),
                    if (example['answer'] != null) ...[
                      const SizedBox(height: 6),
                      MathText(
                        'Answer: ${example['answer']}',
                        style: body.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ],
                ),
              ),
            if ((l['common_errors'] as List?)?.isNotEmpty ?? false)
              _Section(
                title: 'Watch out for',
                tint: Ace.warnSoft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in l['common_errors'] as List)
                      _Bullet(text: e as String, color: Ace.warn),
                  ],
                ),
              ),
            Text(
              'Practice questions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Write your working as you would in the exam. Final answers are checked '
              'straight away; your teacher marks your method.',
              style: TextStyle(color: Ace.inkSoft),
            ),
            for (final (i, q) in questions.indexed)
              QuestionCard(
                key: ValueKey(q['id']),
                number: i + 1,
                question: q,
                color: color,
                review: _reviews[q['id']] == null
                    ? null
                    : Map<String, dynamic>.from(_reviews[q['id']] as Map),
              ),
            if (l['exit_check'] != null)
              _Section(
                title: 'Before you move on',
                child: MathText(l['exit_check'] as String, style: body),
              ),
          ],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Color? tint;

  const _Section({required this.title, required this.child, this.tint});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: tint ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Ace.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  final Color color;

  const _Bullet({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 9, right: 10),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          Expanded(
            child: MathText(
              text,
              style: const TextStyle(fontSize: 15.5, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int index;
  final String text;
  final Color color;

  const _Step({required this.index, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(right: 10, top: 1),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Text(
              '$index',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: MathText(
              text,
              style: const TextStyle(fontSize: 15.5, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// One question with its answer form and, after submitting, the feedback.
class QuestionCard extends StatefulWidget {
  final int number;
  final Map<String, dynamic> question;
  final Color color;

  /// The latest teacher review of this learner's work, if any.
  final Map<String, dynamic>? review;

  const QuestionCard({
    super.key,
    required this.number,
    required this.question,
    required this.color,
    this.review,
  });

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  final _answer = TextEditingController();
  final _unit = TextEditingController();
  final _working = TextEditingController();
  bool _busy = false;
  bool _preview = false;
  String? _error;
  Map<String, dynamic>? _result;
  late int _attempts = (widget.question['attempts'] as num?)?.toInt() ?? 0;

  bool get _numeric => widget.question['kind'] == 'numeric';

  @override
  void initState() {
    super.initState();
    _unit.text = widget.question['answer_unit'] as String? ?? '';
  }

  @override
  void dispose() {
    _answer.dispose();
    _unit.dispose();
    _working.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    num? value;
    if (_numeric && _answer.text.trim().isNotEmpty) {
      value = num.tryParse(_answer.text.trim().replaceAll(',', ''));
      if (value == null) {
        setState(
          () => _error =
              'Type your final answer as a number, e.g. 6.32e3 or -31.',
        );
        return;
      }
    }
    if (value == null && _working.text.trim().isEmpty) {
      setState(
        () => _error = _numeric
            ? 'Give a final answer, your working, or both.'
            : 'Write your working and answer.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await AceApi.instance.submit(
        questionId: widget.question['id'] as String,
        finalAnswer: value,
        unit: _numeric ? _unit.text : null,
        working: _working.text,
      );
      setState(() {
        _result = r;
        _attempts = (r['attempt_no'] as num?)?.toInt() ?? _attempts + 1;
      });
    } catch (e) {
      setState(() => _error = AceApi.message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _retry() => setState(() {
    _result = null;
    _answer.clear();
    _working.clear();
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final marks = q['max_marks'];
    return AceCard(
      accent: widget.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Question ${widget.number}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: widget.color,
                ),
              ),
              const Spacer(),
              if (_attempts > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '$_attempts attempt${_attempts == 1 ? '' : 's'}',
                    style: const TextStyle(color: Ace.inkSoft, fontSize: 13),
                  ),
                ),
              AceChip('[$marks]', color: Ace.inkSoft, background: Ace.line),
            ],
          ),
          const SizedBox(height: 10),
          MathText(
            q['prompt_markdown'] as String,
            style: const TextStyle(
              fontSize: 17,
              height: 1.55,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          if (widget.review != null) ...[
            _TeacherReview(review: widget.review!),
            const SizedBox(height: 16),
          ],
          if (_result == null)
            ..._form()
          else
            Reveal(
              key: ValueKey(_result!['attempt_id']),
              child: _Feedback(
                result: _result!,
                onRetry: _retry,
                color: widget.color,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _form() => [
    Row(
      children: [
        const Expanded(
          child: Text('Working', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        TextButton.icon(
          onPressed: () => setState(() => _preview = !_preview),
          icon: Icon(
            _preview ? Icons.edit_rounded : Icons.visibility_rounded,
            size: 18,
          ),
          label: Text(_preview ? 'Edit' : 'Preview maths'),
        ),
      ],
    ),
    if (_preview)
      Container(
        constraints: const BoxConstraints(minHeight: 96),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: Ace.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in _working.text.split('\n'))
              if (line.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: line.contains(r'$')
                      ? MathText(line, style: const TextStyle(fontSize: 16))
                      : MathBlock(line, style: const TextStyle(fontSize: 17)),
                ),
          ],
        ),
      )
    else
      TextField(
        controller: _working,
        minLines: 4,
        maxLines: 12,
        maxLength: 4000,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 15),
        decoration: const InputDecoration(
          hintText:
              'One step per line. Maths like x^2 - 9x + 20 = 0 or \\frac{dy}{dx} = 6x^2 - 6x',
          alignLabelWithHint: true,
        ),
      ),
    if (_numeric) ...[
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _answer,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9eE.+\-,]')),
              ],
              decoration: const InputDecoration(labelText: 'Final answer'),
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _unit,
              decoration: const InputDecoration(
                labelText: 'Unit',
                hintText: 'none',
              ),
            ),
          ),
        ],
      ),
    ],
    if (_error != null) ...[
      const SizedBox(height: 10),
      Text(_error!, style: const TextStyle(color: Ace.bad)),
    ],
    const SizedBox(height: 14),
    Align(
      alignment: Alignment.centerRight,
      child: FilledButton(
        onPressed: _busy ? null : _submit,
        child: Text(_busy ? 'Checking…' : 'Submit'),
      ),
    ),
  ];
}

class _Feedback extends StatelessWidget {
  final Map<String, dynamic> result;
  final VoidCallback onRetry;
  final Color color;

  const _Feedback({
    required this.result,
    required this.onRetry,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final status = result['final_answer_status'] as String;
    final review = result['marking_state'] == 'needs_review';
    final fb = Map<String, dynamic>.from(
      result['feedback'] as Map? ?? const {},
    );
    final (label, fg, bg, icon) = switch (status) {
      'final_answer_match' || 'option_match' => (
        'Your final answer matches.',
        Ace.good,
        Ace.goodSoft,
        Icons.check_circle_rounded,
      ),
      'unit_mismatch' => (
        'Check your unit: the number may be right, but the unit does not match.',
        Ace.warn,
        Ace.warnSoft,
        Icons.straighten_rounded,
      ),
      'invalid_numeric_input' => (
        'Your final answer was not read as a number.',
        Ace.warn,
        Ace.warnSoft,
        Icons.help_rounded,
      ),
      'try_again' || 'option_wrong' => (
        'Not quite. Compare your working with the solution below.',
        Ace.bad,
        Ace.badSoft,
        Icons.cancel_rounded,
      ),
      _ => (
        'Sent to your teacher to mark.',
        Ace.navy,
        Ace.amberSoft,
        Icons.rate_review_rounded,
      ),
    };
    final steps = (fb['worked_solution'] as List?) ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: fg),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: fg, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          review
              ? 'Your working has gone to your teacher, who awards the method marks.'
              : 'Method marks come from your teacher; a matching final answer alone does not earn full marks.',
          style: const TextStyle(color: Ace.inkSoft, fontSize: 13.5),
        ),
        const SizedBox(height: 14),
        if (fb['correct_answer'] != null)
          MathText(
            'Answer: ${fb['correct_answer']}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        if (steps.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Worked solution',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (final (i, s) in steps.indexed)
            _Step(index: i + 1, text: '$s', color: color),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.replay_rounded, size: 18),
            label: const Text('Try again'),
          ),
        ),
      ],
    );
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HeroPill(this.icon, this.text);

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

/// A teacher's marks and comment on this question.
class _TeacherReview extends StatelessWidget {
  final Map<String, dynamic> review;

  const _TeacherReview({required this.review});

  String _fmt(Object? n) {
    final v = n is num ? n : num.tryParse('$n') ?? 0;
    return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final comment = (review['comment'] as String?)?.trim() ?? '';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Ace.amberSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Ace.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Ace.navy,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_fmt(review['awarded'])}/${review['max']}',
              style: const TextStyle(
                color: Ace.amber,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Marked by ${review['by'] ?? 'your teacher'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Ace.ink,
                  ),
                ),
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '"$comment"',
                    style: const TextStyle(color: Ace.ink, height: 1.45),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

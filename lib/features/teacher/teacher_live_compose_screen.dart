import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/live_test_models.dart';
import '../../router/navigation.dart';
import '../../services/live_test_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/surfaces.dart';

/// Teacher writes a live quiz of any length, then watches answers arrive.
class TeacherLiveComposeScreen extends StatefulWidget {
  const TeacherLiveComposeScreen({super.key});

  @override
  State<TeacherLiveComposeScreen> createState() =>
      _TeacherLiveComposeScreenState();
}

class _TeacherLiveComposeScreenState extends State<TeacherLiveComposeScreen> {
  final _title = TextEditingController();
  final _subject = TextEditingController(text: 'General');
  final List<_DraftQuestion> _questions = [_DraftQuestion()];
  int _minutes = 10;
  bool _busy = false;
  String? _problem;

  @override
  void dispose() {
    _title.dispose();
    _subject.dispose();
    for (final question in _questions) {
      question.dispose();
    }
    super.dispose();
  }

  void _addQuestion() {
    setState(() {
      _questions.add(_DraftQuestion());
      _problem = null;
    });
  }

  void _removeQuestion(int index) {
    if (_questions.length == 1) return;
    final removed = _questions.removeAt(index);
    setState(() => _problem = null);
    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
  }

  String? _validate() {
    if (_title.text.trim().isEmpty) return 'Give the quiz a title.';
    if (_questions.isEmpty) return 'Add at least one question.';
    for (var i = 0; i < _questions.length; i++) {
      final question = _questions[i];
      final number = i + 1;
      if (question.prompt.text.trim().isEmpty) {
        return 'Question $number needs a prompt.';
      }
      final filled = question.options
          .where((option) => option.label.text.trim().isNotEmpty)
          .toList();
      if (filled.length < 2) {
        return 'Question $number needs at least two choices.';
      }
      final correct = filled.where((option) => option.correct).length;
      if (correct != 1) {
        return 'Mark one correct choice on question $number.';
      }
    }
    return null;
  }

  Future<void> _goLive() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      final questions = [
        for (final question in _questions)
          (
            prompt: question.prompt.text.trim(),
            options: [
              for (final entry
                  in question.options
                      .where((option) => option.label.text.trim().isNotEmpty)
                      .indexed)
                LiveTestOption(
                  id: 'o${entry.$1}',
                  label: entry.$2.label.text.trim(),
                  isCorrect: entry.$2.correct,
                ),
            ],
          ),
      ];
      final subject = _subject.text.trim().isEmpty
          ? 'General'
          : _subject.text.trim();
      final created = await LiveTestService.instance.createTest(
        title: _title.text.trim(),
        subject: subject,
        durationSeconds: _minutes * 60,
        questions: questions,
      );
      if (!mounted) return;
      if (created.isFailure || created.data == null) {
        setState(() => _problem = created.error ?? 'Could not create the quiz.');
        return;
      }
      final started = await LiveTestService.instance.startTest(created.data!.id);
      if (!mounted) return;
      if (started.isFailure || started.data == null) {
        setState(() => _problem = started.error ?? 'Could not start the quiz.');
        return;
      }
      context.go('/teacher/live/${started.data!.id}/monitor');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final count = _questions.length;
    return ShellScrollView(
      children: [
        IconButton(
          tooltip: 'Live quizzes',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _busy
              ? null
              : () => popOrGo(context, AppRoutes.teacherLive),
        ),
        const PageIntro(
          eyebrow: 'Live quiz',
          title: 'Write the questions',
          body:
              'Add as many as the lesson needs. Each one needs a prompt, at least two choices, and one marked correct. Students in your class get a banner, and you watch every option fill in.',
        ),
        const SizedBox(height: 20),
        LiftCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Quiz title',
                  hintText: 'Friday check — photosynthesis',
                  filled: true,
                  fillColor: AppColors.surface,
                ),
                onChanged: (_) => setState(() => _problem = null),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _subject,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  filled: true,
                  fillColor: AppColors.surface,
                ),
                onChanged: (_) => setState(() => _problem = null),
              ),
              const SizedBox(height: 16),
              Text(
                '$_minutes minute${_minutes == 1 ? '' : 's'}',
                style: text.titleMedium,
              ),
              Text(
                'The clock starts when you go live. Longer quizzes can use more time.',
                style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
              ),
              Slider(
                value: _minutes.toDouble(),
                min: 1,
                max: 90,
                divisions: 89,
                label: '$_minutes min',
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _minutes = value.round()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: Text(
                count == 1 ? '1 question' : '$count questions',
                style: text.titleLarge,
              ),
            ),
            TextButton.icon(
              onPressed: _busy ? null : _addQuestion,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add question'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _questions.length; i++) ...[
          _QuestionEditor(
            key: ValueKey(_questions[i].id),
            number: i + 1,
            question: _questions[i],
            canRemove: _questions.length > 1 && !_busy,
            onChanged: () => setState(() => _problem = null),
            onRemove: () => _removeQuestion(i),
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          onPressed: _busy ? null : _addQuestion,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add another question'),
        ),
        const SizedBox(height: 18),
        if (_problem != null) ...[
          Text(
            _problem!,
            style: text.bodyMedium?.copyWith(color: AppColors.danger),
          ),
          const SizedBox(height: 12),
        ],
        GradientButton(
          expand: true,
          label: _busy ? 'Starting…' : 'Go live',
          icon: Icons.sensors_rounded,
          onTap: _busy ? null : _goLive,
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

class _QuestionEditor extends StatelessWidget {
  final int number;
  final _DraftQuestion question;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _QuestionEditor({
    super.key,
    required this.number,
    required this.question,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return LiftCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$number',
                  style: text.titleSmall?.copyWith(color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('Question $number', style: text.titleMedium)),
              if (canRemove)
                IconButton(
                  tooltip: 'Remove question',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: question.prompt,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Prompt',
              hintText: 'What do you want the class to answer?',
              filled: true,
              fillColor: AppColors.surface,
              alignLabelWithHint: true,
            ),
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 12),
          Text(
            'Tap the circle beside the correct choice.',
            style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < question.options.length; i++)
            _OptionRow(
              option: question.options[i],
              canRemove: question.options.length > 2,
              onChanged: onChanged,
              onMark: () {
                for (final option in question.options) {
                  option.correct = false;
                }
                question.options[i].correct = true;
                onChanged();
              },
              onRemove: () {
                final removed = question.options.removeAt(i);
                if (!question.options.any((option) => option.correct)) {
                  question.options.first.correct = true;
                }
                onChanged();
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => removed.dispose(),
                );
              },
            ),
          if (question.options.length < 6)
            TextButton.icon(
              onPressed: () {
                question.options.add(_DraftOption());
                onChanged();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add a choice'),
            ),
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final _DraftOption option;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onMark;
  final VoidCallback onRemove;

  const _OptionRow({
    required this.option,
    required this.canRemove,
    required this.onChanged,
    required this.onMark,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            tooltip: option.correct ? 'Correct choice' : 'Mark as correct',
            onPressed: onMark,
            icon: Icon(
              option.correct
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: option.correct ? AppColors.success : AppColors.muted,
            ),
          ),
          Expanded(
            child: TextField(
              controller: option.label,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Choice',
                filled: true,
                fillColor: option.correct
                    ? AppColors.successSoft
                    : AppColors.surface,
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
          if (canRemove)
            IconButton(
              tooltip: 'Remove choice',
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
    );
  }
}

class _DraftOption {
  _DraftOption({this.correct = false});

  final TextEditingController label = TextEditingController();
  bool correct;

  void dispose() => label.dispose();
}

class _DraftQuestion {
  _DraftQuestion() {
    options.first.correct = true;
  }

  static int _nextId = 0;
  final int id = _nextId++;

  final TextEditingController prompt = TextEditingController();
  final List<_DraftOption> options = [
    _DraftOption(correct: true),
    _DraftOption(),
    _DraftOption(),
  ];

  void dispose() {
    prompt.dispose();
    for (final option in options) {
      option.dispose();
    }
  }
}

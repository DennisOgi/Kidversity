import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/records_providers.dart';
import '../../models/past_questions_models.dart';
import 'exam_topics.dart';
import '../../router/navigation.dart';
import '../../services/learning_records_service.dart';
import '../../services/sdash_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/error_boundary.dart';

class PastQuestionsSessionScreen extends ConsumerStatefulWidget {
  final PastQuestionsSessionConfig config;

  const PastQuestionsSessionScreen({super.key, required this.config});

  @override
  ConsumerState<PastQuestionsSessionScreen> createState() =>
      _PastQuestionsSessionScreenState();
}

class _PastQuestionsSessionScreenState
    extends ConsumerState<PastQuestionsSessionScreen> {
  bool _loading = true;
  String? _error;
  List<PastQuestion> _questions = const [];
  int _index = 0;
  String? _selected;
  bool _revealed = false;
  int _correct = 0;
  final Map<int, String?> _answers = {};
  bool _finished = false;
  bool _reporting = false;
  final _clock = Stopwatch();
  Timer? _ticker;
  _SaveState _save = _SaveState.idle;

  bool get _mock => widget.config.isMock;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final preset = widget.config.preset;
    List<PastQuestion> questions;
    if (preset != null) {
      questions = [...preset]..shuffle();
    } else {
      final topicId = widget.config.topicId;
      final result = await SdashApiService.instance.fetchQuestions(
        examSlug: widget.config.exam.slug,
        subjectSlug: widget.config.subject.slug,
        limit: topicId == null ? widget.config.mode.limit : 50,
        year: widget.config.year,
        university: widget.config.university,
      );
      if (!mounted) return;
      if (result.isFailure) {
        setState(() {
          _loading = false;
          _error = result.error;
        });
        return;
      }
      questions = result.data!;
      if (topicId != null) {
        final topic = examTopicById(widget.config.subject.slug, topicId);
        questions = topic == null
            ? const []
            : questionsForTopic(widget.config.subject.slug, topic, questions);
        if (questions.length < examTopicMinimum) {
          setState(() {
            _loading = false;
            _error =
                'This topic does not have enough checked questions in that paper yet.';
          });
          return;
        }
      }
    }
    setState(() {
      _loading = false;
      _questions = questions;
      _index = 0;
      _selected = null;
      _revealed = false;
      _correct = 0;
      _answers.clear();
      _finished = false;
      _save = _SaveState.idle;
    });
    _clock
      ..reset()
      ..start();
    _ticker?.cancel();
    if (_mock && questions.isNotEmpty) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _finished) return;
        if (_remaining <= Duration.zero) {
          unawaited(_finish());
          return;
        }
        setState(() {});
      });
    }
  }

  Duration get _remaining {
    final limit = widget.config.mode.timeLimit ?? Duration.zero;
    final left = limit - _clock.elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  PastQuestion get _current => _questions[_index];

  void _pick(String key) {
    if (_mock) {
      setState(() {
        _selected = key;
        _answers[_current.id] = key;
      });
      return;
    }
    if (_revealed) return;
    setState(() {
      _selected = key;
      _revealed = true;
      _answers[_current.id] = key;
      if (_current.isCorrect(key)) _correct++;
    });
  }

  void _goTo(int index) {
    setState(() {
      _index = index;
      _selected = _answers[_questions[_index].id];
      _revealed = !_mock && _selected != null;
    });
  }

  void _next() {
    if (_index + 1 >= _questions.length) {
      _finish();
      return;
    }
    _goTo(_index + 1);
  }

  Future<void> _confirmSubmit() async {
    final unanswered = _questions.where((q) => _answers[q.id] == null).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Submit the paper?'),
        content: Text(
          unanswered == 0
              ? 'Every question has an answer.'
              : '$unanswered unanswered. They count as wrong.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (ok == true) await _finish();
  }

  Future<void> _finish() async {
    if (_finished) return;
    _clock.stop();
    _ticker?.cancel();
    setState(() {
      _finished = true;
      _correct = _questions.where((q) => q.isCorrect(_answers[q.id])).length;
      _save = _SaveState.saving;
    });
    final result = await LearningRecordsService.instance.recordExamAttempt(
      config: widget.config,
      questions: _questions,
      answers: _answers,
      elapsed: _clock.elapsed,
    );
    if (!mounted) return;
    setState(
      () => _save = result.isSuccess ? _SaveState.saved : _SaveState.failed,
    );
    final topicId = widget.config.topicId;
    if (topicId != null && topicCleared(_correct, _questions.length)) {
      await ExamTopicProgress.mark(
        ExamTopicProgress.idFor(
          examSlug: widget.config.exam.slug,
          subjectSlug: widget.config.subject.slug,
          topicId: topicId,
        ),
      );
    }
    ref
      ..invalidate(myExamAttemptsProvider)
      ..invalidate(myMistakeGroupsProvider)
      ..invalidate(myAssignmentsProvider);
  }

  Future<void> _report() async {
    setState(() => _reporting = true);
    final result = await SdashApiService.instance.reportQuestion(
      questionId: _current.id,
      message: 'Flagged from Kidversity practice session',
    );
    if (!mounted) return;
    setState(() => _reporting = false);
    if (result.isFailure) {
      context.showErrorSnackbar(result.error ?? 'Could not send report.');
      return;
    }
    context.showSuccessSnackbar('Thanks — report sent.');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Exam practice',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => popOrGo(context, AppRoutes.studentExams),
        ),
        title: Text(widget.config.headline),
        actions: [
          if (!_loading && !_finished && _questions.isNotEmpty)
            TextButton(
              onPressed: _reporting ? null : _report,
              child: Text(_reporting ? '…' : 'Report'),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: LoadingIndicator(message: 'Fetching past questions…'),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ErrorDisplay(message: _error!, onRetry: _load),
              ),
            )
          : _questions.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No questions came back for this paper. Try another year.',
                ),
              ),
            )
          : _finished
          ? _ResultsView(
              config: widget.config,
              questions: _questions,
              answers: _answers,
              correct: _correct,
              elapsed: _clock.elapsed,
              save: _save,
              onRetry: () {
                setState(() => _finished = false);
                _load();
              },
              onDone: () => popOrGo(context, AppRoutes.studentExams),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Q ${_index + 1} of ${_questions.length}',
                        style: text.titleMedium,
                      ),
                      const Spacer(),
                      if (_mock)
                        _Countdown(remaining: _remaining)
                      else
                        Text(
                          '$_correct correct',
                          style: text.bodyMedium?.copyWith(
                            color: AppColors.jade,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                  if (_mock) ...[
                    const SizedBox(height: 10),
                    _Palette(
                      questions: _questions,
                      answers: _answers,
                      current: _index,
                      onTap: _goTo,
                    ),
                  ],
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (_index + 1) / _questions.length,
                      minHeight: 8,
                      backgroundColor: AppColors.line,
                      color: AppColors.cinnabar,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView(
                      children: [
                        if (_current.section != null &&
                            _current.section!.trim().isNotEmpty) ...[
                          GlassCard(
                            color: AppColors.backgroundAlt,
                            child: Text(
                              _current.section!,
                              style: text.bodyMedium,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Pill(
                                    label: _current.examType.isEmpty
                                        ? widget.config.exam.shortLabel
                                        : _current.examType,
                                    color: AppColors.cinnabar,
                                  ),
                                  const SizedBox(width: 8),
                                  if (_current.examYear.isNotEmpty)
                                    Pill(
                                      label: _current.examYear,
                                      color: AppColors.jade,
                                    ),
                                  if (_current.university != null) ...[
                                    const SizedBox(width: 8),
                                    Pill(
                                      label: _current.university!,
                                      color: AppColors.gold,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                _current.question,
                                style: text.titleLarge?.copyWith(fontSize: 18),
                              ),
                              if (_current.imageUrl != null &&
                                  _current.imageUrl!.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    _current.imageUrl!,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) =>
                                        const SizedBox.shrink(),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final option in _current.options) ...[
                          _OptionTile(
                            option: option,
                            selected: _selected == option.key,
                            revealed: _revealed,
                            correctKey: _current.answerKey,
                            onTap: () => _pick(option.key),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (_revealed) ...[
                          const SizedBox(height: 8),
                          GlassCard(
                            color: _current.isCorrect(_selected)
                                ? AppColors.successSoft
                                : AppColors.cinnabarSoft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _current.isCorrect(_selected)
                                      ? 'Correct'
                                      : 'Not quite — answer ${_current.answerKey.toUpperCase()}',
                                  style: text.titleMedium?.copyWith(
                                    color: _current.isCorrect(_selected)
                                        ? AppColors.jade
                                        : AppColors.cinnabar,
                                  ),
                                ),
                                if (_current.solution != null &&
                                    _current.solution!.trim().isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _current.solution!,
                                    style: text.bodyMedium,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_mock)
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: _index == 0
                              ? null
                              : () => _goTo(_index - 1),
                          child: const Text('Previous'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _index + 1 >= _questions.length
                              ? null
                              : () => _goTo(_index + 1),
                          child: const Text('Next'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GradientButton(
                            label: 'Submit paper',
                            icon: Icons.flag_rounded,
                            expand: true,
                            onTap: _confirmSubmit,
                          ),
                        ),
                      ],
                    )
                  else
                    GradientButton(
                      label: _index + 1 >= _questions.length
                          ? 'See results'
                          : 'Next question',
                      icon: Icons.arrow_forward_rounded,
                      expand: true,
                      onTap: _revealed ? _next : null,
                    ),
                ],
              ),
            ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final PastQuestionOption option;
  final bool selected;
  final bool revealed;
  final String correctKey;
  final VoidCallback onTap;

  const _OptionTile({
    required this.option,
    required this.selected,
    required this.revealed,
    required this.correctKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color border = AppColors.line;
    Color fill = AppColors.surface;
    if (revealed && option.key == correctKey) {
      border = AppColors.jade;
      fill = AppColors.successSoft;
    } else if (revealed && selected && option.key != correctKey) {
      border = AppColors.cinnabar;
      fill = AppColors.cinnabarSoft;
    } else if (selected) {
      border = AppColors.cinnabar;
      fill = AppColors.cinnabarSoft.withValues(alpha: 0.5);
    }

    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: revealed ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: 1.4),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: border),
                ),
                child: Text(
                  option.key.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option.text,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _SaveState { idle, saving, saved, failed }

int missedCount(List<PastQuestion> questions, Map<int, String?> answers) =>
    questions.where((q) => !q.isCorrect(answers[q.id])).length;

String _clockLabel(Duration value) {
  final minutes = value.inMinutes;
  final seconds = value.inSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

class _Countdown extends StatelessWidget {
  final Duration remaining;

  const _Countdown({required this.remaining});

  @override
  Widget build(BuildContext context) {
    final urgent = remaining.inSeconds <= 120;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.timer_outlined,
          size: 18,
          color: urgent ? AppColors.danger : AppColors.inkSoft,
        ),
        const SizedBox(width: 4),
        Text(
          _clockLabel(remaining),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: urgent ? AppColors.danger : AppColors.ink,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _Palette extends StatelessWidget {
  final List<PastQuestion> questions;
  final Map<int, String?> answers;
  final int current;
  final ValueChanged<int> onTap;

  const _Palette({
    required this.questions,
    required this.answers,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: questions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final answered = answers[questions[i].id] != null;
          final here = i == current;
          return InkWell(
            onTap: () => onTap(i),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: answered ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: here ? AppColors.ink : AppColors.line,
                  width: here ? 2 : 1,
                ),
              ),
              child: Text(
                '${i + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: answered ? Colors.white : AppColors.ink,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ResultsView extends StatelessWidget {
  final PastQuestionsSessionConfig config;
  final List<PastQuestion> questions;
  final Map<int, String?> answers;
  final int correct;
  final Duration elapsed;
  final _SaveState save;
  final VoidCallback onRetry;
  final VoidCallback onDone;

  const _ResultsView({
    required this.config,
    required this.questions,
    required this.answers,
    required this.correct,
    required this.elapsed,
    required this.save,
    required this.onRetry,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final percent = questions.isEmpty
        ? 0
        : ((correct / questions.length) * 100).round();
    final missed = questions.where((q) => !q.isCorrect(answers[q.id])).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        GlassCard(
          gradient: AppColors.brandGradient,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SESSION COMPLETE',
                style: text.labelLarge?.copyWith(
                  color: AppColors.gold,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$percent%',
                style: text.displaySmall?.copyWith(color: Colors.white),
              ),
              Text(
                '$correct of ${questions.length} correct · ${config.headline}',
                style: text.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Time ${_clockLabel(elapsed)}',
                style: text.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          switch (save) {
            _SaveState.saving => 'Saving to your record…',
            _SaveState.saved =>
              config.assignmentId != null
                  ? 'Saved and handed in to your teacher.'
                  : missedCount(questions, answers) == 0
                  ? 'Saved to your record.'
                  : 'Saved. Misses go to your mistakes list for a retry later.',
            _SaveState.failed =>
              'This session could not be saved. Your score is still shown here.',
            _SaveState.idle => '',
          },
          style: text.bodyMedium?.copyWith(
            color: save == _SaveState.failed
                ? AppColors.danger
                : AppColors.inkSoft,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          missed.isEmpty ? 'Clean sheet' : 'Review misses',
          style: text.titleLarge,
        ),
        const SizedBox(height: 10),
        if (missed.isEmpty)
          Text(
            'Every question landed. Try a harder year or Challenge 40 next.',
            style: text.bodyMedium,
          )
        else
          for (final question in missed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(question.question, style: text.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Your answer: ${(answers[question.id] ?? '—').toUpperCase()}',
                      style: text.bodySmall?.copyWith(
                        color: AppColors.cinnabar,
                      ),
                    ),
                    Text(
                      'Correct: ${question.answerKey.toUpperCase()}'
                      '${question.correctText == null ? '' : ' · ${question.correctText}'}',
                      style: text.bodySmall?.copyWith(color: AppColors.jade),
                    ),
                    if (question.solution != null &&
                        question.solution!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(question.solution!, style: text.bodyMedium),
                    ],
                  ],
                ),
              ),
            ),
        const SizedBox(height: 16),
        GradientButton(
          label: 'Practice again',
          icon: Icons.replay_rounded,
          expand: true,
          onTap: onRetry,
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: onDone,
          child: const Text('Back to exam setup'),
        ),
      ],
    );
  }
}

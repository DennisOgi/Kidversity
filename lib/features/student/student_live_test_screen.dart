import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../models/live_test_models.dart';
import '../../services/live_test_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/live_test_widgets.dart';

/// Full-screen timed quiz for students.
class StudentLiveTestScreen extends ConsumerStatefulWidget {
  final String testId;

  const StudentLiveTestScreen({super.key, required this.testId});

  @override
  ConsumerState<StudentLiveTestScreen> createState() => _StudentLiveTestScreenState();
}

class _StudentLiveTestScreenState extends ConsumerState<StudentLiveTestScreen> {
  int _currentIndex = 0;
  final Map<String, String> _answers = {};
  bool _joined = false;
  bool _submitting = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _join();
  }

  Future<void> _join() async {
    final r = await LiveTestService.instance.joinTest(widget.testId);
    if (mounted && r.isSuccess) setState(() => _joined = true);
  }

  Future<void> _selectAnswer(LiveTest test, LiveTestQuestion q, String optionId) async {
    setState(() => _answers[q.id] = optionId);
    await LiveTestService.instance.submitAnswer(
      testId: test.id,
      questionId: q.id,
      selectedOptionId: optionId,
      options: q.options,
    );
  }

  Future<void> _submitAll(LiveTest test) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await LiveTestService.instance.submitTest(test.id);
    if (mounted) setState(() => _finished = true);
  }

  @override
  Widget build(BuildContext context) {
    final testAsync = ref.watch(liveTestDetailProvider(widget.testId));
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/student/home'),
        ),
        title: const Text('Live Quiz'),
        actions: [
          testAsync.whenOrNull(
            data: (test) => test != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Center(child: LiveCountdownTimer(
                      endsAt: test.endsAt,
                      compact: true,
                      onExpired: () {
                        if (!_finished && test.isActive) _submitAll(test);
                      },
                    )),
                  )
                : null,
          ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: testAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (test) {
          if (test == null) return const Center(child: Text('Quiz not found'));
          if (!_joined) return const Center(child: CircularProgressIndicator());

          if (_finished || test.status == LiveTestStatus.ended) {
            return _ResultsView(test: test, answers: _answers);
          }

          if (test.questions.isEmpty) {
            return const Center(child: Text('No questions in this quiz'));
          }

          final q = test.questions[_currentIndex.clamp(0, test.questions.length - 1)];
          final selected = _answers[q.id];
          final isLast = _currentIndex >= test.questions.length - 1;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Row(
                children: [
                  const LivePulseBadge(),
                  const Spacer(),
                  Text('Question ${_currentIndex + 1} of ${test.questions.length}', style: text.bodyMedium),
                ],
              ),
              const SizedBox(height: 16),
              QuestionProgressDots(
                total: test.questions.length,
                current: _currentIndex,
                answered: {
                  for (var i = 0; i < test.questions.length; i++)
                    if (_answers.containsKey(test.questions[i].id)) i,
                },
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: (_currentIndex + 1) / test.questions.length,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
                backgroundColor: AppColors.line,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(q.prompt, style: text.headlineSmall?.copyWith(fontSize: 22)),
                    const SizedBox(height: 20),
                    for (final opt in q.options)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _AnswerTile(
                          label: opt.label,
                          selected: selected == opt.id,
                          onTap: () => _selectAnswer(test, q, opt.id),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  if (_currentIndex > 0)
                    OutlinedButton(
                      onPressed: () => setState(() => _currentIndex--),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: selected == null
                        ? null
                        : () async {
                            if (isLast) {
                              await _submitAll(test);
                            } else {
                              setState(() => _currentIndex++);
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: isLast ? AppColors.success : AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    ),
                    child: Text(isLast ? 'Submit quiz' : 'Next'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AnswerTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AnswerTile({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: selected ? AppColors.primarySoft : AppColors.backgroundAlt,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: selected ? AppColors.primary : AppColors.line, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: selected ? AppColors.primary : AppColors.muted),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: text.titleMedium?.copyWith(fontSize: 16))),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultsView extends StatelessWidget {
  final LiveTest test;
  final Map<String, String> answers;

  const _ResultsView({required this.test, required this.answers});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    var score = 0;
    for (final q in test.questions) {
      final picked = answers[q.id];
      if (picked != null && q.options.any((o) => o.id == picked && o.isCorrect)) score++;
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        GlassCard(
          gradient: AppColors.brandGradient,
          child: Column(
            children: [
              const Text('🎉', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text('Quiz submitted!', style: text.headlineSmall?.copyWith(color: Colors.white)),
              const SizedBox(height: 8),
              Text('You scored $score / ${test.questions.length}',
                  style: text.titleLarge?.copyWith(color: Colors.white.withValues(alpha: 0.95))),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Your answers', style: text.titleMedium),
        const SizedBox(height: 12),
        for (final q in test.questions) ...[
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q.prompt, style: text.titleMedium?.copyWith(fontSize: 15)),
                const SizedBox(height: 8),
                Builder(builder: (context) {
                  final picked = answers[q.id];
                  final opt = q.options.where((o) => o.id == picked).firstOrNull;
                  final correct = q.options.where((o) => o.isCorrect).firstOrNull;
                  final ok = opt?.isCorrect ?? false;
                  return Row(
                    children: [
                      Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          color: ok ? AppColors.success : AppColors.danger, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(opt?.label ?? 'Skipped', style: text.bodyMedium)),
                      if (!ok && correct != null)
                        Text('→ ${correct.label}', style: text.bodySmall?.copyWith(color: AppColors.success)),
                    ],
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        FilledButton(
          onPressed: () => context.go('/student/home'),
          child: const Text('Back to home'),
        ),
      ],
    );
  }
}

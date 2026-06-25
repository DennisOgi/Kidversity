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

/// Teacher hub — quick templates, custom quiz builder, go live.
class TeacherLiveHubScreen extends ConsumerStatefulWidget {
  const TeacherLiveHubScreen({super.key});

  @override
  ConsumerState<TeacherLiveHubScreen> createState() => _TeacherLiveHubScreenState();
}

class _TeacherLiveHubScreenState extends ConsumerState<TeacherLiveHubScreen> {
  bool _busy = false;
  int _duration = 300;
  final _titleCtrl = TextEditingController(text: 'Quick Check Quiz');
  final List<_DraftQuestion> _questions = [
    _DraftQuestion(
      prompt: 'What is 2 + 2?',
      options: ['3', '4', '5'],
      correctIndex: 1,
    ),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _launch({LiveQuizTemplate? template}) async {
    setState(() => _busy = true);
    try {
      final result = template != null
          ? await LiveTestService.instance.createFromTemplate(template, durationSeconds: _duration)
          : await LiveTestService.instance.createTest(
              title: _titleCtrl.text.trim().isEmpty ? 'Live Quiz' : _titleCtrl.text.trim(),
              subject: 'General',
              durationSeconds: _duration,
              questions: _questions.map((q) => q.toPayload()).toList(),
            );

      if (!mounted) return;
      if (result.isFailure || result.data == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.error ?? 'Failed')));
        return;
      }

      final start = await LiveTestService.instance.startTest(result.data!.id);
      if (!mounted) return;
      if (start.isFailure || start.data == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(start.error ?? 'Could not start')));
        return;
      }

      context.go('/teacher/live/${start.data!.id}/monitor');
      ref.invalidate(teacherRecentTestsProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final roster = ref.watch(rosterProvider).value ?? [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Live Quiz', style: text.headlineSmall),
                  Text('Timed tests with real-time student responses', style: text.bodyMedium),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        GlassCard(
          gradient: LinearGradient(
            colors: [AppColors.danger.withValues(alpha: 0.12), AppColors.secondarySoft],
          ),
          child: Row(
            children: [
              const LivePulseBadge(),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  roster.isEmpty
                      ? 'Students in your class will get an instant alert when you go live.'
                      : '${roster.length} students ready — they\'ll see a banner as soon as you start.',
                  style: text.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SectionHeader(title: 'Quick start templates', subtitle: 'One tap to go live'),
        const SizedBox(height: 12),
        for (final t in LiveQuizTemplate.all) ...[
          _TemplateCard(
            template: t,
            busy: _busy,
            onLaunch: () => _launch(template: t),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 12),
        const SectionHeader(title: 'Build your own', subtitle: 'Custom questions & timer'),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Quiz title', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              Text('Duration', style: text.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final sec in [180, 300, 600, 900])
                    ChoiceChip(
                      label: Text('${sec ~/ 60} min'),
                      selected: _duration == sec,
                      onSelected: _busy ? null : (_) => setState(() => _duration = sec),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              for (var i = 0; i < _questions.length; i++) ...[
                _QuestionEditor(
                  index: i,
                  question: _questions[i],
                  onChanged: (q) => setState(() => _questions[i] = q),
                  onRemove: _questions.length > 1 ? () => setState(() => _questions.removeAt(i)) : null,
                ),
                const SizedBox(height: 14),
              ],
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => setState(() => _questions.add(_DraftQuestion(
                          prompt: '',
                          options: ['', '', ''],
                          correctIndex: 0,
                        ))),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add question'),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _busy ? null : () => _launch(),
                icon: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(_busy ? 'Starting…' : 'Go live now'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const SectionHeader(title: 'Recent sessions', subtitle: 'Review past live quizzes'),
        const SizedBox(height: 12),
        _RecentSessionsList(busy: _busy),
      ],
    );
  }
}

class _RecentSessionsList extends ConsumerWidget {
  final bool busy;

  const _RecentSessionsList({required this.busy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final recent = ref.watch(teacherRecentTestsProvider);

    return recent.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
      error: (_, __) => GlassCard(child: Text('Could not load recent sessions', style: text.bodyMedium)),
      data: (tests) {
        if (tests.isEmpty) {
          return GlassCard(
            child: Text('No live quizzes yet — launch your first one above!', style: text.bodyMedium),
          );
        }
        return Column(
          children: [
            for (final t in tests) ...[
              _RecentTestRow(test: t, busy: busy),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _RecentTestRow extends StatelessWidget {
  final LiveTest test;
  final bool busy;

  const _RecentTestRow({required this.test, required this.busy});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final statusLabel = switch (test.status) {
      LiveTestStatus.live => 'Live now',
      LiveTestStatus.ended => 'Ended',
      LiveTestStatus.draft => 'Draft',
    };
    final statusColor = switch (test.status) {
      LiveTestStatus.live => AppColors.danger,
      LiveTestStatus.ended => AppColors.muted,
      LiveTestStatus.draft => AppColors.warning,
    };
    final durationMin = test.durationSeconds ~/ 60;

    return GlassCard(
      onTap: busy
          ? null
          : () {
              if (test.status == LiveTestStatus.live) {
                context.go('/teacher/live/${test.id}/monitor');
              } else if (test.status == LiveTestStatus.ended) {
                context.go('/teacher/live/${test.id}/monitor');
              }
            },
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              test.status == LiveTestStatus.live ? Icons.sensors_rounded : Icons.history_rounded,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(test.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleMedium?.copyWith(fontSize: 15)),
                Text('${test.questions.length} Q · ${durationMin} min · ${test.subject}',
                    style: text.bodySmall?.copyWith(color: AppColors.muted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(statusLabel, style: text.labelSmall?.copyWith(color: statusColor, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final LiveQuizTemplate template;
  final bool busy;
  final VoidCallback onLaunch;

  const _TemplateCard({required this.template, required this.busy, required this.onLaunch});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      onTap: busy ? null : onLaunch,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: template.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.center,
            child: Text(template.emoji, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(template.title, style: text.titleMedium),
                Text('${template.questions.length} questions · ${template.subject}', style: text.bodyMedium),
              ],
            ),
          ),
          Icon(Icons.rocket_launch_rounded, color: template.color),
        ],
      ),
    );
  }
}

class _DraftQuestion {
  String prompt;
  List<String> options;
  int correctIndex;

  _DraftQuestion({required this.prompt, required this.options, required this.correctIndex});

  ({String prompt, List<LiveTestOption> options}) toPayload() {
    return (
      prompt: prompt.isEmpty ? 'Question' : prompt,
      options: options.asMap().entries.map((e) {
        return LiveTestOption(id: 'o${e.key}', label: e.value.isEmpty ? 'Option ${e.key + 1}' : e.value, isCorrect: e.key == correctIndex);
      }).toList(),
    );
  }
}

class _QuestionEditor extends StatelessWidget {
  final int index;
  final _DraftQuestion question;
  final ValueChanged<_DraftQuestion> onChanged;
  final VoidCallback? onRemove;

  const _QuestionEditor({
    required this.index,
    required this.question,
    required this.onChanged,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.backgroundAlt, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Q${index + 1}', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (onRemove != null)
                IconButton(onPressed: onRemove, icon: const Icon(Icons.close_rounded, size: 20)),
            ],
          ),
          TextField(
            onChanged: (v) {
              question.prompt = v;
              onChanged(question);
            },
            decoration: const InputDecoration(hintText: 'Question prompt', isDense: true),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < question.options.length; i++)
            Row(
              children: [
                Radio<int>(
                  value: i,
                  groupValue: question.correctIndex,
                  onChanged: (v) {
                    if (v != null) {
                      question.correctIndex = v;
                      onChanged(question);
                    }
                  },
                ),
                Expanded(
                  child: TextField(
                    onChanged: (v) {
                      question.options[i] = v;
                      onChanged(question);
                    },
                    decoration: InputDecoration(hintText: 'Option ${i + 1}', isDense: true),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../data/auth_state.dart';
import '../../models/mandarin_content.dart';
import '../../models/user_preferences.dart';
import '../../services/mandarin_audio_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/error_boundary.dart';

enum _FoundationStage { character, explain, dialogue, practice, quest, result }

class MandarinLessonPlayer extends ConsumerStatefulWidget {
  final String lessonId;

  const MandarinLessonPlayer({super.key, required this.lessonId});

  @override
  ConsumerState<MandarinLessonPlayer> createState() =>
      _MandarinLessonPlayerState();
}

class _MandarinLessonPlayerState extends ConsumerState<MandarinLessonPlayer> {
  _FoundationStage _stage = _FoundationStage.character;
  int _index = 0;
  int _questCorrect = 0;
  String? _selected;
  bool _answered = false;
  bool _saving = false;
  bool _saved = false;
  bool _showCaptions = true;
  final TextEditingController _typedAnswer = TextEditingController();
  final List<Map<String, dynamic>> _answers = [];

  @override
  void dispose() {
    MandarinAudioService.instance.stop();
    _typedAnswer.dispose();
    super.dispose();
  }

  void _speak(String text, {String? audioUrl, double rate = 0.82}) {
    MandarinAudioService.instance.play(
      text: text,
      audioUrl: audioUrl,
      rate: rate,
    );
  }

  List<_FoundationStage> _stagesFor(MandarinCourseLesson lesson) =>
      <_FoundationStage>[
        _FoundationStage.character,
        _FoundationStage.explain,
        if (lesson.dialogue.isNotEmpty) _FoundationStage.dialogue,
        if (lesson.activities.isNotEmpty) _FoundationStage.practice,
        _FoundationStage.quest,
        _FoundationStage.result,
      ];

  void _nextStage(MandarinCourseLesson lesson) {
    final stages = _stagesFor(lesson);
    final next = stages.indexOf(_stage) + 1;
    if (next < stages.length) {
      setState(() {
        _stage = stages[next];
        _index = 0;
        _selected = null;
        _answered = false;
        _typedAnswer.clear();
      });
    }
  }

  void _answer({
    required String itemId,
    required String selected,
    required String correct,
    required bool countsForScore,
  }) {
    if (_answered) return;
    final cleaned = selected.trim();
    final isCorrect = cleaned.toLowerCase() == correct.trim().toLowerCase();
    setState(() {
      _selected = isCorrect ? correct : cleaned;
      _answered = true;
      if (isCorrect && countsForScore) _questCorrect++;
      _answers.add({
        'item_id': itemId,
        'selected': cleaned,
        'correct_answer': correct,
        'is_correct': isCorrect,
      });
    });
  }

  void _nextItemOrStage(int count, MandarinCourseLesson lesson) {
    if (_index + 1 < count) {
      setState(() {
        _index++;
        _selected = null;
        _answered = false;
        _typedAnswer.clear();
      });
    } else {
      _nextStage(lesson);
    }
  }

  Future<void> _save(MandarinCourseLesson lesson) async {
    if (_saving || _saved || !SupabaseService.instance.isInitialized) return;
    final total = lesson.assessment.length;
    final score = total == 0
        ? 100
        : ((_questCorrect / total) * 100).round().clamp(0, 100);
    setState(() => _saving = true);
    final result = await SupabaseService.instance.completeFoundationLesson(
      lessonId: lesson.id,
      score: score,
      answers: _answers,
      xpReward: lesson.xpReward,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = result.isSuccess;
    });
    if (result.isFailure) {
      context.showErrorSnackbar(result.error ?? 'Could not save your result.');
      return;
    }
    ref.invalidate(foundationCompletedLessonIdsProvider);
    await ref.read(authControllerProvider).reloadProfile();
  }

  @override
  Widget build(BuildContext context) {
    final preferences =
        ref.watch(userPreferencesProvider).whenOrNull(data: (value) => value) ??
        const UserPreferences();
    _showCaptions = preferences.showCaptions;
    final completedLessonIds =
        ref
            .watch(foundationCompletedLessonIdsProvider)
            .whenOrNull(data: (value) => value) ??
        const <String>{};
    return ref
        .watch(mandarinExperienceProvider(widget.lessonId))
        .when(
          loading: () => const Scaffold(
            body: LoadingIndicator(message: 'Preparing lesson…'),
          ),
          error: (error, _) => Scaffold(
            body: ErrorDisplay(
              message: 'This lesson is not ready yet.',
              error: error,
              onRetry: () =>
                  ref.invalidate(mandarinExperienceProvider(widget.lessonId)),
            ),
          ),
          data: (experience) {
            final lesson = experience.source;
            if (lesson.sequence > 1) {
              final previousId =
                  'mfv1_l${(lesson.sequence - 1).toString().padLeft(2, '0')}';
              if (!completedLessonIds.contains(previousId)) {
                return Scaffold(
                  body: ErrorDisplay(
                    message: 'Complete the previous lesson to unlock this one.',
                    onRetry: () => context.go('/student/path'),
                  ),
                );
              }
            }
            return _buildLesson(context, lesson, preferences.dyslexiaFriendly);
          },
        );
  }

  Widget _buildLesson(
    BuildContext context,
    MandarinCourseLesson lesson,
    bool dyslexiaFriendly,
  ) {
    final stages = _stagesFor(lesson);
    final progress = (stages.indexOf(_stage) + 1) / stages.length;
    final scaffold = Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        leading: IconButton(
          onPressed: () => context.go('/student/path'),
          icon: const Icon(Icons.close_rounded),
        ),
        title: Text('${lesson.sequence}. ${lesson.title}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${lesson.xpReward} XP',
                style: const TextStyle(color: AppColors.cinnabar),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            color: AppColors.cinnabar,
            backgroundColor: AppColors.line,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 260),
                child: switch (_stage) {
                  _FoundationStage.character => _characterStage(lesson),
                  _FoundationStage.explain => _explainStage(lesson),
                  _FoundationStage.dialogue => _dialogueStage(lesson),
                  _FoundationStage.practice => _practiceStage(lesson),
                  _FoundationStage.quest => _questStage(lesson),
                  _FoundationStage.result => _resultStage(lesson),
                },
              ),
            ),
          ),
        ),
      ),
    );
    if (!dyslexiaFriendly) return scaffold;
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(
          fontSizeFactor: 1.04,
          bodyColor: AppColors.ink,
          displayColor: AppColors.ink,
        ),
      ),
      child: scaffold,
    );
  }

  Widget _characterStage(MandarinCourseLesson lesson) {
    final item = lesson.vocabulary[_index];
    return _StageCard(
      key: ValueKey('character-${item.id}'),
      eyebrow: 'LOOK · LISTEN · REPEAT',
      child: Column(
        children: [
          Text(
            item.simplified,
            style: const TextStyle(
              fontSize: 78,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          if (_showCaptions) ...[
            Text(
              item.pinyin,
              style: TextStyle(
                fontSize: 28,
                color: _toneColor(item.pinyin),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.english,
              style: const TextStyle(fontSize: 18, color: AppColors.inkSoft),
            ),
          ],
          const SizedBox(height: 30),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () =>
                    _speak(item.simplified, audioUrl: item.audioUrl),
                icon: const Icon(Icons.volume_up_rounded),
                label: const Text('Listen'),
              ),
              OutlinedButton.icon(
                onPressed: () => _speak(
                  item.simplified,
                  audioUrl: item.audioUrl,
                  rate: 0.58,
                ),
                icon: const Icon(Icons.slow_motion_video_rounded),
                label: const Text('Slow'),
              ),
            ],
          ),
          const SizedBox(height: 26),
          _ContinueButton(
            label: _index + 1 < lesson.vocabulary.length
                ? 'Next word'
                : 'I’m ready',
            onTap: () => _nextItemOrStage(lesson.vocabulary.length, lesson),
          ),
        ],
      ),
    );
  }

  Widget _explainStage(MandarinCourseLesson lesson) => _StageCard(
    key: const ValueKey('explain'),
    eyebrow: 'MAKE SENSE OF IT',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Here’s the idea',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 18),
        Text(
          lesson.explanation,
          style: const TextStyle(
            fontSize: 19,
            height: 1.6,
            color: AppColors.inkSoft,
          ),
        ),
        for (final pattern in lesson.grammar) ...[
          const SizedBox(height: 18),
          Text(
            pattern.pattern,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(pattern.explanation),
          const SizedBox(height: 7),
          Text(
            '${pattern.chinese} · ${pattern.pinyin}',
            style: const TextStyle(
              color: AppColors.cinnabar,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(pattern.english),
        ],
        for (final example in lesson.examples) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.backgroundAlt,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  example.chinese,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  example.pinyin,
                  style: const TextStyle(color: AppColors.cinnabar),
                ),
                Text(example.english),
              ],
            ),
          ),
        ],
        if (lesson.sequence == 2) ...[
          const SizedBox(height: 22),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            child: Image.asset(
              'assets/mandarin/four_tones_diagram.png',
              fit: BoxFit.cover,
            ),
          ),
        ],
        const SizedBox(height: 28),
        _ContinueButton(label: 'Try it', onTap: () => _nextStage(lesson)),
      ],
    ),
  );

  Widget _dialogueStage(MandarinCourseLesson lesson) {
    final line = lesson.dialogue[_index];
    return _StageCard(
      key: ValueKey('dialogue-${line.id}'),
      eyebrow: 'MINI DIALOGUE',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            line.speaker,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.jade,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.backgroundAlt,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: Column(
              children: [
                Text(
                  line.chinese,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_showCaptions) ...[
                  const SizedBox(height: 6),
                  Text(
                    line.pinyin,
                    style: const TextStyle(
                      fontSize: 19,
                      color: AppColors.cinnabar,
                    ),
                  ),
                  Text(
                    line.english,
                    style: const TextStyle(color: AppColors.inkSoft),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => _speak(line.chinese, audioUrl: line.audioUrl),
            icon: const Icon(Icons.volume_up_rounded),
            label: const Text('Play line'),
          ),
          const SizedBox(height: 18),
          _ContinueButton(
            label: 'Next',
            onTap: () => _nextItemOrStage(lesson.dialogue.length, lesson),
          ),
        ],
      ),
    );
  }

  Widget _practiceStage(MandarinCourseLesson lesson) {
    final item = lesson.activities[_index];
    return _QuestionStage(
      key: ValueKey('practice-${item.id}'),
      eyebrow: 'PRACTICE',
      prompt: item.prompt,
      options: _ordered(item.options, item.id),
      selected: _selected,
      correct: item.answer,
      answered: _answered,
      audioText: item.type == MandarinActivityType.listenTap
          ? item.answer
          : null,
      audioUrl: item.audioUrl,
      typed: item.type == MandarinActivityType.fillBlank,
      typedAnswer: _typedAnswer,
      explanation: item.explanation,
      onAnswer: (answer) => _answer(
        itemId: item.id,
        selected: answer,
        correct: item.answer,
        countsForScore: false,
      ),
      onNext: () => _nextItemOrStage(lesson.activities.length, lesson),
    );
  }

  Widget _questStage(MandarinCourseLesson lesson) {
    final item = lesson.assessment[_index];
    return _QuestionStage(
      key: ValueKey('quest-${item.id}'),
      eyebrow: 'QUEST · ${_index + 1}/${lesson.assessment.length}',
      prompt: item.question,
      options: _ordered(item.options, item.id),
      selected: _selected,
      correct: item.correctAnswer,
      answered: _answered,
      audioText: item.type == MandarinActivityType.listenTap
          ? item.correctAnswer
          : null,
      audioUrl: item.audioUrl,
      typed: item.type == MandarinActivityType.fillBlank,
      typedAnswer: _typedAnswer,
      explanation: item.explanation,
      onAnswer: (answer) => _answer(
        itemId: item.id,
        selected: answer,
        correct: item.correctAnswer,
        countsForScore: true,
      ),
      onNext: () => _nextItemOrStage(lesson.assessment.length, lesson),
    );
  }

  Widget _resultStage(MandarinCourseLesson lesson) {
    final total = lesson.assessment.length;
    final score = total == 0 ? 100 : ((_questCorrect / total) * 100).round();
    if (!_saved && !_saving && SupabaseService.instance.isInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _save(lesson));
    }
    return _StageCard(
      key: const ValueKey('result'),
      eyebrow: 'LESSON COMPLETE',
      child: Column(
        children: [
          const Text(
            '完成',
            style: TextStyle(
              fontSize: 58,
              fontWeight: FontWeight.w800,
              color: AppColors.cinnabar,
            ),
          ),
          const Text(
            'Wánchéng · Complete!',
            style: TextStyle(fontSize: 20, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 24),
          Text(
            '$score%',
            style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900),
          ),
          Text('$_questCorrect of $total quest answers correct'),
          const SizedBox(height: 12),
          Text(
            '+${lesson.xpReward} XP',
            style: const TextStyle(
              color: AppColors.jade,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (_saving) ...[
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ],
          const SizedBox(height: 28),
          _ContinueButton(
            label: 'Back to my path',
            onTap: () => context.go('/student/path'),
          ),
        ],
      ),
    );
  }

  List<String> _ordered(List<String> values, String seed) {
    if (values.length < 2) return values;
    final shift =
        seed.codeUnits.fold<int>(0, (sum, value) => sum + value) %
        values.length;
    return [...values.skip(shift), ...values.take(shift)];
  }

  Color _toneColor(String pinyin) {
    if (RegExp('[āēīōūǖ]').hasMatch(pinyin)) return const Color(0xFF3D6FB4);
    if (RegExp('[áéíóúǘ]').hasMatch(pinyin)) return AppColors.jade;
    if (RegExp('[ǎěǐǒǔǚ]').hasMatch(pinyin)) return AppColors.gold;
    if (RegExp('[àèìòùǜ]').hasMatch(pinyin)) return AppColors.cinnabar;
    return AppColors.inkSoft;
  }
}

class _StageCard extends StatelessWidget {
  final String eyebrow;
  final Widget child;

  const _StageCard({super.key, required this.eyebrow, required this.child});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            eyebrow,
            style: const TextStyle(
              color: AppColors.cinnabar,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    ),
  );
}

class _QuestionStage extends StatelessWidget {
  final String eyebrow;
  final String prompt;
  final List<String> options;
  final String? selected;
  final String correct;
  final bool answered;
  final String? audioText;
  final String? audioUrl;
  final bool typed;
  final TextEditingController typedAnswer;
  final String explanation;
  final ValueChanged<String> onAnswer;
  final VoidCallback onNext;

  const _QuestionStage({
    super.key,
    required this.eyebrow,
    required this.prompt,
    required this.options,
    required this.selected,
    required this.correct,
    required this.answered,
    required this.audioText,
    this.audioUrl,
    required this.typed,
    required this.typedAnswer,
    required this.explanation,
    required this.onAnswer,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) => _StageCard(
    eyebrow: eyebrow,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (audioText != null) ...[
          Center(
            child: FilledButton.tonalIcon(
              onPressed: () => MandarinAudioService.instance.play(
                text: audioText!,
                audioUrl: audioUrl,
                rate: 0.78,
              ),
              icon: const Icon(Icons.volume_up_rounded),
              label: const Text('Play audio'),
            ),
          ),
          const SizedBox(height: 18),
        ],
        Text(
          prompt,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 22),
        if (typed)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: typedAnswer,
                  enabled: !answered,
                  textInputAction: TextInputAction.done,
                  onSubmitted: answered
                      ? null
                      : (value) {
                          if (value.trim().isNotEmpty) onAnswer(value);
                        },
                  decoration: const InputDecoration(
                    labelText: 'Type your answer',
                    hintText: 'Enter the missing word',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: answered
                    ? null
                    : () {
                        if (typedAnswer.text.trim().isNotEmpty) {
                          onAnswer(typedAnswer.text);
                        }
                      },
                child: const Text('Check'),
              ),
            ],
          )
        else
          for (final option in options) ...[
            _AnswerOption(
              label: option,
              selected: selected == option,
              correct: answered && option == correct,
              wrong: answered && selected == option && option != correct,
              onTap: answered ? null : () => onAnswer(option),
            ),
            const SizedBox(height: 10),
          ],
        if (answered) ...[
          const SizedBox(height: 8),
          Text(
            selected == correct
                ? '✓ Correct — $explanation'
                : 'Not quite — $explanation',
            style: TextStyle(
              color: selected == correct ? AppColors.jade : AppColors.cinnabar,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          _ContinueButton(label: 'Continue', onTap: onNext),
        ],
      ],
    ),
  );
}

class _AnswerOption extends StatelessWidget {
  final String label;
  final bool selected;
  final bool correct;
  final bool wrong;
  final VoidCallback? onTap;

  const _AnswerOption({
    required this.label,
    required this.selected,
    required this.correct,
    required this.wrong,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = correct
        ? AppColors.jade
        : (wrong ? AppColors.cinnabar : AppColors.ink);
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        foregroundColor: color,
        backgroundColor: selected
            ? color.withValues(alpha: 0.08)
            : AppColors.surface,
        side: BorderSide(
          color: (selected || correct) ? color : AppColors.line,
          width: 1.5,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ContinueButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onTap,
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16),
    ),
    child: Text(label),
  );
}

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
import '../../widgets/common.dart';
import '../../widgets/error_boundary.dart';

enum _FoundationStage {
  warmup,
  character,
  explain,
  dialogue,
  speak,
  practice,
  quest,
  result,
}

class MandarinLessonPlayer extends ConsumerStatefulWidget {
  final String lessonId;

  const MandarinLessonPlayer({super.key, required this.lessonId});

  @override
  ConsumerState<MandarinLessonPlayer> createState() =>
      _MandarinLessonPlayerState();
}

class _MandarinLessonPlayerState extends ConsumerState<MandarinLessonPlayer> {
  _FoundationStage? _activeStage;
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

  _FoundationStage _stageFor(List<_FoundationStage> stages) {
    final active = _activeStage;
    if (active != null && stages.contains(active)) return active;
    return stages.first;
  }

  List<MandarinVocabItem> _recycleWords(MandarinCourseLesson lesson) {
    final course = ref.read(mandarinCourseProvider).whenOrNull(data: (c) => c);
    if (course == null || lesson.sequence <= 1) return const [];
    final current = {for (final word in lesson.vocabulary) word.simplified};
    final byLesson = <int, List<MandarinVocabItem>>{};
    final seen = <String>{};
    final prior = [...course.lessons]
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    for (final older in prior.where(
      (item) => item.sequence < lesson.sequence,
    )) {
      final bucket = <MandarinVocabItem>[];
      for (final word in older.vocabulary) {
        if (current.contains(word.simplified) ||
            seen.contains(word.simplified)) {
          continue;
        }
        seen.add(word.simplified);
        bucket.add(word);
      }
      if (bucket.isNotEmpty) byLesson[older.sequence] = bucket;
    }
    if (byLesson.isEmpty) return const [];
    final picks = <MandarinVocabItem>[];
    void takeFrom(int sequence) {
      final bucket = byLesson[sequence];
      if (bucket == null || bucket.isEmpty) return;
      final word = bucket.first;
      if (picks.any((item) => item.simplified == word.simplified)) return;
      picks.add(word);
    }

    takeFrom(lesson.sequence - 1);
    takeFrom(lesson.sequence - 3);
    takeFrom(lesson.sequence - 7);
    for (final sequence in byLesson.keys) {
      if (picks.length >= 4) break;
      takeFrom(sequence);
    }
    return picks.take(4).toList(growable: false);
  }

  List<_FoundationStage> _stagesFor(
    MandarinCourseLesson lesson, [
    List<MandarinVocabItem>? recycle,
  ]) {
    final recycled = recycle ?? _recycleWords(lesson);
    return <_FoundationStage>[
      if (recycled.isNotEmpty) _FoundationStage.warmup,
      _FoundationStage.character,
      _FoundationStage.explain,
      if (lesson.dialogue.isNotEmpty) _FoundationStage.dialogue,
      if (lesson.vocabulary.isNotEmpty) _FoundationStage.speak,
      if (lesson.activities.isNotEmpty) _FoundationStage.practice,
      _FoundationStage.quest,
      _FoundationStage.result,
    ];
  }

  void _nextStage(MandarinCourseLesson lesson) {
    final stages = _stagesFor(lesson);
    final next = stages.indexOf(_stageFor(stages)) + 1;
    if (next < stages.length) {
      setState(() {
        _activeStage = stages[next];
        _index = 0;
        _selected = null;
        _answered = false;
        _typedAnswer.clear();
      });
    }
  }

  int _lastIndexFor(_FoundationStage stage, MandarinCourseLesson lesson) {
    switch (stage) {
      case _FoundationStage.warmup:
        return (_recycleWords(lesson).length - 1).clamp(0, 999);
      case _FoundationStage.character:
      case _FoundationStage.speak:
        return (lesson.vocabulary.length - 1).clamp(0, 999);
      case _FoundationStage.dialogue:
        return (lesson.dialogue.length - 1).clamp(0, 999);
      case _FoundationStage.practice:
        return (lesson.activities.length - 1).clamp(0, 999);
      case _FoundationStage.quest:
        return (lesson.assessment.length - 1).clamp(0, 999);
      case _FoundationStage.explain:
      case _FoundationStage.result:
        return 0;
    }
  }

  bool _canGoBack(MandarinCourseLesson lesson) {
    final stages = _stagesFor(lesson);
    final stage = _stageFor(stages);
    if (stage == _FoundationStage.result) return false;
    if (_index > 0) return true;
    return stages.indexOf(stage) > 0;
  }

  void _previousStage(MandarinCourseLesson lesson) {
    final stages = _stagesFor(lesson);
    final prev = stages.indexOf(_stageFor(stages)) - 1;
    if (prev < 0) return;
    final previous = stages[prev];
    setState(() {
      _activeStage = previous;
      _index = _lastIndexFor(previous, lesson);
      _selected = null;
      _answered = false;
      _typedAnswer.clear();
    });
  }

  void _previousItemOrStage(int count, MandarinCourseLesson lesson) {
    if (_index > 0) {
      setState(() {
        _index--;
        _selected = null;
        _answered = false;
        _typedAnswer.clear();
      });
      return;
    }
    _previousStage(lesson);
  }

  String _normalizeChinese(String value) =>
      value.replaceAll(RegExp(r'[！!？?。.\s，,]'), '');

  String? _audioUrlForChinese(MandarinCourseLesson lesson, String chinese) {
    final target = _normalizeChinese(chinese);
    if (target.isEmpty) return null;
    for (final item in lesson.vocabulary) {
      if (_normalizeChinese(item.simplified) == target &&
          item.audioUrl != null &&
          item.audioUrl!.isNotEmpty) {
        return item.audioUrl;
      }
    }
    for (final line in lesson.dialogue) {
      if (_normalizeChinese(line.chinese) == target &&
          line.audioUrl != null &&
          line.audioUrl!.isNotEmpty) {
        return line.audioUrl;
      }
    }
    for (final example in lesson.examples) {
      if (_normalizeChinese(example.chinese) == target &&
          example.audioUrl != null &&
          example.audioUrl!.isNotEmpty) {
        return example.audioUrl;
      }
    }
    for (final pattern in lesson.grammar) {
      if ((_normalizeChinese(pattern.chinese) == target ||
              _normalizeChinese(pattern.pattern) == target) &&
          pattern.audioUrl != null &&
          pattern.audioUrl!.isNotEmpty) {
        return pattern.audioUrl;
      }
    }
    return null;
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
    final recycle = _recycleWords(lesson);
    final stages = _stagesFor(lesson, recycle);
    final stage = _stageFor(stages);
    final progress = (stages.indexOf(stage) + 1) / stages.length;
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
          preferredSize: const Size.fromHeight(28),
          child: Column(
            children: [
              LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                color: AppColors.cinnabar,
                backgroundColor: AppColors.line,
              ),
              _StageStrip(stages: stages, current: stage),
            ],
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              child: switch (stage) {
                _FoundationStage.warmup => _wordCardStage(
                  lesson: lesson,
                  keyPrefix: 'warmup',
                  items: recycle,
                  eyebrow: 'Warm-up ${_index + 1} of ${recycle.length}',
                  title: 'Words you already know',
                  hint:
                      'Hear them again. These words come back on purpose so they stick.',
                  lastLabel: 'Start today’s words',
                  nextLabel: 'Next',
                ),
                _FoundationStage.character => _wordCardStage(
                  lesson: lesson,
                  keyPrefix: 'character',
                  items: lesson.vocabulary,
                  eyebrow: 'Word ${_index + 1} of ${lesson.vocabulary.length}',
                  title: 'Look, listen, then say it',
                  hint: _index == 0
                      ? 'Tap Listen, repeat the word out loud, then go to the next word.'
                      : null,
                  lastLabel: 'I’m ready for the idea',
                  nextLabel: 'Next word',
                ),
                _FoundationStage.explain => _explainStage(lesson),
                _FoundationStage.dialogue => _dialogueStage(lesson),
                _FoundationStage.speak => _speakStage(lesson),
                _FoundationStage.practice => _practiceStage(lesson),
                _FoundationStage.quest => _questStage(lesson),
                _FoundationStage.result => _resultStage(lesson),
              },
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

  Widget _wordCardStage({
    required MandarinCourseLesson lesson,
    required String keyPrefix,
    required List<MandarinVocabItem> items,
    required String eyebrow,
    required String title,
    required String lastLabel,
    required String nextLabel,
    String? hint,
  }) {
    final safeIndex = items.isEmpty ? 0 : _index.clamp(0, items.length - 1);
    final item = items[safeIndex];
    final last = safeIndex + 1 >= items.length;
    return _LessonPage(
      key: ValueKey('$keyPrefix-${item.id}'),
      eyebrow: eyebrow,
      title: title,
      hint: hint,
      footer: _LessonNavFooter(
        onBack: _canGoBack(lesson)
            ? () => _previousItemOrStage(items.length, lesson)
            : null,
        continueLabel: last ? lastLabel : nextLabel,
        onContinue: () => _nextItemOrStage(items.length, lesson),
      ),
      child: Column(
        children: [
          const Spacer(),
          Text(
            item.simplified,
            style: const TextStyle(
              fontSize: 96,
              height: 1.05,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          if (_showCaptions) ...[
            Text(
              item.pinyin,
              style: TextStyle(
                fontSize: 32,
                color: _toneColor(item.pinyin),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.english,
              style: const TextStyle(fontSize: 20, color: AppColors.inkSoft),
            ),
          ],
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      _speak(item.simplified, audioUrl: item.audioUrl),
                  icon: const Icon(Icons.volume_up_rounded),
                  label: const Text('Listen'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _speak(
                    item.simplified,
                    audioUrl: item.audioUrl,
                    rate: 0.58,
                  ),
                  icon: const Icon(Icons.slow_motion_video_rounded),
                  label: const Text('Slow'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _speakStage(MandarinCourseLesson lesson) {
    final item =
        lesson.vocabulary[_index.clamp(0, lesson.vocabulary.length - 1)];
    final last = _index + 1 >= lesson.vocabulary.length;
    return _LessonPage(
      key: ValueKey('speak-${item.id}'),
      eyebrow: 'Your turn ${_index + 1} of ${lesson.vocabulary.length}',
      title: 'Cover the English. Say it out loud.',
      hint: 'Listen once, look away from the meaning, then say the Chinese.',
      footer: _LessonNavFooter(
        onBack: _canGoBack(lesson)
            ? () => _previousItemOrStage(lesson.vocabulary.length, lesson)
            : null,
        continueLabel: last ? 'I’m ready to practise' : 'I said it',
        onContinue: () => _nextItemOrStage(lesson.vocabulary.length, lesson),
      ),
      child: Column(
        children: [
          const Spacer(),
          Text(
            item.simplified,
            style: const TextStyle(
              fontSize: 88,
              height: 1.05,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.pinyin,
            style: TextStyle(
              fontSize: 28,
              color: _toneColor(item.pinyin),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'English is hidden so you produce the word, not just read it.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.inkSoft, fontSize: 15),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: () => _speak(item.simplified, audioUrl: item.audioUrl),
            icon: const Icon(Icons.volume_up_rounded),
            label: const Text('Hear it again'),
          ),
        ],
      ),
    );
  }

  Widget _explainStage(MandarinCourseLesson lesson) => _LessonPage(
    key: const ValueKey('explain'),
    eyebrow: 'The idea',
    title: 'What this lesson is teaching',
    footer: _LessonNavFooter(
      onBack: _canGoBack(lesson) ? () => _previousStage(lesson) : null,
      continueLabel: lesson.dialogue.isNotEmpty
          ? 'Hear the conversation'
          : 'Now you say it',
      onContinue: () => _nextStage(lesson),
    ),
    child: ListView(
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
          _SpeakablePhraseCard(
            chinese: pattern.chinese,
            pinyin: pattern.pinyin,
            english: pattern.english,
            onListen: () => _speak(
              pattern.chinese,
              audioUrl:
                  pattern.audioUrl ??
                  _audioUrlForChinese(lesson, pattern.chinese) ??
                  _audioUrlForChinese(lesson, pattern.pattern),
            ),
          ),
        ],
        for (final example in lesson.examples) ...[
          const SizedBox(height: 14),
          _SpeakablePhraseCard(
            chinese: example.chinese,
            pinyin: example.pinyin,
            english: example.english,
            onListen: () => _speak(
              example.chinese,
              audioUrl:
                  example.audioUrl ??
                  _audioUrlForChinese(lesson, example.chinese),
            ),
          ),
        ],
        if (lesson.sequence == 2) ...[
          const SizedBox(height: 22),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            child: const WarmAssetImage(
              'assets/mandarin/four_tones_diagram.png',
            ),
          ),
        ],
      ],
    ),
  );

  Widget _dialogueStage(MandarinCourseLesson lesson) {
    final line = lesson.dialogue[_index];
    return _LessonPage(
      key: ValueKey('dialogue-${line.id}'),
      eyebrow: 'Dialogue ${_index + 1} of ${lesson.dialogue.length}',
      title: 'Hear it in a short conversation',
      footer: _LessonNavFooter(
        onBack: _canGoBack(lesson)
            ? () => _previousItemOrStage(lesson.dialogue.length, lesson)
            : null,
        continueLabel: _index + 1 >= lesson.dialogue.length
            ? 'Now you say it'
            : 'Next line',
        onContinue: () => _nextItemOrStage(lesson.dialogue.length, lesson),
      ),
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
        ],
      ),
    );
  }

  Widget _practiceStage(MandarinCourseLesson lesson) {
    final item = lesson.activities[_index];
    return _QuestionStage(
      key: ValueKey('practice-${item.id}'),
      eyebrow: 'Practice ${_index + 1} of ${lesson.activities.length}',
      title: 'Try this one',
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
      onBack: _canGoBack(lesson)
          ? () => _previousItemOrStage(lesson.activities.length, lesson)
          : null,
    );
  }

  Widget _questStage(MandarinCourseLesson lesson) {
    final item = lesson.assessment[_index];
    return _QuestionStage(
      key: ValueKey('quest-${item.id}'),
      eyebrow: 'Quest ${_index + 1} of ${lesson.assessment.length}',
      title: 'Check what you remember',
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
      onBack: _canGoBack(lesson)
          ? () => _previousItemOrStage(lesson.assessment.length, lesson)
          : null,
    );
  }

  Widget _resultStage(MandarinCourseLesson lesson) {
    final total = lesson.assessment.length;
    final score = total == 0 ? 100 : ((_questCorrect / total) * 100).round();
    if (!_saved && !_saving && SupabaseService.instance.isInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _save(lesson));
    }
    return _LessonPage(
      key: const ValueKey('result'),
      eyebrow: 'Finished',
      title: 'This lesson is complete',
      footer: _ContinueButton(
        label: 'Back to my path',
        onTap: () => context.go('/student/path'),
      ),
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

class _StageStrip extends StatelessWidget {
  final List<_FoundationStage> stages;
  final _FoundationStage current;

  const _StageStrip({required this.stages, required this.current});

  static const _labels = {
    _FoundationStage.warmup: 'Warm-up',
    _FoundationStage.character: 'Words',
    _FoundationStage.explain: 'Idea',
    _FoundationStage.dialogue: 'Talk',
    _FoundationStage.speak: 'Say',
    _FoundationStage.practice: 'Practice',
    _FoundationStage.quest: 'Quest',
    _FoundationStage.result: 'Done',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < stages.length; i++) ...[
              if (i > 0)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '·',
                    style: TextStyle(color: AppColors.inkSoft, fontSize: 11),
                  ),
                ),
              Text(
                _labels[stages[i]] ?? '',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: stages[i] == current
                      ? FontWeight.w800
                      : FontWeight.w500,
                  color: stages[i] == current
                      ? AppColors.cinnabar
                      : AppColors.inkSoft,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LessonPage extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? hint;
  final Widget child;
  final Widget? footer;

  const _LessonPage({
    super.key,
    required this.eyebrow,
    required this.title,
    this.hint,
    required this.child,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.cinnabar,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(fontSize: 26),
              ),
              if (hint != null) ...[
                const SizedBox(height: 8),
                Text(
                  hint!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: child,
          ),
        ),
        if (footer != null)
          DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.paper,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: footer,
            ),
          ),
      ],
    );
  }
}

class _QuestionStage extends StatelessWidget {
  final String eyebrow;
  final String title;
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
  final VoidCallback? onBack;

  const _QuestionStage({
    super.key,
    required this.eyebrow,
    required this.title,
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
    this.onBack,
  });

  @override
  Widget build(BuildContext context) => _LessonPage(
    eyebrow: eyebrow,
    title: title,
    footer: answered
        ? _LessonNavFooter(
            onBack: onBack,
            continueLabel: 'Continue',
            onContinue: onNext,
          )
        : (onBack == null
              ? null
              : Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Back'),
                  ),
                )),
    child: ListView(
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

class _SpeakablePhraseCard extends StatelessWidget {
  final String chinese;
  final String pinyin;
  final String english;
  final VoidCallback onListen;

  const _SpeakablePhraseCard({
    required this.chinese,
    required this.pinyin,
    required this.english,
    required this.onListen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundAlt,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chinese,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  pinyin,
                  style: const TextStyle(
                    color: AppColors.cinnabar,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(english),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Listen',
            onPressed: onListen,
            icon: const Icon(
              Icons.volume_up_rounded,
              color: AppColors.cinnabar,
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonNavFooter extends StatelessWidget {
  final VoidCallback? onBack;
  final String continueLabel;
  final VoidCallback? onContinue;

  const _LessonNavFooter({
    this.onBack,
    required this.continueLabel,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    if (onBack == null) {
      return _ContinueButton(label: continueLabel, onTap: onContinue);
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: FilledButton(
            onPressed: onContinue,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(continueLabel),
          ),
        ),
      ],
    );
  }
}

class _ContinueButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _ContinueButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Text(label),
    ),
  );
}

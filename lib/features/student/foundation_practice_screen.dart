import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_state.dart';
import '../../models/mandarin_content.dart';
import '../../services/mandarin_audio_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/error_boundary.dart';

class FoundationPracticeScreen extends ConsumerWidget {
  const FoundationPracticeScreen({super.key});

  List<MandarinVocabItem> _unlockedWords(
    MandarinCourse course,
    Set<String> completedLessonIds,
  ) {
    final lessons = [...course.lessons]
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    final unique = <String, MandarinVocabItem>{};
    for (final lesson in lessons) {
      if (!lesson.isPlayable ||
          !isFoundationLessonUnlocked(lesson, completedLessonIds, lessons)) {
        continue;
      }
      for (final word in lesson.vocabulary) {
        if (word.reviewStatus != ReviewStatus.approved &&
            word.reviewStatus != ReviewStatus.corrected) {
          continue;
        }
        unique.putIfAbsent('${word.simplified}|${word.pinyin}', () => word);
      }
    }
    return unique.values.toList(growable: false);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = ref.watch(mandarinCourseProvider);
    final completedLessonIds =
        ref
            .watch(foundationCompletedLessonIdsProvider)
            .whenOrNull(data: (ids) => ids) ??
        const <String>{};
    return ShellScrollView(
      children: [
        Text('Daily review', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'Eight unlocked words: half older, half newer. Listen, then pick the meaning.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 22),
        course.when(
          loading: () => const LoadingIndicator(message: 'Loading your words…'),
          error: (error, _) => ErrorDisplay(
            message: 'Practice could not be loaded.',
            error: error,
            onRetry: () => ref.invalidate(mandarinCourseProvider),
          ),
          data: (value) {
            final words = _unlockedWords(value, completedLessonIds);
            if (words.isEmpty) {
              return const Text(
                'Finish Lesson 1 to unlock your first review words.',
              );
            }
            return _DailyReviewSession(
              key: ValueKey(words.map((word) => word.id).join('|')),
              words: words,
            );
          },
        ),
      ],
    );
  }
}

class _DailyReviewSession extends StatefulWidget {
  final List<MandarinVocabItem> words;

  const _DailyReviewSession({super.key, required this.words});

  @override
  State<_DailyReviewSession> createState() => _DailyReviewSessionState();
}

class _DailyReviewSessionState extends State<_DailyReviewSession> {
  static const _sessionSize = 8;
  late List<MandarinVocabItem> _session;
  int _index = 0;
  int _correct = 0;
  String? _selected;
  bool _answered = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _session = _pickSession(widget.words);
    _done = _session.isEmpty;
  }

  List<MandarinVocabItem> _pickSession(List<MandarinVocabItem> words) {
    if (words.length <= _sessionSize) return [...words];
    final oldCount = (words.length / 2).floor().clamp(1, words.length - 1);
    final older = words.sublist(0, oldCount);
    final newer = words.sublist(oldCount);
    final day = DateTime.now().toIso8601String().substring(0, 10);
    List<MandarinVocabItem> rotate(List<MandarinVocabItem> list, int extra) {
      if (list.isEmpty) return const [];
      final shift =
          (day.codeUnits.fold<int>(0, (sum, c) => sum + c) + extra) %
          list.length;
      return [...list.skip(shift), ...list.take(shift)];
    }

    final picked = <MandarinVocabItem>[
      ...rotate(older, 1).take(4),
      ...rotate(newer, 3).take(4),
    ];
    if (picked.length < _sessionSize) {
      for (final word in rotate(words, 5)) {
        if (picked.length >= _sessionSize) break;
        if (!picked.contains(word)) picked.add(word);
      }
    }
    return picked.take(_sessionSize).toList(growable: false);
  }

  List<String> _options(MandarinVocabItem word) {
    final pool =
        widget.words
            .where((item) => item.english != word.english)
            .map((item) => item.english)
            .toSet()
            .toList()
          ..sort();
    final distractors = <String>[];
    if (pool.isNotEmpty) {
      var cursor =
          word.id.codeUnits.fold<int>(0, (sum, c) => sum + c) % pool.length;
      final step =
          1 + (word.simplified.codeUnits.fold<int>(0, (sum, c) => sum + c) % 5);
      var guard = 0;
      while (distractors.length < 3 &&
          distractors.length < pool.length &&
          guard < pool.length * 3) {
        final next = pool[cursor % pool.length];
        if (!distractors.contains(next)) distractors.add(next);
        cursor += step;
        guard++;
      }
    }
    final options = [word.english, ...distractors];
    final shift =
        (word.id.codeUnits.fold<int>(0, (sum, c) => sum + c) + _index) %
        options.length;
    return [...options.skip(shift), ...options.take(shift)];
  }

  void _restart() {
    setState(() {
      _session = _pickSession(widget.words);
      _index = 0;
      _correct = 0;
      _selected = null;
      _answered = false;
      _done = _session.isEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return _SessionResult(
        correct: _correct,
        total: _session.length,
        onAgain: _restart,
      );
    }
    final word = _session[_index];
    final options = _options(word);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Card ${_index + 1} of ${_session.length}',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: AppColors.cinnabar),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppColors.ink.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              Text(
                word.simplified,
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                word.pinyin,
                style: const TextStyle(
                  color: AppColors.cinnabar,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => MandarinAudioService.instance.play(
                  text: word.simplified,
                  audioUrl: word.audioUrl,
                  rate: 0.8,
                ),
                icon: const Icon(Icons.volume_up_rounded),
                label: const Text('Listen'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text('What does it mean?'),
        const SizedBox(height: 10),
        for (final option in options) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OutlinedButton(
              onPressed: _answered
                  ? null
                  : () => setState(() {
                      _selected = option;
                      _answered = true;
                      if (option == word.english) _correct++;
                    }),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                side: BorderSide(
                  color: !_answered || _selected != option
                      ? AppColors.line
                      : option == word.english
                      ? AppColors.jade
                      : AppColors.cinnabar,
                  width: 1.5,
                ),
              ),
              child: Text(
                option,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
        if (_answered) ...[
          Text(
            _selected == word.english
                ? 'Yes — ${word.english}.'
                : 'It means ${word.english}.',
            style: TextStyle(
              color: _selected == word.english
                  ? AppColors.jade
                  : AppColors.cinnabar,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => setState(() {
              if (_index + 1 >= _session.length) {
                _done = true;
              } else {
                _index++;
                _selected = null;
                _answered = false;
              }
            }),
            child: Text(
              _index + 1 >= _session.length ? 'See today’s score' : 'Next word',
            ),
          ),
        ],
      ],
    );
  }
}

class _SessionResult extends StatelessWidget {
  final int correct;
  final int total;
  final VoidCallback onAgain;

  const _SessionResult({
    required this.correct,
    required this.total,
    required this.onAgain,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$correct of $total right',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Come back tomorrow. A foundation is the same words, used again.',
        ),
        const SizedBox(height: 18),
        FilledButton(onPressed: onAgain, child: const Text('Practise again')),
      ],
    );
  }
}

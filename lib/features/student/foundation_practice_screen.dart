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
        Text('Word practice', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'Practise words from the lessons you have unlocked.',
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
            final lessons = [...value.lessons]
              ..sort((a, b) => a.sequence.compareTo(b.sequence));
            final reviewedWords = lessons
                .where(
                  (lesson) =>
                      lesson.isPlayable &&
                      isFoundationLessonUnlocked(
                        lesson,
                        completedLessonIds,
                        lessons,
                      ),
                )
                .expand((lesson) => lesson.vocabulary)
                .where(
                  (word) =>
                      word.reviewStatus == ReviewStatus.approved ||
                      word.reviewStatus == ReviewStatus.corrected,
                )
                .toList(growable: false);
            final uniqueWords = <String, MandarinVocabItem>{};
            for (final word in reviewedWords) {
              uniqueWords.putIfAbsent(
                '${word.simplified}|${word.pinyin}',
                () => word,
              );
            }
            final words = uniqueWords.values.toList(growable: false);
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [for (final word in words) _WordCard(word: word)],
            );
          },
        ),
      ],
    );
  }
}

class _WordCard extends StatelessWidget {
  final MandarinVocabItem word;

  const _WordCard({required this.word});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: MediaQuery.sizeOf(context).width < 520 ? double.infinity : 220,
    child: Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: () => MandarinAudioService.instance.play(
          text: word.simplified,
          audioUrl: word.audioUrl,
          rate: 0.8,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppColors.ink.withValues(alpha: 0.10)),
          ),
          child: Column(
            children: [
              Text(
                word.simplified,
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                word.pinyin,
                style: const TextStyle(
                  color: AppColors.cinnabar,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(word.english, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              const Icon(Icons.volume_up_rounded, color: AppColors.jade),
            ],
          ),
        ),
      ),
    ),
  );
}

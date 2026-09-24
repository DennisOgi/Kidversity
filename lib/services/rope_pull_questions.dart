import 'dart:math';

import '../models/mandarin_content.dart';
import '../models/past_questions_models.dart';
import '../models/rope_pull_models.dart';

List<MandarinVocabItem> vocabForRopeBank({
  required MandarinCourse course,
  required RopePullBank bank,
  required Set<String> completedLessonIds,
}) {
  final lessons = [...course.lessons]
    ..sort((a, b) => a.sequence.compareTo(b.sequence));
  bool include(MandarinCourseLesson lesson) {
    if (!lesson.isPlayable) return false;
    switch (bank) {
      case RopePullBank.lessons15:
        return lesson.sequence >= 1 && lesson.sequence <= 5;
      case RopePullBank.module1:
        return lesson.sequence >= 1 && lesson.sequence <= 10;
      case RopePullBank.dailyReview:
        return isFoundationLessonUnlocked(lesson, completedLessonIds, lessons);
      case RopePullBank.pastQuestions:
      case RopePullBank.maths:
        return false;
    }
  }

  final unique = <String, MandarinVocabItem>{};
  for (final lesson in lessons.where(include)) {
    for (final word in lesson.vocabulary) {
      if (word.reviewStatus != ReviewStatus.approved &&
          word.reviewStatus != ReviewStatus.corrected) {
        continue;
      }
      unique.putIfAbsent('${word.simplified}|${word.pinyin}', () => word);
    }
  }
    final words = unique.values.toList();
  if (words.length < 4 &&
      bank != RopePullBank.lessons15 &&
      bank != RopePullBank.pastQuestions &&
      bank != RopePullBank.maths) {
    return vocabForRopeBank(
      course: course,
      bank: RopePullBank.lessons15,
      completedLessonIds: completedLessonIds,
    );
  }
  return words;
}

/// Host-only deck. Guests never call the question API; the room stores this list.
List<RopePullQuestion> packSplitDeck(
  List<RopePullQuestion> questions, {
  required String kind,
  int limit = 40,
}) {
  var deck = questions.take(limit.clamp(4, 40)).toList();
  if (deck.length.isOdd) deck = deck.sublist(0, deck.length - 1);
  if (deck.length < 4) return deck;
  return [
    for (var i = 0; i < deck.length; i++)
      deck[i].copyWith(split: i == 0, kind: kind),
  ];
}

/// Both teams answer the same question each round, capped at ten rounds.
List<RopePullQuestion> sharedRopeDeck(List<RopePullQuestion> questions) => [
  for (final question in questions.take(10)) question.copyWith(split: false),
];

List<RopePullQuestion> buildPastQuestionRopeDeck(
  List<PastQuestion> questions, {
  int limit = 10,
}) {
  final deck = <RopePullQuestion>[];
  for (final item in questions) {
    if (item.options.length < 2) continue;
    final options = <String>[];
    String? answer;
    for (final option in item.options) {
      final text = option.text.trim();
      if (text.isEmpty) continue;
      final label = '${option.key.toUpperCase()}. $text';
      options.add(label);
      if (option.key == item.answerKey) answer = label;
    }
    if (options.length < 2 || answer == null) continue;
    final stem = item.question.trim();
    if (stem.isEmpty) continue;
    deck.add(
      RopePullQuestion(
        id: 'pq-${item.id}',
        simplified: '',
        pinyin: '',
        english: item.examYear,
        options: options,
        answer: answer,
        prompt: stem,
        solution: item.solution?.trim(),
      ),
    );
    if (deck.length == limit.clamp(4, 40)) break;
  }
  return packSplitDeck(deck, kind: 'exam', limit: limit);
}

List<RopePullQuestion> buildRopePullQuestions(
  List<MandarinVocabItem> words, {
  int count = 10,
  int optionCount = 4,
  int Function(int max)? nextInt,
}) {
  if (words.length < 4) return const [];
  final rng = Random();
  final pick = nextInt ?? rng.nextInt;
  final pool = [...words];
  _shuffle(pool, pick);
  final take = pool.take(count.clamp(4, 10)).toList();
  return [
    for (final word in take)
      RopePullQuestion(
        id: word.id,
        simplified: word.simplified,
        pinyin: word.pinyin,
        english: word.english,
        answer: word.english,
        audioUrl: word.audioUrl,
        options: _optionsFor(word, pool, optionCount, pick),
      ),
  ];
}

List<String> _optionsFor(
  MandarinVocabItem word,
  List<MandarinVocabItem> pool,
  int optionCount,
  int Function(int max) nextInt,
) {
  final distractors = pool
      .where((item) => item.english != word.english)
      .map((item) => item.english)
      .toSet()
      .toList();
  _shuffle(distractors, nextInt);
  final options = [word.english, ...distractors.take(optionCount - 1)];
  _shuffle(options, nextInt);
  return options;
}

void _shuffle<T>(List<T> list, int Function(int max) nextInt) {
  for (var i = list.length - 1; i > 0; i--) {
    final j = nextInt(i + 1);
    final temp = list[i];
    list[i] = list[j];
    list[j] = temp;
  }
}

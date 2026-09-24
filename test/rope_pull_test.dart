import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidversity/models/mandarin_content.dart';
import 'package:kidversity/models/models.dart';
import 'package:kidversity/models/past_questions_models.dart';
import 'package:kidversity/models/rope_pull_models.dart';
import 'package:kidversity/router/navigation.dart';
import 'package:kidversity/services/rope_pull_questions.dart';
import 'package:kidversity/widgets/rope_pull_arena.dart';

void main() {
  test('student play routes stay in the student space', () {
    expect(roleFromPath('/student/play'), UserRole.student);
    expect(isProtectedRoute('/student/rope/abc'), isTrue);
    expect(AppRoutes.studentRope('room-1'), '/student/rope/room-1');
  });

  test('rope pull questions stay inside the word bank', () {
    final words = [
      for (var i = 0; i < 12; i++)
        MandarinVocabItem(
          id: 'w$i',
          simplified: '字$i',
          pinyin: 'zi$i',
          english: 'word$i',
        ),
    ];
    final questions = buildRopePullQuestions(
      words,
      nextInt: Random(42).nextInt,
    );
    expect(questions, hasLength(10));
    final answerSlots = <int>{};
    for (final question in questions) {
      expect(question.options, hasLength(4));
      expect(question.options, contains(question.answer));
      expect(question.options.toSet(), hasLength(4));
      answerSlots.add(question.options.indexOf(question.answer));
    }
    expect(
      answerSlots.length,
      greaterThan(1),
      reason: 'the correct meaning should not sit on the same tile every round',
    );
  });

  test('clock-style shuffle parks every answer on the same tile', () {
    final words = [
      for (var i = 0; i < 12; i++)
        MandarinVocabItem(
          id: 'w$i',
          simplified: '字$i',
          pinyin: 'zi$i',
          english: 'word$i',
        ),
    ];
    final questions = buildRopePullQuestions(words, nextInt: (max) => 0);
    final slots = {
      for (final question in questions)
        question.options.indexOf(question.answer),
    };
    expect(slots.length, 1);
  });

  test('mobile courtyard keeps both foxes and the knot on screen', () {
    for (final pull in [-1.0, 0.0, 1.0]) {
      final layout = RopePullArenaLayout.of(
        width: 360,
        height: 210,
        pull: pull,
      );
      expect(layout.leftFoxX, greaterThanOrEqualTo(-2));
      expect(layout.rightFoxX + layout.foxW, lessThanOrEqualTo(362));
      expect(
        layout.knotX,
        inInclusiveRange(layout.knotSize / 2, 360 - layout.knotSize / 2),
      );
      expect(layout.leftHand.dx, lessThan(layout.knotX));
      expect(layout.rightHand.dx, greaterThan(layout.knotX));
    }
  });

  testWidgets('courtyard arena shows blue and red seals', (tester) async {
    const snap = RopePullSnapshot(
      room: RopePullRoom(
        id: 'r1',
        hostId: 'h1',
        joinCode: 'MCXK',
        bank: RopePullBank.lessons15,
        status: RopePullStatus.lobby,
        currentRound: 0,
        ropeScore: -2,
        questions: [],
      ),
      players: [
        RopePullPlayer(
          userId: '1',
          displayName: 'Olala',
          avatar: '🦊',
          team: 'blue',
        ),
        RopePullPlayer(
          userId: '2',
          displayName: 'Friend',
          avatar: '🐼',
          team: 'red',
        ),
      ],
      answers: [],
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RopePullArena(snapshot: snap, height: 240)),
      ),
    );
    await tester.pump();
    expect(find.text('Blue'), findsOneWidget);
    expect(find.text('Red'), findsOneWidget);
  });

  test('rope score names a winner', () {
    RopePullSnapshot snap(int score) => RopePullSnapshot(
      room: RopePullRoom(
        id: 'r1',
        hostId: 'h1',
        joinCode: 'MCXK',
        bank: RopePullBank.lessons15,
        status: RopePullStatus.finished,
        currentRound: 9,
        ropeScore: score,
        questions: const [],
      ),
      players: const [],
      answers: const [],
    );
    expect(snap(-3).outcome, RopePullOutcome.blue);
    expect(snap(4).outcome, RopePullOutcome.red);
    expect(snap(0).outcome, RopePullOutcome.draw);
  });

  testWidgets('hub banner names the game', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RopePullHubBanner())),
    );
    await tester.pump();
    expect(find.text('Rope Pull'), findsOneWidget);
    expect(
      find.text('Words, past questions, or mental maths.'),
      findsOneWidget,
    );
  });

  test('past-question decks keep the correct option and stop at ten', () {
    final questions = [
      for (var i = 0; i < 12; i++)
        PastQuestion(
          id: i,
          question: 'Question $i',
          options: const [
            PastQuestionOption(key: 'a', text: 'One'),
            PastQuestionOption(key: 'b', text: 'Two'),
          ],
          answerKey: 'b',
          examType: 'utme',
          examYear: '2020',
          solution: 'Because two.',
        ),
    ];
    final deck = buildPastQuestionRopeDeck(questions);
    expect(deck, hasLength(10));
    expect(deck.first.prompt, 'Question 0');
    expect(deck.first.answer, 'B. Two');
    expect(deck.first.solution, 'Because two.');
    expect(deck.first.isExamPrompt, isTrue);
  });

  test('fallback decks give both teams the same question', () {
    final questions = [
      for (var i = 0; i < 20; i++)
        PastQuestion(
          id: i,
          question: 'Question $i',
          options: const [
            PastQuestionOption(key: 'a', text: 'One'),
            PastQuestionOption(key: 'b', text: 'Two'),
          ],
          answerKey: 'b',
          examType: 'utme',
          examYear: '2020',
        ),
    ];
    final split = buildPastQuestionRopeDeck(questions, limit: 20);
    expect(split.first.split, isTrue);
    final shared = sharedRopeDeck(split);
    expect(shared, hasLength(10));
    expect(shared.any((question) => question.split), isFalse);
  });
}

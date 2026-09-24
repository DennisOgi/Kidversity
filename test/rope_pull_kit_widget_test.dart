import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidversity/models/rope_pull_models.dart';
import 'package:kidversity/widgets/rope_arena.dart';
import 'package:kidversity/widgets/rope_pull_stage.dart';

const _question = RopePullQuestion(
  id: 'q1',
  simplified: '你好',
  pinyin: 'nǐ hǎo',
  english: 'hello',
  options: ['hello', 'bye', 'thanks', 'please'],
  answer: 'hello',
);

RopePullSnapshot _playingSnap() {
  return const RopePullSnapshot(
    room: RopePullRoom(
      id: 'room-1',
      hostId: 'host',
      joinCode: 'ACEF',
      bank: RopePullBank.lessons15,
      status: RopePullStatus.playing,
      currentRound: 0,
      ropeScore: -2,
      questions: [_question],
    ),
    players: [
      RopePullPlayer(
        userId: 'blue-1',
        displayName: 'Ada',
        avatar: '🦊',
        team: 'blue',
      ),
      RopePullPlayer(
        userId: 'red-1',
        displayName: 'Tunde',
        avatar: '🐼',
        team: 'red',
      ),
    ],
    answers: [],
  );
}

void main() {
  testWidgets('kit arena loads cutouts and exposes a live summary', (
    tester,
  ) async {
    final controller = RopeArenaController();
    addTearDown(controller.dispose);
    controller.applyState(
      position: -0.4,
      phase: RopePhase.playing,
      indigoScore: 2,
      tealScore: 1,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RopeArena(controller: controller)),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('could not load'), findsNothing);
    expect(controller.summary.value, 'Indigo 2, Teal 1. playing');
  });

  testWidgets('kit arena offers retry after a failed decode', (tester) async {
    final controller = RopeArenaController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RopeArena(
            controller: controller,
            assetRoot: 'assets/missing_rope_kit',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('not in this running app'), findsOneWidget);
    expect(find.text('Retry assets'), findsOneWidget);
  });

  testWidgets('class board shows both team prompts without submit controls', (
    tester,
  ) async {
    final controller = RopeArenaController();
    addTearDown(controller.dispose);
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RopePullStage(
            snap: _playingSnap(),
            controller: controller,
            remaining: 8,
            seconds: 10,
            reveal: false,
            blueQuestion: _question,
            redQuestion: _question,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Indigo'), findsOneWidget);
    expect(find.text('Teal'), findsOneWidget);
    expect(find.text('hello'), findsWidgets);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('reduced motion snaps the rope without a running ticker', (
    tester,
  ) async {
    final controller = RopeArenaController();
    addTearDown(controller.dispose);
    controller.setReducedMotion(true);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(body: RopeArena(controller: controller)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    controller.applyState(
      position: 0.8,
      phase: RopePhase.playing,
      indigoScore: 0,
      tealScore: 4,
      snap: false,
    );
    await tester.pump();
    expect(controller.displayPosition, 0.8);
    expect(controller.reducedMotion, isTrue);
  });
}

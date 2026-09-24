import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidversity/models/rope_pull_models.dart';
import 'package:kidversity/widgets/rope_arena.dart';
import 'package:kidversity/widgets/rope_pull_visual_adapter.dart';

const _longPrompt =
    'A very long exam prompt that must stay outside the canvas and wrap on a phone without covering the rope: explain why the first correct tug still belongs to the server, then restating the stem again so two-hundred percent text has something to measure.';

RopePullSnapshot _snap({int score = -2}) {
  return RopePullSnapshot(
    room: RopePullRoom(
      id: 'room-1',
      hostId: 'host',
      joinCode: 'ACEF',
      bank: RopePullBank.pastQuestions,
      status: RopePullStatus.playing,
      currentRound: 0,
      ropeScore: score,
      questions: const [
        RopePullQuestion(
          id: 'q1',
          simplified: 'exam',
          pinyin: '',
          english: '',
          options: ['A', 'B', 'C', 'D'],
          answer: 'B',
          prompt: _longPrompt,
        ),
      ],
    ),
    players: const [
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
    answers: const [],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('viewports, long prompt, 200% text, reconnect restore', (
    tester,
  ) async {
    final controller = RopeArenaController();
    addTearDown(controller.dispose);
    controller.setReducedMotion(true);
    final adapter = RopePullVisualAdapter(controller);
    final live = _snap();
    adapter.applySnapshot(live, remainingMs: 18000);

    Future<void> show(Size size, {double textScale = 1}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: TickerMode(
            enabled: false,
            child: MaterialApp(
              home: Scaffold(
                body: RepaintBoundary(
                  key: const ValueKey('rope-verify'),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        const Text(
                          'INDIGO  ·  TEAL',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        RopePullKitScene(
                          controller: controller,
                          maxHeight: size.height < 900 ? 180 : 280,
                        ),
                        const SizedBox(height: 8),
                        const Expanded(
                          child: SingleChildScrollView(
                            child: Text(_longPrompt),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    await show(const Size(390, 844));
    expect(find.textContaining('INDIGO'), findsOneWidget);
    expect(find.textContaining('long exam prompt'), findsOneWidget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('could not load'), findsNothing);

    await show(const Size(768, 1024));
    expect(find.textContaining('INDIGO'), findsOneWidget);

    await show(const Size(1366, 768));
    expect(find.textContaining('long exam prompt'), findsOneWidget);

    await show(const Size(1920, 1080));
    expect(find.textContaining('INDIGO'), findsOneWidget);

    await show(const Size(390, 844), textScale: 2);
    expect(find.textContaining('INDIGO'), findsOneWidget);

    adapter.applySnapshot(live, reconnecting: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(controller.phase, RopePhase.reconnecting);
    expect(controller.targetPosition, ropePullKitPosition(live));

    adapter.applySnapshot(live);
    expect(controller.phase, RopePhase.playing);
    expect(controller.displayPosition, controller.targetPosition);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:kidversity/models/rope_pull_models.dart';
import 'package:kidversity/widgets/rope_arena.dart';
import 'package:kidversity/widgets/rope_pull_visual_adapter.dart';

RopePullSnapshot _snap({
  RopePullStatus status = RopePullStatus.playing,
  int round = 0,
  int score = 0,
  List<RopePullAnswer> answers = const [],
  List<RopePullQuestion> questions = const [],
  String id = 'room-1',
}) {
  return RopePullSnapshot(
    room: RopePullRoom(
      id: id,
      hostId: 'host',
      joinCode: 'ACEF',
      bank: RopePullBank.lessons15,
      status: status,
      currentRound: round,
      ropeScore: score,
      questions: questions,
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
    answers: answers,
  );
}

void main() {
  test('kit position uses authoritative rope score and display cap', () {
    expect(ropePullKitPosition(_snap(score: -10)), -1);
    expect(ropePullKitPosition(_snap(score: 5)), 0.5);
    expect(ropePullKitPosition(_snap(score: 0)), 0);
    expect(ropePullWinCap(_snap().room), 10);
  });

  test('adapter rejects duplicate and out-of-order sequences', () {
    final cues = <String>[];
    final controller = RopeArenaController(onCue: cues.add);
    addTearDown(controller.dispose);
    final adapter = RopePullVisualAdapter(controller);

    final first = _snap(
      score: -1,
      answers: const [
        RopePullAnswer(
          userId: 'blue-1',
          roundIndex: 0,
          selected: 'hello',
          isCorrect: true,
        ),
      ],
    );
    expect(adapter.applySnapshot(first), isTrue);
    expect(adapter.applySnapshot(first), isFalse);

    final older = _snap();
    expect(
      ropePullVisualSequence(older),
      lessThan(ropePullVisualSequence(first)),
    );
    expect(adapter.applySnapshot(older), isFalse);
    expect(controller.targetPosition, -0.1);
  });

  test('first snapshot never replays confirmed answers as cues', () {
    final cues = <String>[];
    final controller = RopeArenaController(onCue: cues.add);
    addTearDown(controller.dispose);
    final adapter = RopePullVisualAdapter(controller);

    final snap = _snap(
      score: -1,
      answers: const [
        RopePullAnswer(
          userId: 'blue-1',
          roundIndex: 0,
          selected: 'hello',
          isCorrect: true,
        ),
      ],
    );
    expect(adapter.applySnapshot(snap), isTrue);
    expect(cues, isEmpty);
    expect(controller.indigoScore, 1);
    expect(controller.tealScore, 0);
  });

  test('new confirmed answers fire feedback once and never guess a pull', () {
    final cues = <String>[];
    final controller = RopeArenaController(onCue: cues.add);
    addTearDown(controller.dispose);
    final adapter = RopePullVisualAdapter(controller);

    expect(adapter.applySnapshot(_snap()), isTrue);
    expect(controller.indigoScore, 0);
    expect(adapter.applySnapshot(_snap()), isFalse);
    expect(controller.indigoScore, 0);

    final confirmed = _snap(
      score: -1,
      answers: const [
        RopePullAnswer(
          userId: 'blue-1',
          roundIndex: 0,
          selected: 'hello',
          isCorrect: true,
        ),
      ],
    );
    expect(adapter.applySnapshot(confirmed), isTrue);
    expect(cues, ['correct']);
    expect(controller.indigoScore, 1);
    expect(adapter.applySnapshot(confirmed), isFalse);
    expect(cues, ['correct']);
  });

  test('reconnect snaps position and does not replay cues', () {
    final cues = <String>[];
    final controller = RopeArenaController(onCue: cues.add);
    addTearDown(controller.dispose);
    final adapter = RopePullVisualAdapter(controller);

    final live = _snap(
      score: -3,
      answers: const [
        RopePullAnswer(
          userId: 'blue-1',
          roundIndex: 0,
          selected: 'hello',
          isCorrect: true,
        ),
      ],
    );
    adapter.applySnapshot(live);
    adapter.applySnapshot(live, reconnecting: true);
    expect(controller.phase, RopePhase.reconnecting);
    cues.clear();

    expect(adapter.applySnapshot(live), isTrue);
    expect(controller.phase, RopePhase.playing);
    expect(controller.displayPosition, controller.targetPosition);
    expect(cues, isEmpty);
  });

  test('finished draw leaves winner unset', () {
    final controller = RopeArenaController();
    addTearDown(controller.dispose);
    final adapter = RopePullVisualAdapter(controller);
    adapter.applySnapshot(_snap(status: RopePullStatus.finished, score: 0));
    expect(controller.phase, RopePhase.finished);
    expect(controller.winner, isNull);
  });
}

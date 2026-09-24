import 'dart:math' as math;

import '../models/rope_pull_models.dart';
import 'rope_arena.dart';

/// Display-only win cap so kit position stays in [-1, 1].
/// Does not change server scoring or finish rules.
int ropePullWinCap(RopePullRoom room) {
  if (room.isExamMatch) {
    final n = math.max(1, room.roundCount);
    if (room.isSplit) return math.max(10, math.min(20, n));
    return math.min(40, n);
  }
  return 10;
}

/// Authoritative kit position from server `rope_score`.
/// Negative score = indigo (blue) toward the indigo goal.
double ropePullKitPosition(RopePullSnapshot snap) {
  final cap = ropePullWinCap(snap.room);
  if (cap <= 0) return 0;
  return (snap.room.ropeScore / cap).clamp(-1.0, 1.0);
}

int ropePullVisualSequence(RopePullSnapshot snap) {
  final statusWeight = switch (snap.room.status) {
    RopePullStatus.lobby => 0,
    RopePullStatus.playing => 1,
    RopePullStatus.finished => 2,
  };
  return statusWeight * 1000000 +
      snap.room.currentRound * 10000 +
      snap.answers.length * 100 +
      (snap.room.ropeScore + 50);
}

RopeTeam? ropePullKitWinner(RopePullSnapshot snap) {
  if (snap.room.status != RopePullStatus.finished) return null;
  return switch (snap.outcome) {
    RopePullOutcome.blue => RopeTeam.indigo,
    RopePullOutcome.red => RopeTeam.teal,
    RopePullOutcome.draw => null,
  };
}

/// Maps authoritative room snapshots onto [RopeArenaController].
/// Rejects duplicate / out-of-order sequences. Never awards a pull locally.
class RopePullVisualAdapter {
  RopePullVisualAdapter(this.controller);

  final RopeArenaController controller;

  String? _roomId;
  String? _roundId;
  int _lastSequence = -1;
  RopePhase? _lastPhase;
  bool _hasApplied = false;
  final Set<String> _seenEvents = <String>{};

  bool get hasApplied => _hasApplied;
  int get lastSequence => _lastSequence;
  Set<String> get seenEvents => _seenEvents;

  void reset() {
    _roomId = null;
    _roundId = null;
    _lastSequence = -1;
    _lastPhase = null;
    _hasApplied = false;
    _seenEvents.clear();
    controller.reset();
  }

  /// Returns false when the snapshot is ignored as duplicate or stale.
  bool applySnapshot(
    RopePullSnapshot snap, {
    bool reconnecting = false,
    bool paused = false,
    int remainingMs = 0,
  }) {
    if (snap.room.id != _roomId) {
      _roomId = snap.room.id;
      _roundId = null;
      _lastSequence = -1;
      _lastPhase = null;
      _hasApplied = false;
      _seenEvents.clear();
    }

    final roundId = '${snap.room.id}:${snap.room.currentRound}';
    if (roundId != _roundId) {
      _roundId = roundId;
      _lastSequence = -1;
    }

    final sequence = ropePullVisualSequence(snap);
    final phase = _phaseOf(snap, reconnecting: reconnecting, paused: paused);
    if (sequence < _lastSequence) return false;
    if (sequence == _lastSequence && phase == _lastPhase) return false;

    final isInitial = !_hasApplied;
    final resumeAfterGap =
        _lastPhase == RopePhase.reconnecting && phase != RopePhase.reconnecting;
    if (sequence > _lastSequence) _lastSequence = sequence;
    _lastPhase = phase;
    _hasApplied = true;

    controller.applyState(
      position: ropePullKitPosition(snap),
      phase: phase,
      indigoScore: snap.blueTugs,
      tealScore: snap.redTugs,
      countdown: _countdownSeconds(remainingMs),
      winner: ropePullKitWinner(snap),
      snap: isInitial || resumeAfterGap,
    );

    final replaySafe =
        !isInitial &&
        phase != RopePhase.reconnecting &&
        phase != RopePhase.lobby;
    for (final answer in snap.answers) {
      final id = '${answer.userId}:${answer.roundIndex}';
      if (!_seenEvents.add(id)) continue;
      if (!replaySafe) continue;
      final player = snap.playerFor(answer.userId);
      if (player == null) continue;
      controller.feedback(
        player.isBlue ? RopeTeam.indigo : RopeTeam.teal,
        correct: answer.isCorrect,
      );
    }
    return true;
  }

  RopePhase _phaseOf(
    RopePullSnapshot snap, {
    required bool reconnecting,
    required bool paused,
  }) {
    if (reconnecting) return RopePhase.reconnecting;
    if (paused) return RopePhase.paused;
    return switch (snap.room.status) {
      RopePullStatus.lobby => RopePhase.lobby,
      RopePullStatus.playing => RopePhase.playing,
      RopePullStatus.finished => RopePhase.finished,
    };
  }

  int _countdownSeconds(int remainingMs) {
    if (remainingMs <= 0) return 0;
    return (remainingMs / 1000).ceil().clamp(0, 99);
  }
}

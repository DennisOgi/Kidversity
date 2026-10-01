// LOCAL DEMONSTRATION ONLY. Do not use this question bank/scoring in multiplayer.
import 'dart:async';
import 'package:flutter/material.dart';
import 'rope_arena.dart';

class RopePullDemoPage extends StatefulWidget {
  const RopePullDemoPage({super.key});
  @override
  State<RopePullDemoPage> createState() => _RopePullDemoPageState();
}

class _RopePullDemoPageState extends State<RopePullDemoPage> with WidgetsBindingObserver {
  final arena = RopeArenaController(); // Wire onCue to your existing audio service.
  final inputs = [TextEditingController(), TextEditingController()];
  final scores = [0, 0];
  final indexes = [0, 0];
  final messages = ['Start the round to answer.', 'Start the round to answer.'];
  static const questions = [
    [('10 × 5 = ?', 50), ('8 + 7 = ?', 15), ('9 × 4 = ?', 36), ('42 ÷ 6 = ?', 7), ('17 + 8 = ?', 25), ('12 × 3 = ?', 36)],
    [('7 × 6 = ?', 42), ('16 + 9 = ?', 25), ('8 × 8 = ?', 64), ('63 ÷ 7 = ?', 9), ('23 + 19 = ?', 42), ('11 × 4 = ?', 44)],
  ];
  Timer? timer;
  DateTime? deadline;
  double remaining = 60;
  int countdown = 3;

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && arena.phase == RopePhase.playing) _pause();
  }

  void _sync(RopePhase phase, {bool snap = false}) {
    arena.applyState(
      position: ((scores[1] - scores[0]) / 6).clamp(-1.0, 1.0).toDouble(),
      phase: phase,
      indigoScore: scores[0],
      tealScore: scores[1],
      countdown: countdown,
      snap: snap,
      winner: phase == RopePhase.finished && scores[0] != scores[1]
          ? (scores[0] > scores[1] ? RopeTeam.indigo : RopeTeam.teal) : null,
    );
  }

  void _start() {
    timer?.cancel();
    scores[0] = scores[1] = 0;
    indexes[0] = indexes[1] = 0;
    for (final input in inputs) { input.clear(); }
    remaining = 60;
    countdown = 3;
    messages[0] = messages[1] = 'Get ready.';
    arena.reset();
    setState(() { _sync(RopePhase.countdown, snap: true); });
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      countdown--;
      if (countdown == 0) {
        timer?.cancel();
        messages[0] = messages[1] = 'Your turn.';
        setState(() { _sync(RopePhase.playing); });
        _startClock();
      } else { setState(() { _sync(RopePhase.countdown); }); }
    });
  }

  void _startClock() {
    deadline = DateTime.now().add(Duration(milliseconds: (remaining * 1000).round()));
    timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      remaining = (deadline!.difference(DateTime.now()).inMilliseconds / 1000).clamp(0.0, 60.0).toDouble();
      if (remaining <= 0) { _finish(); } else { setState(() {}); }
    });
  }

  void _finish() {
    timer?.cancel();
    setState(() { _sync(RopePhase.finished); });
  }

  void _pause() {
    if (arena.phase == RopePhase.playing) {
      remaining = (deadline!.difference(DateTime.now()).inMilliseconds / 1000).clamp(0.0, 60.0).toDouble();
      timer?.cancel();
      setState(() { _sync(RopePhase.paused); });
    } else if (arena.phase == RopePhase.paused) {
      setState(() { _sync(RopePhase.playing); });
      _startClock();
    }
  }

  void _answer(int team) {
    if (arena.phase != RopePhase.playing) return;
    final raw = inputs[team].text.trim();
    final value = int.tryParse(raw);
    if (value == null) { setState(() { messages[team] = 'Enter a whole-number answer.'; }); return; }
    final q = questions[team][indexes[team] % questions[team].length];
    final correct = value == q.$2;
    arena.feedback(team == 0 ? RopeTeam.indigo : RopeTeam.teal, correct: correct);
    setState(() {
      messages[team] = correct ? '✓ Correct. Your team pulls ahead.' : 'Not quite. Try this question again.';
      if (correct) { scores[team]++; indexes[team]++; inputs[team].clear(); }
      _sync(RopePhase.playing);
    });
    if ((scores[0] - scores[1]).abs() >= 6) _finish();
  }

  Widget _panel(int team) {
    final color = team == 0 ? const Color(0xFF4433CC) : const Color(0xFF11646A);
    final q = questions[team][indexes[team] % questions[team].length];
    final enabled = arena.phase == RopePhase.playing;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFDADDEA)), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(team == 0 ? '◆ Indigo' : '○ Teal', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 18),
        Text(q.$1, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
        const SizedBox(height: 18),
        TextField(
          controller: inputs[team], enabled: enabled, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Your answer', border: OutlineInputBorder()),
          onSubmitted: (_) => _answer(team),
        ),
        const SizedBox(height: 12),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: color, minimumSize: const Size(48, 48)),
          onPressed: enabled ? () => _answer(team) : null, child: const Text('Submit answer'),
        ),
        const SizedBox(height: 12),
        Semantics(liveRegion: true, child: Text(messages[team])),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playing = arena.phase == RopePhase.playing;
    final paused = arena.phase == RopePhase.paused;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FB),
      appBar: AppBar(title: const Text('Kidversity · Rope Pull demo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1500),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Every answer makes a difference.', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Local sample arithmetic. Connect real questions and authoritative multiplayer state in production.'),
            const SizedBox(height: 20),
            Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
              FilledButton(onPressed: [RopePhase.lobby, RopePhase.finished].contains(arena.phase) ? _start : null,
                  child: Text(arena.phase == RopePhase.finished ? 'Play again' : 'Start round')),
              OutlinedButton(onPressed: playing || paused ? _pause : null, child: Text(paused ? 'Resume' : 'Pause')),
              Text('Indigo ${scores[0]}  ·  ${remaining.ceil()}s  ·  Teal ${scores[1]}', style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 20),
            LayoutBuilder(builder: (context, constraints) {
              final scene = RopeArena(key: const ValueKey('rope-arena'), controller: arena);
              if (constraints.maxWidth >= 1100) {
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 220, child: _panel(0)), const SizedBox(width: 16),
                  Expanded(child: scene), const SizedBox(width: 16), SizedBox(width: 220, child: _panel(1)),
                ]);
              }
              return Column(children: [scene, const SizedBox(height: 20),
                if (constraints.maxWidth >= 650) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: _panel(0)), const SizedBox(width: 16), Expanded(child: _panel(1)),
                ]) else ...[_panel(0), const SizedBox(height: 16), _panel(1)],
              ]);
            }),
            const SizedBox(height: 16),
            ValueListenableBuilder<String>(valueListenable: arena.summary,
                builder: (context, summary, _) => Semantics(liveRegion: true, child: Text(summary))),
          ]),
        )),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    for (final input in inputs) { input.dispose(); }
    arena.dispose();
    super.dispose();
  }
}

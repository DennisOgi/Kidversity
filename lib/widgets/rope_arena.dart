// Presentation kit: grip-pivot cutouts, one background, procedural rope.
// PNG transforms are not skeletal animation.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'rope_png_decode.dart';

enum RopeTeam { indigo, teal }

enum RopePhase { lobby, countdown, playing, paused, reconnecting, finished }

typedef RopeCue = void Function(String name);

const kRopeIndigo = Color(0xFF4433CC);
const kRopeTeal = Color(0xFF147D85);

class RopeArenaController extends ChangeNotifier {
  RopeArenaController({this.onCue});
  final RopeCue? onCue;
  final ValueNotifier<String> summary = ValueNotifier('Waiting for the round.');
  RopePhase phase = RopePhase.lobby;
  RopeTeam? winner;
  RopeTeam? impactTeam;
  bool impactCorrect = true;
  bool reducedMotion = false;
  double targetPosition = 0;
  double displayPosition = 0;
  double clock = 0;
  double impactAt = -100;
  double finishedAt = -100;
  int countdown = 3;
  int indigoScore = 0;
  int tealScore = 0;

  /// Negative position favours Indigo, positive favours Teal.
  /// The caller must deduplicate server snapshots/events before applying them.
  void applyState({
    required double position,
    required RopePhase phase,
    required int indigoScore,
    required int tealScore,
    int countdown = 3,
    RopeTeam? winner,
    bool snap = false,
  }) {
    final previous = this.phase;
    final previousCountdown = this.countdown;
    targetPosition = position.isFinite
        ? position.clamp(-1.0, 1.0).toDouble()
        : 0;
    this.phase = phase;
    this.winner = winner;
    this.indigoScore = indigoScore;
    this.tealScore = tealScore;
    this.countdown = countdown;
    if (snap || reducedMotion) displayPosition = targetPosition;
    if (phase == RopePhase.finished && previous != phase) {
      finishedAt = clock;
      if (winner != null) onCue?.call('win');
    }
    if (phase == RopePhase.countdown &&
        (previous != phase || previousCountdown != countdown)) {
      onCue?.call('countdown');
    }
    if (phase == RopePhase.playing && previous == RopePhase.countdown) {
      onCue?.call('start');
    }
    final result = phase == RopePhase.finished
        ? (winner == null ? 'Draw.' : '${winner.name} wins.')
        : phase.name;
    summary.value = 'Indigo $indigoScore, Teal $tealScore. $result';
    notifyListeners();
  }

  /// Call once after a new answer result is confirmed by the game service.
  void feedback(RopeTeam team, {required bool correct}) {
    impactTeam = team;
    impactCorrect = correct;
    impactAt = clock;
    onCue?.call(correct ? 'correct' : 'incorrect');
    notifyListeners();
  }

  void setReducedMotion(bool value) {
    if (reducedMotion == value) return;
    reducedMotion = value;
    if (value) displayPosition = targetPosition;
    notifyListeners();
  }

  void reset() {
    impactAt = -100;
    finishedAt = -100;
    impactTeam = null;
    applyState(
      position: 0,
      phase: RopePhase.lobby,
      indigoScore: 0,
      tealScore: 0,
      snap: true,
    );
  }

  void advance(double dt) {
    if (reducedMotion ||
        phase == RopePhase.paused ||
        phase == RopePhase.reconnecting) {
      return;
    }
    final step = dt.clamp(0.0, 0.05).toDouble();
    clock += step;
    displayPosition +=
        (targetPosition - displayPosition) * (1 - math.exp(-step * 10));
    if ((targetPosition - displayPosition).abs() < 0.0001) {
      displayPosition = targetPosition;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    summary.dispose();
    super.dispose();
  }
}

class RopeArena extends StatefulWidget {
  const RopeArena({
    super.key,
    required this.controller,
    this.assetRoot = 'assets/rope_pull',
  });
  final RopeArenaController controller;
  final String assetRoot;
  @override
  State<RopeArena> createState() => _RopeArenaState();
}

class _RopeArenaState extends State<RopeArena>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  Duration? _lastElapsed;
  Map<String, ui.Image>? _images;
  String? _error;
  int _generation = 0;
  bool _appActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker((elapsed) {
      final last = _lastElapsed;
      _lastElapsed = elapsed;
      if (last != null) {
        widget.controller.advance((elapsed - last).inMicroseconds / 1000000.0);
      }
      final state = widget.controller;
      if (state.phase == RopePhase.finished &&
          state.clock - state.finishedAt > 2.3 &&
          (state.targetPosition - state.displayPosition).abs() < .001) {
        _ticker.stop();
        _lastElapsed = null;
      }
    });
    widget.controller.summary.addListener(_syncTicker);
    _loadAssets();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.controller.setReducedMotion(
      MediaQuery.of(context).disableAnimations,
    );
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant RopeArena oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.summary.removeListener(_syncTicker);
      widget.controller.summary.addListener(_syncTicker);
      widget.controller.setReducedMotion(
        MediaQuery.of(context).disableAnimations,
      );
    }
    if (oldWidget.assetRoot != widget.assetRoot) _loadAssets();
    _syncTicker();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _syncTicker();
  }

  void _syncTicker() {
    if (!mounted) return;
    final phase = widget.controller.phase;
    final shouldRun =
        _images != null &&
        _appActive &&
        TickerMode.valuesOf(context).enabled &&
        !widget.controller.reducedMotion &&
        phase != RopePhase.paused &&
        phase != RopePhase.reconnecting;
    if (shouldRun && !_ticker.isActive) {
      _lastElapsed = null;
      _ticker.start();
    } else if (!shouldRun && _ticker.isActive) {
      _ticker.stop();
      _lastElapsed = null;
    }
  }

  Future<void> _loadAssets() async {
    final generation = ++_generation;
    final local = <String, ui.Image>{};
    if (mounted) setState(() => _error = null);
    try {
      const files = {
        'background': 'environment/campus-court.png',
        'indigo-captain': 'characters/indigo-captain.png',
        'indigo-partner': 'characters/indigo-partner.png',
        'teal-captain': 'characters/teal-captain.png',
        'teal-partner': 'characters/teal-partner.png',
      };
      for (final entry in files.entries) {
        final data = await rootBundle.load(
          '${widget.assetRoot}/${entry.value}',
        );
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        local[entry.key] = await decodeRopePng(bytes);
      }
      if (!mounted || generation != _generation) {
        for (final image in local.values) {
          image.dispose();
        }
        return;
      }
      final previous = _images;
      setState(() => _images = local);
      if (previous != null) {
        for (final image in previous.values) {
          image.dispose();
        }
      }
      _syncTicker();
    } catch (error) {
      for (final image in local.values) {
        image.dispose();
      }
      debugPrint('RopeArena assets: $error');
      if (mounted && generation == _generation) {
        final missing = error.toString().contains('Unable to load asset');
        setState(() {
          _error = missing
              ? 'The court images are not in this running app. Stop it and start again. Hot restart does not pick up new images.'
              : 'Arena assets could not load. Check asset paths and retry.';
        });
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.summary.removeListener(_syncTicker);
    _ticker.dispose();
    for (final image in _images?.values ?? <ui.Image>[]) {
      image.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ColoredBox(
          color: const Color(0xFFF0F3F7),
          child: _error != null
              ? Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(_error!, textAlign: TextAlign.center),
                          ),
                          TextButton(
                            onPressed: _loadAssets,
                            child: const Text('Retry assets'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : _images == null
              ? const Center(child: CircularProgressIndicator())
              : ValueListenableBuilder<String>(
                  valueListenable: widget.controller.summary,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _ArenaPainter(widget.controller, _images!),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  builder: (context, label, child) =>
                      Semantics(image: true, label: label, child: child),
                ),
        ),
      ),
    );
  }
}

class _ArenaPainter extends CustomPainter {
  _ArenaPainter(this.state, this.images) : super(repaint: state);
  final RopeArenaController state;
  final Map<String, ui.Image> images;
  static const indigo = kRopeIndigo;
  static const teal = kRopeTeal;
  static const ink = Color(0xFF20213B);
  static const amber = Color(0xFFF5C56A);
  // Normalized grips/feet are calibrated to the included unmodified PNGs.
  static const grips = <String, Offset>{
    'indigo-captain': Offset(0.712, 0.421),
    'indigo-partner': Offset(0.712, 0.392),
    'teal-captain': Offset(0.756, 0.390),
    'teal-partner': Offset(0.744, 0.411),
  };

  void _line(Canvas c, Offset a, Offset b, Color color, double width) =>
      c.drawLine(
        a,
        b,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );

  void _text(Canvas c, String value, Offset at, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 1000);
    tp.paint(c, Offset(at.dx - tp.width / 2, at.dy - tp.height / 2));
  }

  void _player(Canvas c, String key, double x, bool flipped, double phase) {
    final grip = grips[key]!;
    final team = flipped ? RopeTeam.teal : RopeTeam.indigo;
    final age = state.clock - state.impactAt;
    final impulse =
        age >= 0 && age < .65 && state.impactTeam == team && state.impactCorrect
        ? math.sin(age / .65 * math.pi)
        : 0.0;
    final active =
        state.phase == RopePhase.playing || state.phase == RopePhase.lobby;
    final sway = state.reducedMotion || !active
        ? 0.0
        : math.sin(state.clock * 2.6 + phase) * .009 + impulse * .035;
    final angle = flipped ? -sway : sway;
    const extent = 340.0;
    final direction = flipped ? -1.0 : 1.0;
    final shadowX = x + direction * (0.54 - grip.dx) * extent;
    final shadowY = 340 + (0.915 - grip.dy) * extent;
    c.drawOval(
      Rect.fromCenter(
        center: Offset(shadowX, shadowY + 3),
        width: 195,
        height: 13,
      ),
      Paint()..color = ink.withValues(alpha: 0.12),
    );
    c.save();
    c.translate(x, 340);
    c.rotate(angle);
    c.scale(direction, 1);
    final image = images[key]!;
    c.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(-grip.dx * extent, -grip.dy * extent, extent, extent),
      Paint()..filterQuality = FilterQuality.medium,
    );
    c.restore();
    if (!state.reducedMotion && impulse > 0) {
      for (var i = 0; i < 8; i++) {
        final p = age / .65;
        c.drawCircle(
          Offset(
            shadowX - direction * (i * 9 + p * 45),
            shadowY - math.sin(p * math.pi) * (8 + i * 2),
          ),
          (2 + i % 3).toDouble(),
          Paint()
            ..color = const Color(0xFFA69983).withValues(alpha: (1 - p) * .45),
        );
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = canvas;
    c.save();
    c.clipRect(Offset.zero & size);
    c.scale(size.width / 1200, size.height / 600);
    final bg = images['background']!;
    final sourceHeight = bg.width / 2.0;
    c.drawImageRect(
      bg,
      Rect.fromLTWH(
        0,
        (bg.height - sourceHeight) / 2,
        bg.width.toDouble(),
        sourceHeight,
      ),
      const Rect.fromLTWH(0, 0, 1200, 600),
      Paint()..filterQuality = FilterQuality.medium,
    );
    c.drawRect(
      const Rect.fromLTWH(0, 0, 1200, 600),
      Paint()..color = Colors.white.withValues(alpha: 0.06),
    );
    for (final x in [510.0, 690.0]) {
      for (var y = 365.0; y < 550; y += 20) {
        _line(
          c,
          Offset(x, y),
          Offset(x, y + 9),
          (x < 600 ? indigo : teal).withValues(alpha: 0.35),
          3,
        );
      }
    }
    _text(c, 'INDIGO', const Offset(245, 64), 23, indigo);
    _text(c, 'TEAL', const Offset(955, 64), 23, teal);
    final shift = state.displayPosition * 90;
    _player(c, 'indigo-partner', 255 + shift, false, 1);
    _player(c, 'teal-partner', 945 + shift, true, 1.4);
    _player(c, 'indigo-captain', 395 + shift, false, 0);
    _player(c, 'teal-captain', 805 + shift, true, .4);
    final sag = 5 * (1 - state.displayPosition.abs());
    double ropeY(double x) =>
        340 + math.sin((x - 190 - shift) / 820 * math.pi) * sag;
    final path = Path()..moveTo(190 + shift, 340);
    for (var x = 194.0 + shift; x <= 1010 + shift; x += 4) {
      path.lineTo(x, ropeY(x));
    }
    c.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF79613D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
    c.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFE9D2A2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
    for (var x = 194.0 + shift; x < 1008 + shift; x += 10) {
      _line(
        c,
        Offset(x - 2, ropeY(x) - 2.5),
        Offset(x + 2, ropeY(x) + 2.5),
        const Color(0xFFAD8E59),
        1.3,
      );
    }
    final center = 600 + shift;
    final ribbon = Path()
      ..moveTo(center - 8, ropeY(center) - 5)
      ..lineTo(center + 8, ropeY(center) - 5)
      ..lineTo(center + 12, 382)
      ..lineTo(center, 374)
      ..lineTo(center - 12, 382)
      ..close();
    c.drawPath(ribbon, Paint()..color = amber);
    final age = state.clock - state.impactAt;
    if (!state.reducedMotion &&
        age >= 0 &&
        age < .65 &&
        state.impactTeam != null) {
      final x = (state.impactTeam == RopeTeam.indigo ? 395 : 805) + shift;
      final colour = state.impactCorrect
          ? (state.impactTeam == RopeTeam.indigo ? indigo : teal)
          : const Color(0xFFB42332);
      c.drawCircle(
        Offset(x, 340),
        18 + age * 65,
        Paint()
          ..color = colour.withValues(alpha: (1 - age / .65) * .65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
    if (state.phase == RopePhase.countdown) {
      c.drawRect(
        const Rect.fromLTWH(0, 0, 1200, 600),
        Paint()..color = ink.withValues(alpha: 0.24),
      );
      _text(c, '${state.countdown}', const Offset(600, 205), 100, Colors.white);
    }
    if (state.phase == RopePhase.lobby) {
      _text(c, 'Ready to pull together?', const Offset(600, 140), 28, ink);
    }
    if (state.phase == RopePhase.paused ||
        state.phase == RopePhase.reconnecting) {
      c.drawRect(
        const Rect.fromLTWH(0, 0, 1200, 600),
        Paint()..color = Colors.white.withValues(alpha: 0.55),
      );
      _text(
        c,
        state.phase == RopePhase.paused ? 'Paused' : 'Reconnecting…',
        const Offset(600, 230),
        40,
        ink,
      );
    }
    if (state.phase == RopePhase.finished) {
      _text(
        c,
        state.winner == null
            ? 'A well-matched round. Draw.'
            : '${state.winner == RopeTeam.indigo ? 'Indigo' : 'Teal'} wins the round',
        const Offset(600, 140),
        38,
        ink,
      );
      final finishAge = state.clock - state.finishedAt;
      if (!state.reducedMotion &&
          state.winner != null &&
          finishAge >= 0 &&
          finishAge < 2.2) {
        final t = finishAge / 2.2;
        for (var i = 0; i < 48; i++) {
          final x = 80 + ((i * 137) % 1040) + math.sin(t * 7 + i) * 25;
          final y = -50 + t * 650 - (i % 7) * 23;
          final colour = [
            state.winner == RopeTeam.indigo ? indigo : teal,
            amber,
            Colors.white,
          ][i % 3];
          c.save();
          c.translate(x, y);
          c.rotate(t * 8 + i);
          c.drawRect(
            const Rect.fromLTWH(-3, -6, 6, 12),
            Paint()..color = colour.withValues(alpha: 1 - t * .6),
          );
          c.restore();
        }
      }
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _ArenaPainter oldDelegate) =>
      state != oldDelegate.state || images != oldDelegate.images;
}

/// Constrains the 2:1 kit arena without baking HUD into the canvas.
class RopePullKitScene extends StatelessWidget {
  const RopePullKitScene({super.key, required this.controller, this.maxHeight});

  final RopeArenaController controller;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final arena = RopeArena(controller: controller);
    if (maxHeight == null) return arena;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(constraints.maxWidth, maxHeight! * 2);
        return Center(
          child: SizedBox(width: width, height: width / 2, child: arena),
        );
      },
    );
  }
}

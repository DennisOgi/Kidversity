// Rope Pull arena: a Blender-rendered school field plus four rigged kids
// rendered to sprite sheets (idle, pull, slip, win, lose). Every frame ships
// its projected hand and foot points, so the rope always runs through the
// fists. The camera adapts to the box: phones get a tighter, taller view,
// classroom screens a wide one, and nothing is ever stretched.
import 'dart:convert';
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

// ---------------------------------------------------------------------------
// Scene description. World units are metres on the rope line; v is the
// camera-plane height above the ground line. Values come from the Blender
// renders in assets/rope_pull/scene (see tool/rope_pull_blender/).

/// The court backdrop: size, pixels per metre and where world (0, 0) lands.
class _Court {
  static const width = 2881.0;
  static const height = 1783.0;
  static const pxPerM = 342.976;
  static const groundX = 1440.5;
  static const groundY = 1298.0;

  /// Lowest and highest camera-plane heights the backdrop covers.
  static const vBottom = -(height - groundY) / pxPerM;
  static const vTop = groundY / pxPerM;

  /// Widest view the backdrop covers, in metres.
  static const spanM = width / pxPerM;
}

/// Room every view must show: all four pullers plus a little air.
const _minViewWidth = 5.6;
const _minViewHeight = 3.4;
const _viewCentre = 0.9;

/// Root positions along the rope (metres). Captains face each other.
const _roots = <String, double>{
  'indigo-partner': -1.75,
  'indigo-captain': -0.72,
  'teal-captain': 0.72,
  'teal-partner': 1.75,
};

/// How far the whole line slides at full score (metres).
const _maxShift = 0.55;

const _kidIds = [
  'indigo-partner',
  'teal-partner',
  'indigo-captain',
  'teal-captain',
];

class _Frame {
  const _Frame(this.grips, this.feet);
  final List<Offset>? grips;
  final List<Offset> feet;
}

class _KidSheet {
  _KidSheet(this.anchor, this.states, this.frames);
  final Offset anchor;
  final Map<String, List<int>> states;
  final List<_Frame> frames;

  static Offset _pt(Object? raw) {
    final list = raw! as List;
    return Offset((list[0] as num).toDouble(), (list[1] as num).toDouble());
  }

  factory _KidSheet.fromJson(Map<String, dynamic> json) {
    final states = <String, List<int>>{
      for (final entry in (json['states'] as Map).entries)
        entry.key as String: [
          for (final i in entry.value as List) (i as num).toInt(),
        ],
    };
    final frames = <_Frame>[];
    for (final raw in json['frames'] as List) {
      final frame = raw as Map<String, dynamic>;
      final grips = frame['g'] as List?;
      frames.add(
        _Frame(grips == null ? null : [for (final p in grips) _pt(p)], [
          for (final p in frame['f'] as List) _pt(p),
        ]),
      );
    }
    return _KidSheet(_pt(json['anchor']), states, frames);
  }
}

class _SceneArt {
  _SceneArt({
    required this.court,
    required this.sheets,
    required this.kids,
    required this.cell,
    required this.columns,
    this.dust,
  });

  final ui.Image court;
  final Map<String, ui.Image> sheets;
  final Map<String, _KidSheet> kids;
  final double cell;
  final int columns;
  final ui.Image? dust;

  /// Sprite pixels per metre (cells cover 1.9 m).
  double get cellPxPerM => cell / 1.9;

  void dispose() {
    court.dispose();
    for (final image in sheets.values) {
      image.dispose();
    }
    dust?.dispose();
  }
}

/// Arena aspect for a given width when the parent leaves height open.
double ropeArenaAspectFor(double width) {
  if (width < 480) return 1.3;
  if (width < 820) return 1.7;
  return 2.1;
}

const _minAspect = 1.2;
const _maxAspect = 2.4;

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
  _SceneArt? _art;
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
    // Kids keep breathing/celebrating in every phase except pause and
    // reconnect, so the ticker runs whenever the arena is on screen.
    final shouldRun =
        _art != null &&
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

  Future<ui.Image> _image(String path) async {
    final data = await rootBundle.load('${widget.assetRoot}/$path');
    return decodeRopePng(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }

  Future<void> _loadAssets() async {
    final generation = ++_generation;
    final loaded = <ui.Image>[];
    if (mounted) setState(() => _error = null);
    try {
      final manifest =
          jsonDecode(
                await rootBundle.loadString(
                  '${widget.assetRoot}/scene/kids.json',
                ),
              )
              as Map<String, dynamic>;
      final court = await _image('scene/court.jpg');
      loaded.add(court);
      final sheets = <String, ui.Image>{};
      final kids = <String, _KidSheet>{};
      final kidJson = manifest['kids'] as Map<String, dynamic>;
      for (final id in _kidIds) {
        final sheet = await _image('scene/$id.png');
        loaded.add(sheet);
        sheets[id] = sheet;
        kids[id] = _KidSheet.fromJson(kidJson[id] as Map<String, dynamic>);
      }
      ui.Image? dust;
      try {
        dust = await _image('ui/dust-sheet.png');
        loaded.add(dust);
      } catch (_) {
        // Dust is decoration; the arena works without it.
      }
      final art = _SceneArt(
        court: court,
        sheets: sheets,
        kids: kids,
        cell: (manifest['cell'] as num).toDouble(),
        columns: (manifest['cols'] as num).toInt(),
        dust: dust,
      );
      if (!mounted || generation != _generation) {
        art.dispose();
        return;
      }
      final previous = _art;
      setState(() => _art = art);
      previous?.dispose();
      _syncTicker();
    } catch (error) {
      for (final image in loaded) {
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
    _art?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 720.0;
        var height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : width / ropeArenaAspectFor(width);
        var boxWidth = width;
        // Keep the view inside what the backdrop covers.
        if (boxWidth / height > _maxAspect) boxWidth = height * _maxAspect;
        if (boxWidth / height < _minAspect) height = boxWidth / _minAspect;
        return Center(
          child: SizedBox(
            width: boxWidth,
            height: height,
            child: _frame(context),
          ),
        );
      },
    );
  }

  Widget _frame(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return ClipRRect(
      borderRadius: radius,
      child: ColoredBox(
        color: const Color(0xFFB9DFF2),
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
            : _art == null
            ? const Center(child: CircularProgressIndicator())
            : ValueListenableBuilder<String>(
                valueListenable: widget.controller.summary,
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _ArenaPainter(widget.controller, _art!),
                    child: const SizedBox.expand(),
                  ),
                ),
                builder: (context, label, child) =>
                    Semantics(image: true, label: label, child: child),
              ),
      ),
    );
  }
}

class _ArenaPainter extends CustomPainter {
  _ArenaPainter(this.state, this.art) : super(repaint: state);
  final RopeArenaController state;
  final _SceneArt art;
  static const indigo = kRopeIndigo;
  static const teal = kRopeTeal;
  static const ink = Color(0xFF20213B);
  static const amber = Color(0xFFF5C56A);

  // Per-paint camera.
  late double _k; // screen px per metre
  late double _vc; // camera-plane height at the vertical centre
  late Size _size;

  Offset _screen(double x, double v) =>
      Offset(_size.width / 2 + x * _k, _size.height / 2 - (v - _vc) * _k);

  void _setCamera(Size size) {
    _size = size;
    _k = math.min(size.width / _minViewWidth, size.height / _minViewHeight);
    // Never show past the backdrop's edges.
    _k = math.max(_k, size.width / _Court.spanM);
    final half = size.height / (2 * _k);
    final low = _Court.vBottom + half;
    final high = _Court.vTop - half;
    _vc = low > high
        ? (low + high) / 2
        : _viewCentre.clamp(low, high).toDouble();
  }

  // ---- animation selection ----------------------------------------------

  double _impulse(RopeTeam team) {
    final age = state.clock - state.impactAt;
    if (age < 0 || age >= .65 || state.impactTeam != team) return 0;
    return math.sin(age / .65 * math.pi);
  }

  /// Picks the clip and frame index for one kid at the current clock.
  (String, int) _clip(String id, RopeTeam team, double offset) {
    final kid = art.kids[id]!;
    final other = team == RopeTeam.indigo ? RopeTeam.teal : RopeTeam.indigo;
    final t = state.clock + offset;
    String clip;
    var fps = 9.0;
    var once = false;
    var since = t;
    switch (state.phase) {
      case RopePhase.finished:
        if (state.winner == null) {
          clip = 'idle';
        } else {
          clip = state.winner == team ? 'win' : 'lose';
          once = true;
          fps = 12;
          since = state.clock - state.finishedAt;
        }
      case RopePhase.playing:
        // Behind on the rope, or just out-pulled: dig in and slip.
        final losing = team == RopeTeam.indigo
            ? state.displayPosition > 0.45
            : state.displayPosition < -0.45;
        final yanked = state.impactCorrect && _impulse(other) > 0.05;
        final heave = state.impactCorrect && _impulse(team) > 0.05;
        clip = (losing || yanked) && !heave ? 'slip' : 'pull';
        fps = heave ? 16 : 9;
      case RopePhase.lobby:
      case RopePhase.countdown:
      case RopePhase.paused:
      case RopePhase.reconnecting:
        clip = 'idle';
        fps = 6;
    }
    final frames = kid.states[clip]!;
    if (state.reducedMotion) {
      return (clip, frames[once ? frames.length - 1 : 0]);
    }
    var i = (math.max(0.0, since) * fps).floor();
    if (once && i >= frames.length) {
      // Hold the end of the clip with a gentle loop over its last frames.
      const tail = 4;
      i = frames.length - tail + ((i - frames.length) ~/ 2) % tail;
    }
    return (clip, frames[i % frames.length]);
  }

  // ---- drawing helpers ---------------------------------------------------

  void _text(
    Canvas c,
    String value,
    Offset at,
    double size,
    Color color, {
    Color? halo,
    FontWeight weight = FontWeight.w800,
  }) {
    final style = TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: 0.5,
    );
    if (halo != null) {
      final back = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontSize: size,
            fontWeight: weight,
            letterSpacing: 0.5,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size * 0.18
              ..strokeJoin = StrokeJoin.round
              ..color = halo,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: _size.width - 24);
      back.paint(c, Offset(at.dx - back.width / 2, at.dy - back.height / 2));
    }
    final tp = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: _size.width - 24);
    tp.paint(c, Offset(at.dx - tp.width / 2, at.dy - tp.height / 2));
  }

  void _background(Canvas c) {
    final origin = _screen(0, 0);
    final s = _k / _Court.pxPerM;
    c.drawImageRect(
      art.court,
      const Rect.fromLTWH(0, 0, _Court.width, _Court.height),
      Rect.fromLTWH(
        origin.dx - _Court.groundX * s,
        origin.dy - _Court.groundY * s,
        _Court.width * s,
        _Court.height * s,
      ),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  /// Painted centre line plus a dashed win line for each team. The lines
  /// belong to the ground and never move; the rope's ribbon crossing a
  /// team's line is the visual "they pulled it over".
  void _groundMarks(Canvas c) {
    // Depth runs up the screen, so a line across the pit is vertical.
    const far = 0.5;
    const near = -0.55;
    final width = math.max(2.0, _k * 0.03);
    final centreTop = _screen(0, far);
    final centreBottom = _screen(0, near);
    c.drawLine(
      centreTop,
      centreBottom,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.92)
        ..strokeWidth = width * 1.4
        ..strokeCap = StrokeCap.round,
    );
    for (final (x, colour) in [(-_maxShift, indigo), (_maxShift, teal)]) {
      final top = _screen(x, far);
      final bottom = _screen(x, near);
      final dash = Paint()
        ..color = Color.lerp(
          colour,
          Colors.white,
          0.35,
        )!.withValues(alpha: 0.95)
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round;
      for (var y = top.dy; y < bottom.dy; y += _k * 0.12) {
        c.drawLine(
          Offset(top.dx, y),
          Offset(top.dx, math.min(y + _k * 0.07, bottom.dy)),
          dash,
        );
      }
      // Team cone at the near end, in front of the kids so it never hides.
      final h = _k * 0.17;
      final w = _k * 0.075;
      final base = _screen(x, near - 0.04);
      final cone = Path()
        ..moveTo(base.dx - w, base.dy)
        ..lineTo(base.dx + w, base.dy)
        ..lineTo(base.dx, base.dy - h)
        ..close();
      c.drawPath(cone, Paint()..color = colour);
      c.drawPath(
        cone,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, _k * 0.01)
          ..color = const Color(0xFF120F22),
      );
      c.drawLine(
        Offset(base.dx - w * 0.55, base.dy - h * 0.38),
        Offset(base.dx + w * 0.55, base.dy - h * 0.38),
        Paint()
          ..color = Colors.white
          ..strokeWidth = math.max(1.0, _k * 0.018),
      );
    }
  }

  /// Draws one kid; returns its grips in screen space (null when the rope
  /// is dropped) and the screen x of the back foot for dust.
  (List<Offset>?, Offset) _kid(Canvas c, String id, double shift) {
    final kid = art.kids[id]!;
    final team = id.startsWith('teal') ? RopeTeam.teal : RopeTeam.indigo;
    final flip = team == RopeTeam.teal;
    final offset = switch (id) {
      'indigo-partner' => 0.37,
      'teal-captain' => 0.19,
      'teal-partner' => 0.53,
      _ => 0.0,
    };
    final (_, index) = _clip(id, team, offset);
    final frame = kid.frames[index];
    final root = _screen(_roots[id]! + shift, 0);
    final s = _k / art.cellPxPerM;
    final dir = flip ? -1.0 : 1.0;
    Offset toScreen(Offset p) => Offset(
      root.dx + dir * (p.dx - kid.anchor.dx) * s,
      root.dy + (p.dy - kid.anchor.dy) * s,
    );

    // Soft contact shadow spanning both feet.
    final feet = frame.feet.map(toScreen).toList();
    final left = feet.map((f) => f.dx).reduce(math.min) - 0.12 * _k;
    final right = feet.map((f) => f.dx).reduce(math.max) + 0.12 * _k;
    final shadowRect = Rect.fromLTRB(
      left,
      root.dy - 0.05 * _k,
      right,
      root.dy + 0.05 * _k,
    );
    c.drawOval(
      shadowRect,
      Paint()
        ..color = const Color(0xFF5A2E10).withValues(alpha: 0.28)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 0.02 * _k + 0.5),
    );

    final col = index % art.columns;
    final row = index ~/ art.columns;
    final src = Rect.fromLTWH(
      col * art.cell,
      row * art.cell,
      art.cell,
      art.cell,
    );
    c.save();
    c.translate(root.dx, root.dy);
    c.scale(dir * s, s);
    c.drawImageRect(
      art.sheets[id]!,
      src,
      Rect.fromLTWH(-kid.anchor.dx, -kid.anchor.dy, art.cell, art.cell),
      Paint()..filterQuality = FilterQuality.medium,
    );
    c.restore();
    final back = flip
        ? feet.reduce((a, b) => a.dx > b.dx ? a : b)
        : feet.reduce((a, b) => a.dx < b.dx ? a : b);
    final grips = frame.grips?.map(toScreen).toList();
    // One rope point per kid, between both fists, keeps the rope smooth.
    final mid = grips == null || grips.isEmpty
        ? null
        : <Offset>[
            Offset(
              grips.map((g) => g.dx).reduce((a, b) => a + b) / grips.length,
              grips.map((g) => g.dy).reduce((a, b) => a + b) / grips.length,
            ),
          ];
    return (mid, back);
  }

  /// Smooth rope through every fist, with loose tails at both ends.
  void _rope(Canvas c, List<Offset> grips, double shift) {
    grips.sort((a, b) => a.dx.compareTo(b.dx));
    final tailDrop = 0.16 * _k;
    final first = grips.first;
    final last = grips.last;
    final pts = <Offset>[
      Offset(first.dx - 0.42 * _k, first.dy + tailDrop * 1.6),
      Offset(first.dx - 0.2 * _k, first.dy + tailDrop * 0.45),
      ...grips,
      Offset(last.dx + 0.2 * _k, last.dy + tailDrop * 0.45),
      Offset(last.dx + 0.42 * _k, last.dy + tailDrop * 1.6),
    ];
    // Tension: a touch of sag between the captains, less when it is tight.
    final sag = (1 - state.displayPosition.abs()) * 0.02 * _k;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = i == 0 ? pts[i] : pts[i - 1];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = i + 2 < pts.length ? pts[i + 2] : pts[i + 1];
      // Catmull-Rom to cubic Bezier; the long span between captains sags.
      final dip = Offset(0, p2.dx - p1.dx > 0.6 * _k ? sag : 0.0);
      final c1 = p1 + (p2 - p0) / 6 + dip;
      final c2 = p2 - (p3 - p1) / 6 + dip;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    final thick = math.max(3.0, 0.045 * _k);
    c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thick + math.max(1.5, thick * 0.35)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF4A3016),
    );
    c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thick
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFD9B77E),
    );
    c.drawPath(
      path.shift(Offset(0, -thick * 0.22)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thick * 0.28
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFF1DDB1),
    );
    // Braid ticks.
    final tick = Paint()
      ..color = const Color(0xFF9C7440)
      ..strokeWidth = math.max(1.0, thick * 0.16)
      ..strokeCap = StrokeCap.round;
    final step = math.max(5.0, thick * 0.9);
    Offset? centre;
    final centreX = _screen(shift, 0).dx;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += step) {
        final tan = metric.getTangentForOffset(d);
        if (tan == null) continue;
        final n = Offset(-tan.vector.dy, tan.vector.dx);
        final a =
            tan.position + n * (thick * 0.42) - tan.vector * (thick * 0.25);
        final b =
            tan.position - n * (thick * 0.42) + tan.vector * (thick * 0.25);
        c.drawLine(a, b, tick);
        if (centre == null && tan.position.dx >= centreX) centre = tan.position;
      }
    }
    // Centre ribbon rides on the rope.
    final at = centre ?? _screen(shift, 0.8);
    final w = math.max(5.0, 0.07 * _k);
    final h = math.max(10.0, 0.2 * _k);
    final ribbon = Path()
      ..moveTo(at.dx - w * 0.5, at.dy)
      ..lineTo(at.dx + w * 0.5, at.dy)
      ..lineTo(at.dx + w * 0.8, at.dy + h)
      ..lineTo(at.dx, at.dy + h * 0.78)
      ..lineTo(at.dx - w * 0.8, at.dy + h)
      ..close();
    c.drawPath(ribbon, Paint()..color = amber);
    c.drawPath(
      ribbon,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, thick * 0.2)
        ..color = const Color(0xFF6B4A12),
    );
    c.drawCircle(at, thick * 0.7, Paint()..color = const Color(0xFFB0391F));
  }

  /// Rope dropped on the sand after the final whistle.
  void _restingRope(Canvas c, double shift) {
    final thick = math.max(3.0, 0.045 * _k);
    final path = Path();
    for (var i = 0; i <= 40; i++) {
      final x = -2.3 + 4.6 * i / 40 + shift;
      final p = _screen(x, -0.12 + math.sin(i * 0.7) * 0.025);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thick + 2
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF4A3016),
    );
    c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thick
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFD9B77E),
    );
  }

  void _dust(Canvas c, Offset foot, RopeTeam team) {
    final dust = art.dust;
    final age = state.clock - state.impactAt;
    if (dust == null ||
        state.reducedMotion ||
        state.impactTeam != team ||
        !state.impactCorrect ||
        age < 0 ||
        age >= .65) {
      return;
    }
    const frames = 8;
    final p = age / .65;
    final frame = (p * frames).floor().clamp(0, frames - 1);
    final fw = dust.width / frames;
    final size = 0.55 * _k;
    final dir = team == RopeTeam.indigo ? -1.0 : 1.0;
    final at = Offset(foot.dx + dir * size * (0.15 + p * 0.3), foot.dy);
    c.drawImageRect(
      dust,
      Rect.fromLTWH(frame * fw, 0, fw, dust.height.toDouble()),
      Rect.fromCenter(
        center: at.translate(0, -size * 0.32),
        width: size,
        height: size,
      ),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Colors.white.withValues(alpha: 1 - p * 0.7),
    );
  }

  void _teamTags(Canvas c) {
    final size = (_size.height * 0.05).clamp(11.0, 22.0).toDouble();
    final pad = size * 0.9;
    for (final (label, colour, score, right) in [
      ('INDIGO', indigo, state.indigoScore, false),
      ('TEAL', teal, state.tealScore, true),
    ]) {
      final tp = TextPainter(
        text: TextSpan(
          text: '$label  $score',
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final w = tp.width + pad * 1.6;
      final h = tp.height + pad * 0.6;
      final x = right ? _size.width - w - pad * 0.6 : pad * 0.6;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, pad * 0.6, w, h),
        Radius.circular(h / 2),
      );
      c.drawRRect(rect, Paint()..color = colour.withValues(alpha: 0.92));
      tp.paint(c, Offset(x + pad * 0.8, pad * 0.6 + pad * 0.3));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = canvas;
    _setCamera(size);
    c.save();
    c.clipRect(Offset.zero & size);
    _background(c);
    _groundMarks(c);

    final shift = state.displayPosition * _maxShift;
    final finished = state.phase == RopePhase.finished;
    if (finished) _restingRope(c, shift);

    final grips = <Offset>[];
    final feet = <String, Offset>{};
    for (final id in _kidIds) {
      final (g, back) = _kid(c, id, shift);
      if (g != null) grips.addAll(g);
      feet[id] = back;
    }
    if (!finished && grips.length >= 2) _rope(c, grips, shift);
    _dust(c, feet['indigo-captain']!, RopeTeam.indigo);
    _dust(c, feet['indigo-partner']!, RopeTeam.indigo);
    _dust(c, feet['teal-captain']!, RopeTeam.teal);
    _dust(c, feet['teal-partner']!, RopeTeam.teal);

    // Answer ring at the team's front fists.
    final age = state.clock - state.impactAt;
    if (!state.reducedMotion &&
        age >= 0 &&
        age < .65 &&
        state.impactTeam != null &&
        grips.isNotEmpty) {
      final indigoSide = state.impactTeam == RopeTeam.indigo;
      final front = indigoSide
          ? grips
                .where((g) => g.dx < _size.width / 2 + shift * _k)
                .fold<Offset?>(
                  null,
                  (best, g) => best == null || g.dx > best.dx ? g : best,
                )
          : grips
                .where((g) => g.dx > _size.width / 2 + shift * _k)
                .fold<Offset?>(
                  null,
                  (best, g) => best == null || g.dx < best.dx ? g : best,
                );
      if (front != null) {
        final colour = state.impactCorrect
            ? (indigoSide ? indigo : teal)
            : const Color(0xFFB42332);
        c.drawCircle(
          front,
          0.1 * _k + age * 0.5 * _k,
          Paint()
            ..color = colour.withValues(alpha: (1 - age / .65) * .7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2.0, 0.03 * _k),
        );
      }
    }

    _teamTags(c);
    final big = (_size.height * 0.11).clamp(18.0, 44.0).toDouble();
    final centreTop = Offset(_size.width / 2, _size.height * 0.2);
    if (state.phase == RopePhase.countdown) {
      c.drawRect(
        Offset.zero & _size,
        Paint()..color = ink.withValues(alpha: 0.28),
      );
      _text(
        c,
        state.countdown > 0 ? '${state.countdown}' : 'Pull!',
        Offset(_size.width / 2, _size.height * 0.42),
        big * 2.2,
        Colors.white,
        halo: ink.withValues(alpha: 0.5),
      );
    }
    if (state.phase == RopePhase.lobby) {
      _text(
        c,
        'Ready to pull together?',
        centreTop.translate(0, big * 0.4),
        big * 0.7,
        ink,
        halo: Colors.white.withValues(alpha: 0.85),
      );
    }
    if (state.phase == RopePhase.paused ||
        state.phase == RopePhase.reconnecting) {
      c.drawRect(
        Offset.zero & _size,
        Paint()..color = Colors.white.withValues(alpha: 0.55),
      );
      _text(
        c,
        state.phase == RopePhase.paused ? 'Paused' : 'Reconnecting…',
        Offset(_size.width / 2, _size.height * 0.4),
        big,
        ink,
      );
    }
    if (finished) {
      final winner = state.winner;
      _text(
        c,
        winner == null
            ? 'A well-matched round. Draw.'
            : '${winner == RopeTeam.indigo ? 'Indigo' : 'Teal'} wins the round!',
        centreTop.translate(0, big * 0.4),
        big * 0.8,
        winner == null ? ink : (winner == RopeTeam.indigo ? indigo : teal),
        halo: Colors.white.withValues(alpha: 0.9),
      );
      final finishAge = state.clock - state.finishedAt;
      if (!state.reducedMotion &&
          winner != null &&
          finishAge >= 0 &&
          finishAge < 2.4) {
        final t = finishAge / 2.4;
        final piece = math.max(3.0, _size.height * 0.012);
        for (var i = 0; i < 48; i++) {
          final x =
              _size.width * (0.05 + ((i * 137) % 900) / 1000) +
              math.sin(t * 7 + i) * piece * 4;
          final y = -piece * 6 + t * _size.height * 1.1 - (i % 7) * piece * 3;
          final colour = [
            winner == RopeTeam.indigo ? indigo : teal,
            amber,
            Colors.white,
          ][i % 3];
          c.save();
          c.translate(x, y);
          c.rotate(t * 8 + i);
          c.drawRect(
            Rect.fromLTWH(-piece / 2, -piece, piece, piece * 2),
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
      state != oldDelegate.state || art != oldDelegate.art;
}

/// Arena sized for its slot. With [maxHeight] the scene fills the width and
/// caps its height (widening the view instead of shrinking the kids); without
/// it, the scene fills whatever box it is given.
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
        final width = constraints.maxWidth;
        final natural = width / ropeArenaAspectFor(width);
        final height = math.min(natural, maxHeight!);
        return SizedBox(width: width, height: height, child: arena);
      },
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../theme/app_colors.dart';
import 'lab_frame.dart';
import 'lab_math.dart';

enum WireLayout { series, parallel }

class CircuitLab extends StatefulWidget {
  const CircuitLab({super.key});

  @override
  State<CircuitLab> createState() => _CircuitLabState();
}

class _CircuitLabState extends State<CircuitLab>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double voltage = 6;
  double r1 = 8;
  double r2 = 12;
  double phase = 0;
  WireLayout layout = WireLayout.series;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (MediaQuery.disableAnimationsOf(context)) return;
      setState(() => phase = elapsed.inMilliseconds / 1000);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  double _power(bool first) {
    if (layout == WireLayout.series) {
      final current = seriesCurrent(voltage, r1, r2);
      return current * current * (first ? r1 : r2);
    }
    final resistance = first ? r1 : r2;
    final current = voltage / resistance;
    return current * current * resistance;
  }

  @override
  Widget build(BuildContext context) {
    final current = layout == WireLayout.series
        ? seriesCurrent(voltage, r1, r2)
        : parallelCurrent(voltage, r1, r2);
    final brighter = _power(true) >= _power(false) ? 'left' : 'right';
    return LabFrame(
      spec: circuitSpec,
      challengeMet:
          layout == WireLayout.parallel && _power(false) > _power(true),
      readout:
          '${layout == WireLayout.series ? 'Series' : 'Parallel'}   ·   supply current ${current.toStringAsFixed(2)} A   ·   $brighter bulb is brighter',
      stage: CustomPaint(
        painter: _CircuitPainter(
          voltage: voltage,
          r1: r1,
          r2: r2,
          layout: layout,
          phase: phase,
          power1: _power(true),
          power2: _power(false),
        ),
        child: const SizedBox.expand(),
      ),
      controls: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<WireLayout>(
              segments: const [
                ButtonSegment(value: WireLayout.series, label: Text('Series')),
                ButtonSegment(
                  value: WireLayout.parallel,
                  label: Text('Parallel'),
                ),
              ],
              selected: {layout},
              onSelectionChanged: (value) =>
                  setState(() => layout = value.first),
            ),
          ),
          LabSlider(
            label: 'Battery',
            value: '${voltage.toStringAsFixed(1)} V',
            min: 1,
            max: 12,
            current: voltage,
            onChanged: (v) => setState(() => voltage = v),
          ),
          LabSlider(
            label: 'Left bulb',
            value: '${r1.round()} Ω',
            min: 2,
            max: 30,
            current: r1,
            onChanged: (v) => setState(() => r1 = v),
          ),
          LabSlider(
            label: 'Right bulb',
            value: '${r2.round()} Ω',
            min: 2,
            max: 30,
            current: r2,
            onChanged: (v) => setState(() => r2 = v),
          ),
        ],
      ),
    );
  }
}

class _CircuitPainter extends CustomPainter {
  final double voltage;
  final double r1;
  final double r2;
  final WireLayout layout;
  final double phase;
  final double power1;
  final double power2;

  const _CircuitPainter({
    required this.voltage,
    required this.r1,
    required this.r2,
    required this.layout,
    required this.phase,
    required this.power1,
    required this.power2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final wire = Paint()
      ..color = AppColors.ink
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final left = Offset(size.width * 0.18, size.height * 0.5);
    final right = Offset(size.width * 0.72, size.height * 0.5);
    final battery = Offset(size.width * 0.08, size.height * 0.5);
    if (layout == WireLayout.series) {
      final path = Path()
        ..moveTo(battery.dx, size.height * 0.28)
        ..lineTo(left.dx, size.height * 0.28)
        ..lineTo(left.dx, left.dy)
        ..moveTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy)
        ..lineTo(right.dx, size.height * 0.28)
        ..lineTo(size.width * 0.9, size.height * 0.28)
        ..lineTo(size.width * 0.9, size.height * 0.72)
        ..lineTo(battery.dx, size.height * 0.72);
      canvas.drawPath(path, wire);
      _battery(canvas, battery);
      _bulb(canvas, left, power1, '${r1.round()}Ω');
      _bulb(canvas, right, power2, '${r2.round()}Ω');
      _flow(canvas, [
        Offset(left.dx, size.height * 0.28),
        left,
        right,
        Offset(right.dx, size.height * 0.28),
      ], seriesCurrent(voltage, r1, r2));
    } else {
      final top = size.height * 0.32;
      final bottom = size.height * 0.68;
      final path = Path()
        ..moveTo(battery.dx, top)
        ..lineTo(size.width * 0.86, top)
        ..lineTo(size.width * 0.86, bottom)
        ..lineTo(battery.dx, bottom)
        ..moveTo(left.dx, top)
        ..lineTo(left.dx, bottom)
        ..moveTo(right.dx, top)
        ..lineTo(right.dx, bottom);
      canvas.drawPath(path, wire);
      _battery(canvas, battery);
      _bulb(
        canvas,
        Offset(left.dx, size.height * 0.5),
        power1,
        '${r1.round()}Ω',
      );
      _bulb(
        canvas,
        Offset(right.dx, size.height * 0.5),
        power2,
        '${r2.round()}Ω',
      );
      _flow(canvas, [
        Offset(left.dx, top),
        Offset(left.dx, bottom),
      ], voltage / r1);
      _flow(canvas, [
        Offset(right.dx, top),
        Offset(right.dx, bottom),
      ], voltage / r2);
    }
  }

  void _battery(Canvas canvas, Offset at) {
    canvas.drawLine(
      at + const Offset(0, -22),
      at + const Offset(0, 22),
      Paint()
        ..color = AppColors.ink
        ..strokeWidth = 4,
    );
    canvas.drawLine(
      at + const Offset(10, -12),
      at + const Offset(10, 12),
      Paint()
        ..color = AppColors.ink
        ..strokeWidth = 2,
    );
  }

  void _bulb(Canvas canvas, Offset at, double power, String label) {
    final glow = (power / 36).clamp(0.0, 1.0);
    canvas.drawCircle(
      at,
      28 + glow * 16,
      Paint()..color = AppColors.spark.withValues(alpha: 0.15 + glow * 0.55),
    );
    canvas.drawCircle(
      at,
      22,
      Paint()
        ..color = Color.lerp(
          const Color(0xFFE7E9F2),
          const Color(0xFFFFF4C8),
          glow,
        )!,
    );
    canvas.drawCircle(
      at,
      22,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.ink,
    );
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at + Offset(-painter.width / 2, 28));
  }

  void _flow(Canvas canvas, List<Offset> points, double current) {
    if (points.length < 2 || current <= 0) return;
    var length = 0.0;
    for (var i = 1; i < points.length; i++) {
      length += (points[i] - points[i - 1]).distance;
    }
    final speed = 40 + current * 80;
    for (var n = 0; n < 4; n++) {
      final distance = ((phase * speed) + n * length / 4) % length;
      var walked = 0.0;
      for (var i = 1; i < points.length; i++) {
        final segment = (points[i] - points[i - 1]).distance;
        if (walked + segment >= distance) {
          final t = (distance - walked) / segment;
          final at = Offset.lerp(points[i - 1], points[i], t)!;
          canvas.drawCircle(at, 4, Paint()..color = AppColors.spark);
          break;
        }
        walked += segment;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CircuitPainter oldDelegate) => true;
}

class BuretteLab extends StatefulWidget {
  const BuretteLab({super.key});

  @override
  State<BuretteLab> createState() => _BuretteLabState();
}

class _BuretteLabState extends State<BuretteLab>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  final _random = math.Random();
  late double endpoint;
  double volume = 0;
  bool open = false;
  bool stopped = false;

  @override
  void initState() {
    super.initState();
    endpoint = 22 + _random.nextDouble() * 7;
    _ticker = createTicker((elapsed) {
      final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
      _last = elapsed;
      if (!open || volume >= 50) return;
      setState(() {
        volume = (volume + dt * 2.2).clamp(0, 50);
        stopped = false;
      });
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      endpoint = 22 + _random.nextDouble() * 7;
      volume = 0;
      open = false;
      stopped = false;
    });
  }

  String get _note {
    if (!stopped) {
      return open
          ? 'Tap open. Watch the flask. Stop at the first permanent pink.'
          : 'The flask holds acid and phenolphthalein. It starts colourless.';
    }
    final gap = volume - endpoint;
    if (gap < -0.15) {
      return 'Still colourless. The acid is not neutralised yet. Delivered ${volume.toStringAsFixed(1)} ml.';
    }
    if (gap <= 0.45) {
      return 'First permanent pink. Endpoint ${endpoint.toStringAsFixed(1)} ml, you stopped ${volume.toStringAsFixed(1)} ml.';
    }
    return 'Past the endpoint by ${gap.toStringAsFixed(1)} ml. The deep pink means too much alkali.';
  }

  bool get _met =>
      stopped && volume - endpoint >= -0.15 && volume - endpoint <= 0.45;

  @override
  Widget build(BuildContext context) {
    return LabFrame(
      spec: buretteSpec,
      challengeMet: _met,
      readout: _note,
      stage: CustomPaint(
        painter: _BurettePainter(
          volume: volume,
          endpoint: endpoint,
          open: open,
          reveal: stopped,
        ),
        child: const SizedBox.expand(),
      ),
      controls: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton(
            onPressed: volume >= 50
                ? null
                : () => setState(() {
                    open = !open;
                    if (!open) stopped = volume > 0;
                  }),
            child: Text(open ? 'Close the tap' : 'Open the tap'),
          ),
          OutlinedButton(onPressed: _reset, child: const Text('New flask')),
        ],
      ),
    );
  }
}

class _BurettePainter extends CustomPainter {
  final double volume;
  final double endpoint;
  final bool open;
  final bool reveal;

  const _BurettePainter({
    required this.volume,
    required this.endpoint,
    required this.open,
    required this.reveal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final tube = Rect.fromLTWH(
      size.width * 0.22,
      size.height * 0.06,
      34,
      size.height * 0.46,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(tube, const Radius.circular(6)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.ink,
    );
    final fill = (volume / 50).clamp(0.0, 1.0);
    final meniscus = tube.top + 8 + fill * (tube.height - 16);
    canvas.drawRect(
      Rect.fromLTRB(tube.left + 3, meniscus, tube.right - 3, tube.bottom - 3),
      Paint()..color = const Color(0xFFD7F3EE),
    );
    canvas.drawLine(
      Offset(tube.left + 3, meniscus),
      Offset(tube.right - 3, meniscus),
      Paint()
        ..color = AppColors.accentTeal
        ..strokeWidth = 2,
    );
    for (var ml = 0; ml <= 50; ml += 5) {
      final y = tube.top + 8 + (ml / 50) * (tube.height - 16);
      canvas.drawLine(
        Offset(tube.right, y),
        Offset(tube.right + (ml % 10 == 0 ? 12 : 7), y),
        Paint()
          ..color = AppColors.inkSoft
          ..strokeWidth = 1,
      );
      if (ml % 10 == 0) {
        _text(canvas, '$ml', Offset(tube.right + 16, y - 7));
      }
    }
    final tap = Offset(tube.center.dx, tube.bottom + 16);
    canvas.drawLine(
      Offset(tube.center.dx, tube.bottom),
      tap,
      Paint()
        ..color = AppColors.ink
        ..strokeWidth = 3,
    );
    canvas.drawCircle(
      tap + const Offset(16, 0),
      7,
      Paint()..color = open ? AppColors.success : AppColors.danger,
    );
    if (open) {
      canvas.drawCircle(
        tap + const Offset(0, 18),
        4,
        Paint()..color = const Color(0xFF7DCEC4),
      );
    }

    final neck = size.height * 0.62;
    final bowl = size.height * 0.9;
    final flask = Path()
      ..moveTo(size.width * 0.42, neck)
      ..lineTo(size.width * 0.32, bowl - 20)
      ..quadraticBezierTo(
        size.width * 0.55,
        size.height * 0.98,
        size.width * 0.78,
        bowl - 20,
      )
      ..lineTo(size.width * 0.68, neck)
      ..close();
    canvas.drawPath(
      flask,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.ink,
    );
    final pink = ((volume - endpoint) / 1.2).clamp(0.0, 1.0);
    final liquid = Color.lerp(
      const Color(0xFFF4F7FB),
      const Color(0xFFE24B8A),
      volume + 0.05 >= endpoint ? 0.25 + pink * 0.75 : 0,
    )!;
    canvas.drawPath(flask, Paint()..color = liquid.withValues(alpha: 0.9));
    _text(
      canvas,
      reveal ? 'Endpoint ${endpoint.toStringAsFixed(1)} ml' : 'Endpoint hidden',
      Offset(size.width * 0.58, size.height * 0.12),
    );
    _text(
      canvas,
      '${volume.toStringAsFixed(1)} ml delivered',
      Offset(size.width * 0.58, size.height * 0.2),
    );
  }

  void _text(Canvas canvas, String text, Offset at) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _BurettePainter oldDelegate) => true;
}

class VernierLab extends StatefulWidget {
  const VernierLab({super.key});

  @override
  State<VernierLab> createState() => _VernierLabState();
}

class _VernierLabState extends State<VernierLab> {
  double reading = 12.0;

  @override
  Widget build(BuildContext context) {
    return LabFrame(
      spec: vernierSpec,
      challengeMet: (reading - 12.6).abs() < 0.05,
      readout: vernierReadingSentence(reading),
      stage: CustomPaint(
        painter: _VernierPainter(reading: reading),
        child: const SizedBox.expand(),
      ),
      controls: LabSlider(
        label: 'Jaws',
        value: '${reading.toStringAsFixed(1)} mm',
        min: 0,
        max: 25,
        current: reading,
        onChanged: (v) => setState(() => reading = (v * 10).round() / 10),
      ),
    );
  }
}

class _VernierPainter extends CustomPainter {
  final double reading;
  const _VernierPainter({required this.reading});

  @override
  void paint(Canvas canvas, Size size) {
    final px = ((size.width - 72) / 28).clamp(8.0, 16.0);
    final origin = Offset(36, size.height * 0.42);
    final main = Paint()
      ..color = AppColors.ink
      ..strokeWidth = 2;
    canvas.drawLine(origin, origin + Offset(26 * px, 0), main);
    for (var mm = 0; mm <= 26; mm++) {
      final x = origin.dx + mm * px;
      final h = mm % 5 == 0 ? 18.0 : 10.0;
      canvas.drawLine(Offset(x, origin.dy), Offset(x, origin.dy - h), main);
      if (mm % 5 == 0) {
        _text(canvas, '$mm', Offset(x - 6, origin.dy + 6));
      }
    }
    final zero = origin.dx + reading * px;
    final tenth = (reading * 10).round() % 10;
    canvas.drawLine(
      Offset(zero, origin.dy + 8),
      Offset(zero + 9 * px, origin.dy + 8),
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 2,
    );
    for (var mark = 0; mark < 10; mark++) {
      final x = zero + mark * 0.9 * px;
      final hit = mark == tenth;
      canvas.drawLine(
        Offset(x, origin.dy + 8),
        Offset(x, origin.dy + (hit ? 28 : 20)),
        Paint()
          ..color = hit ? AppColors.spark : AppColors.primary
          ..strokeWidth = hit ? 3 : 1.5,
      );
    }
    canvas.drawLine(
      Offset(zero, origin.dy - 36),
      Offset(zero, origin.dy + 36),
      Paint()
        ..color = AppColors.accentTeal
        ..strokeWidth = 2,
    );
    _text(canvas, '0', Offset(zero - 4, origin.dy + 30));
    _text(
      canvas,
      'Gold mark is the line that meets the main scale',
      Offset(36, size.height * 0.72),
    );
  }

  void _text(Canvas canvas, String text, Offset at) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: AppColors.ink, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _VernierPainter oldDelegate) =>
      oldDelegate.reading != reading;
}

const hookePoints = <(double, double)>[
  (1, 2.1),
  (2, 4.0),
  (3, 5.8),
  (4, 8.3),
  (5, 9.9),
  (6, 12.2),
  (7, 13.8),
  (8, 16.4),
];

class BestFitLab extends StatefulWidget {
  const BestFitLab({super.key});

  @override
  State<BestFitLab> createState() => _BestFitLabState();
}

class _BestFitLabState extends State<BestFitLab> {
  double slope = 1;
  double intercept = 4;

  @override
  Widget build(BuildContext context) {
    final best = leastSquares(hookePoints);
    final error = meanAbsoluteResidual(hookePoints, slope, intercept);
    final bestError = meanAbsoluteResidual(
      hookePoints,
      best.slope,
      best.intercept,
    );
    final close = error - bestError < 0.18;
    return LabFrame(
      spec: bestFitSpec,
      challengeMet: close,
      readout:
          'Your line  y = ${slope.toStringAsFixed(2)}x + ${intercept.toStringAsFixed(2)}    ·    average miss ${error.toStringAsFixed(2)} cm',
      stage: CustomPaint(
        painter: _FitPainter(
          slope: slope,
          intercept: intercept,
          showBest: close,
          bestSlope: best.slope,
          bestIntercept: best.intercept,
        ),
        child: const SizedBox.expand(),
      ),
      controls: Column(
        children: [
          LabSlider(
            label: 'Slope',
            value: slope.toStringAsFixed(2),
            min: 0.4,
            max: 3.2,
            current: slope,
            onChanged: (v) => setState(() => slope = v),
          ),
          LabSlider(
            label: 'Intercept',
            value: intercept.toStringAsFixed(2),
            min: -1,
            max: 6,
            current: intercept,
            onChanged: (v) => setState(() => intercept = v),
          ),
        ],
      ),
    );
  }
}

class _FitPainter extends CustomPainter {
  final double slope;
  final double intercept;
  final bool showBest;
  final double bestSlope;
  final double bestIntercept;

  const _FitPainter({
    required this.slope,
    required this.intercept,
    required this.showBest,
    required this.bestSlope,
    required this.bestIntercept,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTWH(48, 24, size.width - 80, size.height - 64);
    canvas.drawRRect(
      RRect.fromRectAndRadius(plot, const Radius.circular(8)),
      Paint()..color = Colors.white,
    );
    final axis = Paint()
      ..color = AppColors.inkSoft
      ..strokeWidth = 1.2;
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, axis);
    canvas.drawLine(plot.bottomLeft, plot.topLeft, axis);
    Offset at(double x, double y) {
      final px = plot.left + (x / 9) * plot.width;
      final py = plot.bottom - (y / 18) * plot.height;
      return Offset(px, py);
    }

    void line(double m, double c, Color color, double width) {
      final path = Path()
        ..moveTo(at(0, c).dx, at(0, c).dy)
        ..lineTo(at(9, m * 9 + c).dx, at(9, m * 9 + c).dy);
      canvas.save();
      canvas.clipRect(plot);
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..style = PaintingStyle.stroke,
      );
      canvas.restore();
    }

    if (showBest) {
      line(bestSlope, bestIntercept, AppColors.accentTeal, 2);
    }
    line(slope, intercept, AppColors.primary, 3);
    for (final point in hookePoints) {
      canvas.drawCircle(
        at(point.$1, point.$2),
        5.5,
        Paint()..color = AppColors.spark,
      );
      canvas.drawCircle(
        at(point.$1, point.$2),
        5.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.ink,
      );
    }
    _text(canvas, 'extension / cm', Offset(plot.left, plot.bottom + 8));
    _text(canvas, 'load', Offset(8, plot.top));
  }

  void _text(Canvas canvas, String text, Offset at) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: AppColors.inkSoft, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _FitPainter oldDelegate) => true;
}

const circuitSpec = LabSpec(
  id: 'circuit',
  subject: 'Physics',
  title: 'Circuit bench',
  blurb: 'Series and parallel bulbs, with the current you can see.',
  idea:
      'In series, the same current passes through both bulbs, and the two resistances add. In parallel, each bulb gets the full battery voltage, so a lower resistance takes more current and glows brighter. The moving dots show the direction of conventional current. Brightness follows the power in that bulb.',
  how: 'Switch the wiring, then change the battery and each bulb’s resistance.',
  challenge: 'In parallel, make the right bulb brighter than the left.',
  icon: Icons.bolt_rounded,
  color: AppColors.spark,
  build: CircuitLab.new,
);

const buretteSpec = LabSpec(
  id: 'burette',
  subject: 'Chemistry',
  title: 'Acid–alkali titration',
  blurb: 'Run alkali from a burette until the indicator just turns pink.',
  idea:
      'A titration finds how much alkali neutralises a known acid. Phenolphthalein stays colourless in acid and turns pink in alkali. The endpoint is the first permanent pink, not a deep colour. The volume you need is hidden until you close the tap, the way a real result is read after you stop.',
  how:
      'Open the tap. Close it the moment the flask turns pink. Then start a new flask.',
  challenge: 'Stop within half a millilitre of the endpoint.',
  icon: Icons.science_rounded,
  color: AppColors.accentPink,
  build: BuretteLab.new,
);

const vernierSpec = LabSpec(
  id: 'vernier',
  subject: 'Physics',
  title: 'Vernier callipers',
  blurb: 'Read a length to a tenth of a millimetre.',
  idea:
      'The main scale gives whole millimetres. The sliding vernier has 10 divisions squeezed into 9 mm, so the lines match one at a time. Find the vernier line that sits exactly on a main line. That line’s number is the tenth. The teal line is the zero of the vernier.',
  how:
      'Slide the jaws. The gold mark is the vernier line that meets the main scale.',
  challenge: 'Set the callipers to 12.6 mm.',
  icon: Icons.straighten_rounded,
  color: AppColors.primary,
  build: VernierLab.new,
);

const bestFitSpec = LabSpec(
  id: 'best-fit',
  subject: 'Physics',
  title: 'Line of best fit',
  blurb: 'A spring’s extension against the load that stretched it.',
  idea:
      'Practical points never sit on a perfect line. A line of best fit follows the trend and leaves the points as evenly scattered as possible. Here the load is on the horizontal axis and the extension is vertical. Slope is how many extra centimetres you get per extra unit of load. Intercept is where your line would cross zero load.',
  how:
      'Move slope and intercept until the indigo line follows the points. Average miss is how far the points sit from your line.',
  challenge: 'Bring the average miss close to the best possible line.',
  icon: Icons.show_chart_rounded,
  color: AppColors.worldExams,
  build: BestFitLab.new,
);

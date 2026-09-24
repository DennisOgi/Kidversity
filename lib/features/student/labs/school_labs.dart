import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../theme/app_colors.dart';
import 'lab_frame.dart';
import 'lab_math.dart';

const _elements = [
  'Hydrogen',
  'Helium',
  'Lithium',
  'Beryllium',
  'Boron',
  'Carbon',
  'Nitrogen',
  'Oxygen',
  'Fluorine',
  'Neon',
  'Sodium',
  'Magnesium',
  'Aluminium',
  'Silicon',
  'Phosphorus',
  'Sulphur',
  'Chlorine',
  'Argon',
];

class LensLab extends StatefulWidget {
  const LensLab({super.key});

  @override
  State<LensLab> createState() => _LensLabState();
}

class _LensLabState extends State<LensLab> {
  double focal = 15;
  double object = 40;

  @override
  Widget build(BuildContext context) {
    final image = lensImageDistance(object, focal);
    final sameSize =
        (object - 2 * focal).abs() < 1.2 && image != null && image > 0;
    final readout = image == null
        ? 'The object is on the focus. The rays leave parallel and do not meet.'
        : image < 0
        ? 'Virtual image, ${image.abs().toStringAsFixed(1)} cm on the same side. A screen would stay blank.'
        : 'Real image ${image.toStringAsFixed(1)} cm beyond the lens. Magnification ${(image / object).toStringAsFixed(2)}.';
    return LabFrame(
      spec: lensSpec,
      challengeMet: sameSize,
      readout: readout,
      stage: CustomPaint(
        painter: _LensPainter(focal: focal, object: object, image: image),
        child: const SizedBox.expand(),
      ),
      controls: Column(
        children: [
          LabSlider(
            label: 'Focal length',
            value: '${focal.toStringAsFixed(0)} cm',
            min: 10,
            max: 25,
            current: focal,
            onChanged: (v) => setState(() => focal = v),
          ),
          LabSlider(
            label: 'Object distance',
            value: '${object.toStringAsFixed(0)} cm',
            min: 12,
            max: 70,
            current: object,
            onChanged: (v) => setState(() => object = v),
          ),
        ],
      ),
    );
  }
}

class _LensPainter extends CustomPainter {
  final double focal;
  final double object;
  final double? image;
  const _LensPainter({
    required this.focal,
    required this.object,
    required this.image,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final axisY = size.height * 0.58;
    final lensX = size.width * 0.48;
    final scale = (size.width * 0.36) / 70;
    final objX = lensX - object * scale;
    const height = 64.0;
    final axis = Paint()
      ..color = AppColors.inkSoft
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(16, axisY), Offset(size.width - 16, axisY), axis);
    canvas.drawLine(
      Offset(lensX, axisY - 108),
      Offset(lensX, axisY + 108),
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 3,
    );
    _mark(canvas, lensX + focal * scale, axisY, 'F');
    _mark(canvas, lensX - focal * scale, axisY, 'F');
    _arrow(
      canvas,
      Offset(objX, axisY),
      Offset(objX, axisY - height),
      AppColors.ink,
    );
    final v = image;
    if (v != null && v > 0 && v < 160) {
      final imgX = lensX + v * scale;
      final imgH = height * v / object;
      _arrow(
        canvas,
        Offset(imgX, axisY),
        Offset(imgX, axisY + imgH),
        AppColors.accentTeal,
      );
      final ray = Paint()
        ..color = AppColors.spark
        ..strokeWidth = 2;
      canvas.drawLine(
        Offset(objX, axisY - height),
        Offset(lensX, axisY - height),
        ray,
      );
      canvas.drawLine(
        Offset(lensX, axisY - height),
        Offset(imgX, axisY + imgH),
        ray,
      );
      canvas.drawLine(
        Offset(objX, axisY - height),
        Offset(imgX, axisY + imgH),
        ray,
      );
    }
  }

  void _mark(Canvas canvas, double x, double y, String label) {
    canvas.drawLine(
      Offset(x, y - 8),
      Offset(x, y + 8),
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 2,
    );
    _label(canvas, label, Offset(x - 4, y + 10));
  }

  void _arrow(Canvas canvas, Offset from, Offset to, Color color) {
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = color
        ..strokeWidth = 3,
    );
    canvas.drawCircle(to, 4, Paint()..color = color);
  }

  void _label(Canvas canvas, String text, Offset at) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _LensPainter oldDelegate) => true;
}

class HookeLab extends StatefulWidget {
  const HookeLab({super.key});

  @override
  State<HookeLab> createState() => _HookeLabState();
}

class _HookeLabState extends State<HookeLab> {
  double stiffness = 4;
  double extension = 1;

  @override
  Widget build(BuildContext context) {
    final force = hookeForce(stiffness, extension);
    return LabFrame(
      spec: hookeSpec,
      challengeMet: (force - 10).abs() < 0.35,
      readout:
          'F = kx = ${stiffness.toStringAsFixed(1)} × ${extension.toStringAsFixed(1)} = ${force.toStringAsFixed(1)} N',
      stage: CustomPaint(
        painter: _HookePainter(extension: extension, stiffness: stiffness),
        child: const SizedBox.expand(),
      ),
      controls: Column(
        children: [
          LabSlider(
            label: 'Stiffness k',
            value: '${stiffness.toStringAsFixed(1)} N/cm',
            min: 1,
            max: 8,
            current: stiffness,
            onChanged: (v) => setState(() => stiffness = v),
          ),
          LabSlider(
            label: 'Extension',
            value: '${extension.toStringAsFixed(1)} cm',
            min: 0,
            max: 8,
            current: extension,
            onChanged: (v) => setState(() => extension = v),
          ),
        ],
      ),
    );
  }
}

class _HookePainter extends CustomPainter {
  final double extension;
  final double stiffness;
  const _HookePainter({required this.extension, required this.stiffness});

  @override
  void paint(Canvas canvas, Size size) {
    final top = Offset(size.width * 0.5, 28);
    final stretch = 36 + extension * 22;
    const coils = 8;
    final path = Path()..moveTo(top.dx, top.dy);
    for (var i = 0; i < coils; i++) {
      final y = top.dy + (i + 1) * stretch / coils;
      final x = top.dx + (i.isEven ? -16 : 16);
      path.lineTo(x, y);
    }
    path.lineTo(top.dx, top.dy + stretch);
    canvas.drawLine(
      top + const Offset(-28, 0),
      top + const Offset(28, 0),
      Paint()
        ..color = AppColors.ink
        ..strokeWidth = 4,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Color.lerp(
          AppColors.accentTeal,
          AppColors.danger,
          (extension / 8).clamp(0, 1),
        )!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final mass = Offset(top.dx, top.dy + stretch + 28);
    final radius = 16 + stiffness;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: mass, width: radius * 2, height: radius * 1.4),
        const Radius.circular(6),
      ),
      Paint()..color = AppColors.primary,
    );
  }

  @override
  bool shouldRepaint(covariant _HookePainter oldDelegate) => true;
}

class ForceLab extends StatefulWidget {
  const ForceLab({super.key});

  @override
  State<ForceLab> createState() => _ForceLabState();
}

class _ForceLabState extends State<ForceLab>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double force = 6;
  double mass = 3;
  double position = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (MediaQuery.disableAnimationsOf(context)) return;
      final a = acceleration(force, mass);
      setState(() => position = (elapsed.inMilliseconds / 1000 * a * 40) % 1);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = acceleration(force, mass);
    return LabFrame(
      spec: forceSpec,
      challengeMet: (mass - 6).abs() < 0.35 && (a - 2).abs() < 0.2,
      readout:
          'a = F/m = ${force.toStringAsFixed(1)} / ${mass.toStringAsFixed(1)} = ${a.toStringAsFixed(2)} m/s²',
      stage: CustomPaint(
        painter: _ForcePainter(position: position, mass: mass),
        child: const SizedBox.expand(),
      ),
      controls: Column(
        children: [
          LabSlider(
            label: 'Force',
            value: '${force.toStringAsFixed(1)} N',
            min: 1,
            max: 20,
            current: force,
            onChanged: (v) => setState(() => force = v),
          ),
          LabSlider(
            label: 'Mass',
            value: '${mass.toStringAsFixed(1)} kg',
            min: 1,
            max: 10,
            current: mass,
            onChanged: (v) => setState(() => mass = v),
          ),
        ],
      ),
    );
  }
}

class _ForcePainter extends CustomPainter {
  final double position;
  final double mass;
  const _ForcePainter({required this.position, required this.mass});

  @override
  void paint(Canvas canvas, Size size) {
    final track = Rect.fromLTWH(36, size.height * 0.55, size.width - 72, 8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(track, const Radius.circular(4)),
      Paint()..color = AppColors.ink,
    );
    final width = 36 + mass * 6;
    final left = track.left + position * (track.width - width);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, track.top - 36, width, 36),
        const Radius.circular(6),
      ),
      Paint()..color = AppColors.primary,
    );
    final arrow = Paint()
      ..color = AppColors.spark
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(left + width + 8, track.top - 18),
      Offset(left + width + 48, track.top - 18),
      arrow,
    );
  }

  @override
  bool shouldRepaint(covariant _ForcePainter oldDelegate) => true;
}

class StatesLab extends StatefulWidget {
  const StatesLab({super.key});

  @override
  State<StatesLab> createState() => _StatesLabState();
}

class _StatesLabState extends State<StatesLab>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double celsius = 20;
  double phase = 0;

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

  @override
  Widget build(BuildContext context) {
    final state = matterState(celsius);
    final note = switch (state) {
      'solid' => 'The particles stay in a pattern and only vibrate.',
      'liquid' =>
        'The particles stay close, but they can slide past each other.',
      _ => 'The particles are far apart and move quickly. This is steam.',
    };
    return LabFrame(
      spec: statesSpec,
      challengeMet: celsius >= 100,
      readout: '${celsius.round()} °C   ·   $state. $note',
      stage: CustomPaint(
        painter: _StatesPainter(celsius: celsius, phase: phase, state: state),
        child: const SizedBox.expand(),
      ),
      controls: LabSlider(
        label: 'Temperature',
        value: '${celsius.round()} °C',
        min: -20,
        max: 120,
        current: celsius,
        onChanged: (v) => setState(() => celsius = v),
      ),
    );
  }
}

class _StatesPainter extends CustomPainter {
  final double celsius;
  final double phase;
  final String state;
  const _StatesPainter({
    required this.celsius,
    required this.phase,
    required this.state,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final box = Rect.fromLTWH(
      size.width * 0.18,
      36,
      size.width * 0.64,
      size.height - 72,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(18)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.ink,
    );
    final color = switch (state) {
      'solid' => const Color(0xFF9FD6FF),
      'liquid' => const Color(0xFF3D8BFF),
      _ => const Color(0xFF7DCEC4),
    };
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 5; col++) {
        final jitter = switch (state) {
          'solid' =>
            Offset(math.sin(phase * 6 + col), math.cos(phase * 6 + row)) * 2,
          'liquid' => Offset(
            math.sin(phase * 2 + row) * 10,
            math.cos(phase * 1.6 + col) * 6,
          ),
          _ => Offset(
            math.sin(phase * 1.3 + col * 2) * box.width * 0.28,
            math.cos(phase * 1.1 + row) * box.height * 0.22,
          ),
        };
        final base = state == 'gas'
            ? box.center
            : Offset(
                box.left + 36 + col * ((box.width - 72) / 4),
                box.top + 36 + row * ((box.height - 72) / 3),
              );
        canvas.drawCircle(
          base + jitter,
          state == 'gas' ? 7 : 10,
          Paint()..color = color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StatesPainter oldDelegate) => true;
}

class RateLab extends StatefulWidget {
  const RateLab({super.key});

  @override
  State<RateLab> createState() => _RateLabState();
}

class _RateLabState extends State<RateLab> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double concentration = 0.4;
  double celsius = 20;
  double phase = 0;

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

  @override
  Widget build(BuildContext context) {
    final rate = reactionRate(concentration: concentration, celsius: celsius);
    return LabFrame(
      spec: rateSpec,
      challengeMet: rate >= 0.9,
      readout:
          'Relative rate ${rate.toStringAsFixed(2)}. A higher concentration or a warmer flask makes more bubbles each second.',
      stage: CustomPaint(
        painter: _RatePainter(rate: rate, phase: phase),
        child: const SizedBox.expand(),
      ),
      controls: Column(
        children: [
          LabSlider(
            label: 'Concentration',
            value: concentration.toStringAsFixed(2),
            min: 0.1,
            max: 1,
            current: concentration,
            onChanged: (v) => setState(() => concentration = v),
          ),
          LabSlider(
            label: 'Temperature',
            value: '${celsius.round()} °C',
            min: 10,
            max: 60,
            current: celsius,
            onChanged: (v) => setState(() => celsius = v),
          ),
        ],
      ),
    );
  }
}

class _RatePainter extends CustomPainter {
  final double rate;
  final double phase;
  const _RatePainter({required this.rate, required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final flask = Path()
      ..moveTo(size.width * 0.38, size.height * 0.28)
      ..lineTo(size.width * 0.3, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.96,
        size.width * 0.7,
        size.height * 0.78,
      )
      ..lineTo(size.width * 0.62, size.height * 0.28)
      ..close();
    canvas.drawPath(flask, Paint()..color = const Color(0xFFD7F3EE));
    canvas.drawPath(
      flask,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.ink,
    );
    final bubbles = (4 + rate * 10).round();
    for (var i = 0; i < bubbles; i++) {
      final t = (phase * (0.4 + rate) + i / bubbles) % 1;
      final x = size.width * (0.38 + (i % 5) * 0.05);
      final y = size.height * (0.8 - t * 0.45);
      canvas.drawCircle(
        Offset(x, y),
        4 + (i % 3).toDouble(),
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RatePainter oldDelegate) => true;
}

class AtomLab extends StatefulWidget {
  const AtomLab({super.key});

  @override
  State<AtomLab> createState() => _AtomLabState();
}

class _AtomLabState extends State<AtomLab> {
  double atomicNumber = 6;

  @override
  Widget build(BuildContext context) {
    final z = atomicNumber.round();
    final shells = electronShells(z);
    return LabFrame(
      spec: atomSpec,
      challengeMet: z == 10,
      readout:
          '${_elements[z - 1]}   ·   atomic number $z   ·   shells ${shells.join(', ')}',
      stage: CustomPaint(
        painter: _AtomPainter(shells: shells),
        child: const SizedBox.expand(),
      ),
      controls: LabSlider(
        label: 'Atomic number',
        value: '$z',
        min: 1,
        max: 18,
        current: atomicNumber,
        onChanged: (v) => setState(() => atomicNumber = v.roundToDouble()),
      ),
    );
  }
}

class _AtomPainter extends CustomPainter {
  final List<int> shells;
  const _AtomPainter({required this.shells});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, 16, Paint()..color = AppColors.spark);
    for (var s = 0; s < shells.length; s++) {
      final radius = 42.0 + s * 36;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = AppColors.primary.withValues(alpha: 0.45),
      );
      for (var e = 0; e < shells[s]; e++) {
        final angle = (e / shells[s]) * math.pi * 2 - math.pi / 2;
        canvas.drawCircle(
          center + Offset(math.cos(angle), math.sin(angle)) * radius,
          6,
          Paint()..color = AppColors.primary,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AtomPainter oldDelegate) => true;
}

class EnzymeLab extends StatefulWidget {
  const EnzymeLab({super.key});

  @override
  State<EnzymeLab> createState() => _EnzymeLabState();
}

class _EnzymeLabState extends State<EnzymeLab> {
  double celsius = 10;

  @override
  Widget build(BuildContext context) {
    final activity = enzymeActivity(celsius);
    return LabFrame(
      spec: enzymeSpec,
      challengeMet: (celsius - 37).abs() < 2,
      readout:
          '${celsius.round()} °C   ·   relative activity ${(activity * 100).round()}%. The peak of this curve is the optimum.',
      stage: CustomPaint(
        painter: _EnzymePainter(celsius: celsius),
        child: const SizedBox.expand(),
      ),
      controls: LabSlider(
        label: 'Temperature',
        value: '${celsius.round()} °C',
        min: 0,
        max: 80,
        current: celsius,
        onChanged: (v) => setState(() => celsius = v),
      ),
    );
  }
}

class _EnzymePainter extends CustomPainter {
  final double celsius;
  const _EnzymePainter({required this.celsius});

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTWH(48, 28, size.width - 80, size.height - 70);
    canvas.drawLine(
      plot.bottomLeft,
      plot.bottomRight,
      Paint()..color = AppColors.inkSoft,
    );
    canvas.drawLine(
      plot.bottomLeft,
      plot.topLeft,
      Paint()..color = AppColors.inkSoft,
    );
    final path = Path();
    for (var t = 0.0; t <= 80; t += 1) {
      final x = plot.left + (t / 80) * plot.width;
      final y = plot.bottom - enzymeActivity(t) * (plot.height - 12);
      if (t == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.accentTeal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final x = plot.left + (celsius / 80) * plot.width;
    final y = plot.bottom - enzymeActivity(celsius) * (plot.height - 12);
    canvas.drawCircle(Offset(x, y), 7, Paint()..color = AppColors.spark);
    canvas.drawCircle(
      Offset(x, y),
      7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.ink,
    );
  }

  @override
  bool shouldRepaint(covariant _EnzymePainter oldDelegate) => true;
}

class PhotosynthesisLab extends StatefulWidget {
  const PhotosynthesisLab({super.key});

  @override
  State<PhotosynthesisLab> createState() => _PhotosynthesisLabState();
}

class _PhotosynthesisLabState extends State<PhotosynthesisLab>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double light = 0.35;
  double carbon = 0.35;
  double phase = 0;

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

  @override
  Widget build(BuildContext context) {
    final rate = photosynthesisRate(light, carbon);
    final limitedBy = light <= carbon ? 'light' : 'carbon dioxide';
    return LabFrame(
      spec: photosynthesisSpec,
      challengeMet:
          light >= 0.85 && carbon <= 0.4 && (rate - carbon).abs() < 0.05,
      readout:
          'Rate ${(rate * 100).round()}%. Right now $limitedBy is holding the rate down.',
      stage: CustomPaint(
        painter: _LeafPainter(rate: rate, light: light, phase: phase),
        child: const SizedBox.expand(),
      ),
      controls: Column(
        children: [
          LabSlider(
            label: 'Light',
            value: '${(light * 100).round()}%',
            min: 0,
            max: 1,
            current: light,
            onChanged: (v) => setState(() => light = v),
          ),
          LabSlider(
            label: 'Carbon dioxide',
            value: '${(carbon * 100).round()}%',
            min: 0,
            max: 1,
            current: carbon,
            onChanged: (v) => setState(() => carbon = v),
          ),
        ],
      ),
    );
  }
}

class _LeafPainter extends CustomPainter {
  final double rate;
  final double light;
  final double phase;
  const _LeafPainter({
    required this.rate,
    required this.light,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width * 0.18, size.height * 0.22),
      18 + light * 10,
      Paint()..color = AppColors.spark.withValues(alpha: 0.35 + light * 0.65),
    );
    final leaf = Path()
      ..moveTo(size.width * 0.28, size.height * 0.62)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.18,
        size.width * 0.78,
        size.height * 0.48,
      )
      ..quadraticBezierTo(
        size.width * 0.55,
        size.height * 0.9,
        size.width * 0.28,
        size.height * 0.62,
      );
    canvas.drawPath(leaf, Paint()..color = const Color(0xFF1F8A4C));
    canvas.drawLine(
      Offset(size.width * 0.32, size.height * 0.6),
      Offset(size.width * 0.72, size.height * 0.5),
      Paint()
        ..color = const Color(0xFFD7F3C8)
        ..strokeWidth = 2,
    );
    final bubbles = (rate * 8).round();
    for (var i = 0; i < bubbles; i++) {
      final t = (phase * 0.5 + i / 8) % 1;
      canvas.drawCircle(
        Offset(
          size.width * (0.4 + (i % 4) * 0.06),
          size.height * (0.7 - t * 0.4),
        ),
        5,
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LeafPainter oldDelegate) => true;
}

class PythagorasLab extends StatefulWidget {
  const PythagorasLab({super.key});

  @override
  State<PythagorasLab> createState() => _PythagorasLabState();
}

class _PythagorasLabState extends State<PythagorasLab> {
  double a = 5;
  double b = 5;

  @override
  Widget build(BuildContext context) {
    final c = hypotenuse(a, b);
    final triple = (a - 3).abs() < 0.2 && (b - 4).abs() < 0.2;
    return LabFrame(
      spec: pythagorasSpec,
      challengeMet: triple || ((a - 4).abs() < 0.2 && (b - 3).abs() < 0.2),
      readout:
          '${a.toStringAsFixed(0)}² + ${b.toStringAsFixed(0)}² = ${c.toStringAsFixed(2)}². The long side is ${c.toStringAsFixed(2)}.',
      stage: CustomPaint(
        painter: _TrianglePainter(a: a, b: b),
        child: const SizedBox.expand(),
      ),
      controls: Column(
        children: [
          LabSlider(
            label: 'Side a',
            value: a.toStringAsFixed(0),
            min: 2,
            max: 8,
            current: a,
            onChanged: (v) => setState(() => a = v.roundToDouble()),
          ),
          LabSlider(
            label: 'Side b',
            value: b.toStringAsFixed(0),
            min: 2,
            max: 8,
            current: b,
            onChanged: (v) => setState(() => b = v.roundToDouble()),
          ),
        ],
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final double a;
  final double b;
  const _TrianglePainter({required this.a, required this.b});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) * 0.04;
    final origin = Offset(size.width * 0.46, size.height * 0.58);
    final p = origin;
    final q = origin + Offset(b * scale, 0);
    final r = origin + Offset(0, -a * scale);
    final fill = Paint()..color = AppColors.primary.withValues(alpha: 0.12);
    canvas.drawPath(Path()..addPolygon([p, q, r], true), fill);
    canvas.drawPath(
      Path()..addPolygon([p, q, r], true),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.primary,
    );
    _square(canvas, p, r, AppColors.accentTeal, outwardLeft: true);
    _square(canvas, p, q, AppColors.spark, outwardLeft: false);
  }

  void _square(
    Canvas canvas,
    Offset a,
    Offset b,
    Color color, {
    required bool outwardLeft,
  }) {
    final side = b - a;
    final normal = outwardLeft
        ? Offset(side.dy, -side.dx)
        : Offset(-side.dy, side.dx);
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo((b + normal).dx, (b + normal).dy)
      ..lineTo((a + normal).dx, (a + normal).dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.35));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) => true;
}

class ChanceLab extends StatefulWidget {
  const ChanceLab({super.key});

  @override
  State<ChanceLab> createState() => _ChanceLabState();
}

class _ChanceLabState extends State<ChanceLab> {
  double redDegrees = 180;

  @override
  Widget build(BuildContext context) {
    final chance = redDegrees / 360;
    return LabFrame(
      spec: chanceSpec,
      challengeMet: (redDegrees - 90).abs() < 6,
      readout:
          'P(red) = ${redDegrees.round()} / 360 = ${chance.toStringAsFixed(2)}. That is about ${(chance * 100).round()} in every 100 spins, if the spinner is fair.',
      stage: CustomPaint(
        painter: _WheelPainter(redDegrees: redDegrees),
        child: const SizedBox.expand(),
      ),
      controls: LabSlider(
        label: 'Red sector',
        value: '${redDegrees.round()}°',
        min: 0,
        max: 360,
        current: redDegrees,
        onChanged: (v) => setState(() => redDegrees = v),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final double redDegrees;
  const _WheelPainter({required this.redDegrees});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.32;
    final red = redDegrees * math.pi / 180;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      red,
      true,
      Paint()..color = AppColors.danger,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 + red,
      math.pi * 2 - red,
      true,
      Paint()..color = AppColors.primary,
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.ink,
    );
    canvas.drawCircle(center, 8, Paint()..color = AppColors.spark);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) => true;
}

class WaterCycleLab extends StatefulWidget {
  const WaterCycleLab({super.key});

  @override
  State<WaterCycleLab> createState() => _WaterCycleLabState();
}

class _WaterCycleLabState extends State<WaterCycleLab>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double heat = 0.25;
  double phase = 0;

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

  @override
  Widget build(BuildContext context) {
    final raining = rainFalling(heat);
    return LabFrame(
      spec: waterSpec,
      challengeMet: raining,
      readout: raining
          ? 'The cloud is heavy enough. Rain is falling back into the sea.'
          : 'Water is leaving the sea. The cloud is still building.',
      stage: CustomPaint(
        painter: _CyclePainter(heat: heat, phase: phase, raining: raining),
        child: const SizedBox.expand(),
      ),
      controls: LabSlider(
        label: 'Sunshine',
        value: '${(heat * 100).round()}%',
        min: 0,
        max: 1,
        current: heat,
        onChanged: (v) => setState(() => heat = v),
      ),
    );
  }
}

class _CyclePainter extends CustomPainter {
  final double heat;
  final double phase;
  final bool raining;
  const _CyclePainter({
    required this.heat,
    required this.phase,
    required this.raining,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width * 0.16, size.height * 0.2),
      16 + heat * 14,
      Paint()..color = AppColors.spark,
    );
    canvas.drawOval(
      Rect.fromLTWH(
        24,
        size.height * 0.72,
        size.width * 0.42,
        size.height * 0.16,
      ),
      Paint()..color = const Color(0xFF3D8BFF),
    );
    final cloud = Offset(size.width * 0.68, size.height * 0.28);
    final puff = 18 + heat * 22;
    canvas.drawCircle(cloud, puff, Paint()..color = Colors.white);
    canvas.drawCircle(
      cloud + const Offset(22, 6),
      puff * 0.8,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      cloud + const Offset(-20, 8),
      puff * 0.75,
      Paint()..color = Colors.white,
    );
    final drops = (heat * 5).round();
    for (var i = 0; i < drops; i++) {
      final t = (phase * 0.6 + i / 5) % 1;
      canvas.drawCircle(
        Offset(size.width * 0.32 + i * 8, size.height * (0.7 - t * 0.28)),
        3,
        Paint()..color = AppColors.accentTeal.withValues(alpha: 0.8),
      );
    }
    if (raining) {
      for (var i = 0; i < 6; i++) {
        final t = (phase * 0.8 + i / 6) % 1;
        final x = cloud.dx - 16 + i * 8;
        canvas.drawLine(
          Offset(x, cloud.dy + 24 + t * 40),
          Offset(x, cloud.dy + 36 + t * 40),
          Paint()
            ..color = const Color(0xFF3D8BFF)
            ..strokeWidth = 2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CyclePainter oldDelegate) => true;
}

class FederalLab extends StatefulWidget {
  const FederalLab({super.key});

  @override
  State<FederalLab> createState() => _FederalLabState();
}

const _duties = [
  ('defence', 'Defence'),
  ('currency', 'Printing the naira'),
  ('markets', 'Local markets'),
  ('refuse', 'Refuse collection'),
];

class _FederalLabState extends State<FederalLab> {
  final placed = <String, String>{};

  bool get _done =>
      _duties.every((duty) => placed[duty.$1] == governmentLevel(duty.$1));

  @override
  Widget build(BuildContext context) {
    return LabFrame(
      spec: federalSpec,
      challengeMet: _done,
      readout: _done
          ? 'Each duty is with the level that holds it in this simplified list.'
          : 'Defence and currency belong to the federation. Markets and refuse belong to the local government.',
      stage: _FederalBoard(placed: placed),
      controls: Column(
        children: [
          for (final duty in _duties)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(duty.$2),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Federal', label: Text('Federal')),
                      ButtonSegment(value: 'Local', label: Text('Local')),
                    ],
                    emptySelectionAllowed: true,
                    selected: {if (placed[duty.$1] != null) placed[duty.$1]!},
                    onSelectionChanged: (value) => setState(() {
                      if (value.isEmpty) {
                        placed.remove(duty.$1);
                      } else {
                        placed[duty.$1] = value.first;
                      }
                    }),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FederalBoard extends StatelessWidget {
  final Map<String, String> placed;
  const _FederalBoard({required this.placed});

  @override
  Widget build(BuildContext context) {
    Widget column(String level, Color color) {
      final items = [
        for (final duty in _duties)
          if (placed[duty.$1] == level) duty.$2,
      ];
      return Expanded(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(level, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (items.isEmpty)
                Text(
                  'Nothing placed yet',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(item),
                  ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        column('Federal', AppColors.primary),
        column('Local', AppColors.accentTeal),
      ],
    );
  }
}

const lensSpec = LabSpec(
  id: 'lens',
  subject: 'Physics',
  title: 'Convex lens',
  blurb: 'Move an object and see where the image forms.',
  idea:
      'A convex lens brings rays together. The focal length is the distance from the lens to the focus, marked F. When the object is beyond that focus, the rays meet on the far side and a screen can catch a real, upside-down image. At twice the focal length, the image is the same size as the object. Closer than the focus, the rays never meet on a screen: the image is virtual.',
  how:
      'Move the object distance, then the focal length. The gold lines are the two school rays.',
  challenge: 'Place the object so the image is the same size as the object.',
  icon: Icons.center_focus_strong_rounded,
  color: AppColors.worldExams,
  build: LensLab.new,
);

const hookeSpec = LabSpec(
  id: 'hooke',
  subject: 'Physics',
  title: "Hooke's law",
  blurb: 'Stretch a spring and read the force.',
  idea:
      'Within its elastic limit, the force in a spring is its stiffness times the extension. Double the stretch and you double the force, if the stiffness stays the same. A stiffer spring needs more force for the same extension. This bench stops before the spring is damaged, so the line stays straight.',
  how:
      'Change the extension and the stiffness. The mass drops as the spring gets longer.',
  challenge: 'Make the force 10 N.',
  icon: Icons.compress_rounded,
  color: AppColors.accentTeal,
  build: HookeLab.new,
);

const forceSpec = LabSpec(
  id: 'force',
  subject: 'Physics',
  title: 'Force and acceleration',
  blurb: 'A trolley speeds up in proportion to the force.',
  idea:
      'Newton’s second law says acceleration equals force divided by mass. Push harder and the trolley gains speed faster. Add mass, with the same push, and the acceleration falls. The arrow shows the direction of the force. The block’s speed on the track follows the acceleration.',
  how: 'Change the force and the mass. Read a = F/m under the track.',
  challenge: 'Give a 6 kg trolley an acceleration of about 2 m/s².',
  icon: Icons.speed_rounded,
  color: AppColors.primary,
  build: ForceLab.new,
);

const statesSpec = LabSpec(
  id: 'states',
  subject: 'Chemistry',
  title: 'States of matter',
  blurb: 'Heat water and watch the particles change arrangement.',
  idea:
      'The same particles can be a solid, a liquid, or a gas. In ice they vibrate in a pattern. In water they stay close but slide. In steam they are far apart and move quickly. On this bench, 0 °C is melting and 100 °C is boiling. The dots are a picture of the arrangement, not a count of molecules.',
  how: 'Move the temperature from below freezing to above boiling.',
  challenge: 'Boil the water.',
  icon: Icons.thermostat_rounded,
  color: AppColors.accentTeal,
  build: StatesLab.new,
);

const rateSpec = LabSpec(
  id: 'rate',
  subject: 'Chemistry',
  title: 'Rate of reaction',
  blurb: 'Concentration and temperature change how fast the bubbles come.',
  idea:
      'A reaction speeds up when particles collide more often and with more energy. A more concentrated solution means more particles in the same space. A warmer flask means faster particles. This bench shows a relative rate for those two changes. It does not include a catalyst or the surface area of a solid.',
  how: 'Raise the concentration, then the temperature, and watch the bubbles.',
  challenge: 'Make the relative rate at least 0.90.',
  icon: Icons.bubble_chart_rounded,
  color: AppColors.accentPink,
  build: RateLab.new,
);

const atomSpec = LabSpec(
  id: 'atom',
  subject: 'Chemistry',
  title: 'Electron shells',
  blurb: 'Fill the shells from hydrogen to argon.',
  idea:
      'In the school shell model, the first shell holds 2 electrons, the next holds 8, and the next holds 8. Electrons fill the inner shell first. The atomic number is the number of protons, and in a neutral atom it is also the number of electrons. Real arrangements become finer after argon, so this bench stops there.',
  how:
      'Move the atomic number. The gold centre is the nucleus. Each ring is a shell.',
  challenge: 'Build neon, with both shown shells full.',
  icon: Icons.blur_circular_rounded,
  color: AppColors.primary,
  build: AtomLab.new,
);

const enzymeSpec = LabSpec(
  id: 'enzyme',
  subject: 'Biology',
  title: 'Enzymes and temperature',
  blurb: 'Activity rises to an optimum, then the enzyme fails.',
  idea:
      'An enzyme speeds a reaction in a living cell. Warming it helps, up to an optimum. On this curve that peak is 37 °C, a common school example for a human enzyme. Hotter than that, the enzyme loses its shape and the activity collapses. Cold does not destroy it in the same way. It only slows the reaction.',
  how: 'Slide the temperature along the curve. The gold dot is your setting.',
  challenge: 'Set the temperature where this enzyme works best.',
  icon: Icons.biotech_rounded,
  color: AppColors.success,
  build: EnzymeLab.new,
);

const photosynthesisSpec = LabSpec(
  id: 'photosynthesis',
  subject: 'Biology',
  title: 'Limiting factors',
  blurb: 'Light and carbon dioxide set the rate of photosynthesis.',
  idea:
      'A leaf makes food when it has light, carbon dioxide, and a suitable temperature. The rate follows whichever of those is in shortest supply. That one is the limiting factor. Here temperature is kept suitable, so only light and carbon dioxide can hold the rate down. Extra light does nothing once carbon dioxide is the limit.',
  how: 'Raise one factor at a time. The bubbles stand for oxygen given off.',
  challenge: 'Make carbon dioxide the factor that limits a brightly lit leaf.',
  icon: Icons.energy_savings_leaf_rounded,
  color: AppColors.success,
  build: PhotosynthesisLab.new,
);

const pythagorasSpec = LabSpec(
  id: 'pythagoras',
  subject: 'Maths',
  title: 'Pythagoras',
  blurb: 'The squares on the two short sides match the long side.',
  idea:
      'In a right-angled triangle, the square of the longest side equals the squares of the other two sides added together. The longest side is the hypotenuse, opposite the right angle. The coloured squares are drawn on the two shorter sides so you can see the areas that add.',
  how: 'Set the two shorter sides. The readout gives the long side.',
  challenge: 'Build a 3-4-5 triangle.',
  icon: Icons.change_history_rounded,
  color: AppColors.worldExams,
  build: PythagorasLab.new,
);

const chanceSpec = LabSpec(
  id: 'chance',
  subject: 'Maths',
  title: 'A fair spinner',
  blurb: 'The chance of red is its share of the circle.',
  idea:
      'If a spinner is fair, the chance of a colour is the size of its sector divided by the whole circle. A full turn is 360°. A quarter of the circle is 90°, so the chance of red is 90/360, which is 1/4. The rest of the circle is the other colour.',
  how: 'Change the red sector and read the fraction under the wheel.',
  challenge: 'Make the chance of red equal to one quarter.',
  icon: Icons.pie_chart_rounded,
  color: AppColors.spark,
  build: ChanceLab.new,
);

const waterSpec = LabSpec(
  id: 'water-cycle',
  subject: 'Geography',
  title: 'The water cycle',
  blurb: 'Heat lifts water from the sea, and the cloud gives it back.',
  idea:
      'The sun warms the sea and water evaporates. The vapour rises, cools, and condenses into a cloud. When the cloud holds enough, water falls as rain and returns to the sea. This bench shows that loop with one control: how strong the sunshine is. It leaves out rivers, plants, and groundwater.',
  how: 'Turn the sunshine up. Watch vapour rise, then rain begin.',
  challenge: 'Make it rain.',
  icon: Icons.water_drop_rounded,
  color: AppColors.accentTeal,
  build: WaterCycleLab.new,
);

const federalSpec = LabSpec(
  id: 'federal',
  subject: 'Government',
  title: 'Federal and local duties',
  blurb: 'Some jobs belong to Abuja. Some belong to the local government.',
  idea:
      'Nigeria’s constitution gives some matters to the federation alone, including defence and the currency. The local government list includes markets and refuse collection. Education and many roads are shared, so they are left off this bench. The two columns show only the clear cases.',
  how: 'Place each duty with Federal or Local. The board fills as you choose.',
  challenge: 'Place all four duties with the level that holds them.',
  icon: Icons.account_balance_rounded,
  color: AppColors.worldExams,
  build: FederalLab.new,
);

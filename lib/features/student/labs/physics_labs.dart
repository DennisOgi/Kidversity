import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../theme/app_colors.dart';
import 'lab_frame.dart';
import 'lab_math.dart';

class PendulumLab extends StatefulWidget {
  const PendulumLab({super.key});

  @override
  State<PendulumLab> createState() => _PendulumLabState();
}

class _PendulumLabState extends State<PendulumLab>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double length = 1.5;
  double gravity = 9.8;
  double damping = 0.02;
  double theta = math.pi / 3;
  double omega = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
      _last = elapsed;
      if (MediaQuery.disableAnimationsOf(context)) return;
      final alpha = -(gravity / length) * math.sin(theta) - damping * omega;
      setState(() {
        omega += alpha * dt;
        theta += omega * dt;
      });
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _drag(Offset local, Size size) {
    final pivot = Offset(size.width / 2, size.height * 0.16);
    setState(() {
      theta = math.atan2(local.dx - pivot.dx, local.dy - pivot.dy);
      theta = theta.clamp(-1.4, 1.4);
      omega = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final period = pendulumPeriod(length, gravity);
    return LabFrame(
      spec: pendulumSpec,
      challengeMet: (period - 2).abs() < 0.06,
      readout:
          'Angle ${(theta * 180 / math.pi).toStringAsFixed(0)}°   ·   Period about ${period.toStringAsFixed(2)} s',
      stage: LabStage(
        onDrag: _drag,
        child: CustomPaint(
          painter: _PendulumPainter(length: length, theta: theta),
          child: const SizedBox.expand(),
        ),
      ),
      controls: Column(
        children: [
          LabSlider(
            label: 'Length',
            value: '${length.toStringAsFixed(2)} m',
            min: 0.5,
            max: 2.5,
            current: length,
            onChanged: (v) => setState(() => length = v),
          ),
          LabSlider(
            label: 'Gravity',
            value: gravity.toStringAsFixed(1),
            min: 1.6,
            max: 20,
            current: gravity,
            onChanged: (v) => setState(() => gravity = v),
          ),
          LabSlider(
            label: 'Damping',
            value: damping.toStringAsFixed(2),
            min: 0,
            max: 0.2,
            current: damping,
            onChanged: (v) => setState(() => damping = v),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() {
                theta = math.pi / 3;
                omega = 0;
              }),
              child: const Text('Reset swing'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendulumPainter extends CustomPainter {
  final double length;
  final double theta;
  const _PendulumPainter({required this.length, required this.theta});

  @override
  void paint(Canvas canvas, Size size) {
    final pivot = Offset(size.width / 2, size.height * 0.16);
    final bob =
        pivot + Offset(math.sin(theta), math.cos(theta)) * (length * 90);
    final rail = Paint()
      ..color = AppColors.inkSoft
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      pivot + const Offset(-36, 0),
      pivot + const Offset(36, 0),
      rail,
    );
    canvas.drawLine(
      pivot,
      bob,
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 3,
    );
    canvas.drawCircle(bob, 16, Paint()..color = AppColors.spark);
    canvas.drawCircle(
      bob,
      16,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.ink,
    );
  }

  @override
  bool shouldRepaint(covariant _PendulumPainter oldDelegate) =>
      oldDelegate.theta != theta || oldDelegate.length != length;
}

class WaveLab extends StatefulWidget {
  const WaveLab({super.key});

  @override
  State<WaveLab> createState() => _WaveLabState();
}

class _WaveLabState extends State<WaveLab> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double time = 0;
  double frequency = 1.2;
  double amplitude = 70;
  double speed = 1;
  double? probeX;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
      _last = elapsed;
      if (MediaQuery.disableAnimationsOf(context)) return;
      setState(() => time += dt * speed);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  double _y(double x, double width) => math.sin(
    (x / width) * math.pi * 2 * frequency * 2 - time * frequency * 4,
  );

  @override
  Widget build(BuildContext context) {
    final probe = probeX;
    return LabFrame(
      spec: waveSpec,
      challengeMet: (frequency - 1).abs() < 0.08,
      readout: probe == null
          ? 'y = A sin(kx − ωt)'
          : 'At this point the displacement is ${(amplitude * _y(probe, 1)).toStringAsFixed(0)} px',
      stage: LabStage(
        onDrag: (local, size) => setState(() => probeX = local.dx / size.width),
        child: CustomPaint(
          painter: _WavePainter(
            frequency: frequency,
            amplitude: amplitude,
            time: time,
            probe: probe,
          ),
          child: const SizedBox.expand(),
        ),
      ),
      controls: Column(
        children: [
          LabSlider(
            label: 'Frequency',
            value: '${frequency.toStringAsFixed(1)} Hz',
            min: 0.4,
            max: 3,
            current: frequency,
            onChanged: (v) => setState(() => frequency = v),
          ),
          LabSlider(
            label: 'Amplitude',
            value: '${amplitude.round()} px',
            min: 16,
            max: 110,
            current: amplitude,
            onChanged: (v) => setState(() => amplitude = v),
          ),
          LabSlider(
            label: 'Speed',
            value: '${speed.toStringAsFixed(1)}×',
            min: 0.2,
            max: 2.5,
            current: speed,
            onChanged: (v) => setState(() => speed = v),
          ),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double frequency;
  final double amplitude;
  final double time;
  final double? probe;
  const _WavePainter({
    required this.frequency,
    required this.amplitude,
    required this.time,
    required this.probe,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    canvas.drawLine(
      Offset(0, mid),
      Offset(size.width, mid),
      Paint()
        ..color = AppColors.line
        ..strokeWidth = 1,
    );
    final path = Path();
    for (var x = 0.0; x <= size.width; x++) {
      final y =
          mid +
          math.sin(
                (x / size.width) * math.pi * 2 * frequency * 2 -
                    time * frequency * 4,
              ) *
              amplitude;
      if (x == 0) {
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
    final p = probe;
    if (p != null) {
      final x = p * size.width;
      final y =
          mid +
          math.sin(p * math.pi * 2 * frequency * 2 - time * frequency * 4) *
              amplitude;
      canvas.drawCircle(Offset(x, y), 7, Paint()..color = AppColors.spark);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) => true;
}

class RayLab extends StatefulWidget {
  const RayLab({super.key});

  @override
  State<RayLab> createState() => _RayLabState();
}

class _RayLabState extends State<RayLab> {
  double angle = 35;
  double index = 1.5;

  @override
  Widget build(BuildContext context) {
    final result = snellGlassToAir(angle, index);
    final readout = result.reflectsInside
        ? 'Total internal reflection. The ray stays in the glass.'
        : 'Incidence ${angle.round()}°  ·  refraction in air ${result.refractionDegrees!.toStringAsFixed(1)}°';
    return LabFrame(
      spec: raySpec,
      challengeMet: result.reflectsInside,
      readout: readout,
      stage: CustomPaint(
        painter: _RayPainter(angle: angle, index: index, result: result),
        child: const SizedBox.expand(),
      ),
      controls: Column(
        children: [
          LabSlider(
            label: 'Angle from the normal',
            value: '${angle.round()}°',
            min: 5,
            max: 80,
            current: angle,
            onChanged: (v) => setState(() => angle = v),
          ),
          LabSlider(
            label: 'Glass refractive index',
            value: index.toStringAsFixed(2),
            min: 1.2,
            max: 2.2,
            current: index,
            onChanged: (v) => setState(() => index = v),
          ),
        ],
      ),
    );
  }
}

class _RayPainter extends CustomPainter {
  final double angle;
  final double index;
  final SnellResult result;
  const _RayPainter({
    required this.angle,
    required this.index,
    required this.result,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final block = Rect.fromLTWH(
      24,
      size.height * 0.16,
      size.width * 0.46,
      size.height * 0.68,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(block, const Radius.circular(8)),
      Paint()..color = AppColors.primary.withValues(alpha: 0.12),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(block, const Radius.circular(8)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.primary,
    );
    final hit = Offset(block.right, block.center.dy);
    final i = angle * math.pi / 180;
    final travel = Offset(math.cos(i), -math.sin(i));
    final incoming = hit - travel * 160;
    final ray = Paint()
      ..color = AppColors.spark
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(incoming, hit, ray);
    _dashed(canvas, hit + const Offset(-90, 0), hit + const Offset(110, 0));
    if (result.reflectsInside) {
      final reflected = hit + Offset(-math.cos(i), -math.sin(i)) * 150;
      canvas.drawLine(hit, reflected, ray..color = AppColors.danger);
    } else {
      final r = result.refractionDegrees! * math.pi / 180;
      final outside = hit + Offset(math.cos(r), -math.sin(r)) * 160;
      canvas.drawLine(hit, outside, ray);
    }
    _label(canvas, 'glass  n=${index.toStringAsFixed(2)}', block.center);
    _label(canvas, 'air', Offset(hit.dx + 70, block.top + 18));
  }

  void _dashed(Canvas canvas, Offset a, Offset b) {
    final delta = b - a;
    final length = delta.distance;
    if (length == 0) return;
    final step = delta / length;
    final paint = Paint()
      ..color = AppColors.inkSoft
      ..strokeWidth = 1.4;
    for (var t = 0.0; t < length; t += 10) {
      final end = math.min(t + 5, length);
      canvas.drawLine(a + step * t, a + step * end, paint);
    }
  }

  void _label(Canvas canvas, String text, Offset at) {
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
    painter.paint(canvas, at - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _RayPainter oldDelegate) => true;
}

class MomentsLab extends StatefulWidget {
  const MomentsLab({super.key});

  @override
  State<MomentsLab> createState() => _MomentsLabState();
}

class _MomentsLabState extends State<MomentsLab> {
  double leftMass = 200;
  double leftCm = 30;
  double rightMass = 150;
  double rightCm = 40;

  @override
  Widget build(BuildContext context) {
    final left = moment(leftMass, leftCm);
    final right = moment(rightMass, rightCm);
    final balanced = momentsBalanced(leftMass, leftCm, rightMass, rightCm);
    final set =
        (leftMass - 200).abs() < 8 && (leftCm - 40).abs() < 1.2 && balanced;
    return LabFrame(
      spec: momentsSpec,
      challengeMet: set,
      readout: balanced
          ? 'Balanced. ${left.round()} = ${right.round()} g·cm'
          : 'Clockwise ${right.round()} g·cm   ·   anticlockwise ${left.round()} g·cm',
      stage: CustomPaint(
        painter: _MomentsPainter(
          leftMass: leftMass,
          leftCm: leftCm,
          rightMass: rightMass,
          rightCm: rightCm,
        ),
        child: const SizedBox.expand(),
      ),
      controls: Column(
        children: [
          LabSlider(
            label: 'Left mass',
            value: '${leftMass.round()} g',
            min: 50,
            max: 400,
            current: leftMass,
            onChanged: (v) => setState(() => leftMass = v),
          ),
          LabSlider(
            label: 'Left distance',
            value: '${leftCm.round()} cm',
            min: 10,
            max: 50,
            current: leftCm,
            onChanged: (v) => setState(() => leftCm = v),
          ),
          LabSlider(
            label: 'Right mass',
            value: '${rightMass.round()} g',
            min: 50,
            max: 400,
            current: rightMass,
            onChanged: (v) => setState(() => rightMass = v),
          ),
          LabSlider(
            label: 'Right distance',
            value: '${rightCm.round()} cm',
            min: 10,
            max: 50,
            current: rightCm,
            onChanged: (v) => setState(() => rightCm = v),
          ),
        ],
      ),
    );
  }
}

class _MomentsPainter extends CustomPainter {
  final double leftMass;
  final double leftCm;
  final double rightMass;
  final double rightCm;
  const _MomentsPainter({
    required this.leftMass,
    required this.leftCm,
    required this.rightMass,
    required this.rightCm,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pivot = Offset(size.width / 2, size.height * 0.58);
    final tilt =
        ((moment(leftMass, leftCm) - moment(rightMass, rightCm)) / 8000).clamp(
          -0.28,
          0.28,
        );
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(-tilt);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-180, -8, 360, 16),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFF8A5A2A),
    );
    _hang(canvas, -leftCm * 3.2, leftMass, AppColors.primary);
    _hang(canvas, rightCm * 3.2, rightMass, AppColors.accentTeal);
    canvas.restore();
    final triangle = Path()
      ..moveTo(pivot.dx, pivot.dy + 6)
      ..lineTo(pivot.dx - 16, pivot.dy + 34)
      ..lineTo(pivot.dx + 16, pivot.dy + 34)
      ..close();
    canvas.drawPath(triangle, Paint()..color = AppColors.ink);
  }

  void _hang(Canvas canvas, double x, double mass, Color color) {
    canvas.drawLine(
      Offset(x, 8),
      Offset(x, 48),
      Paint()
        ..color = AppColors.inkSoft
        ..strokeWidth = 2,
    );
    final radius = 10 + mass / 40;
    canvas.drawCircle(Offset(x, 48 + radius), radius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _MomentsPainter oldDelegate) => true;
}

class PistonLab extends StatefulWidget {
  const PistonLab({super.key});

  @override
  State<PistonLab> createState() => _PistonLabState();
}

class _PistonLabState extends State<PistonLab>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double volume = 1.2;
  double temperature = 300;
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
    final pressure = gasPressure(
      amount: 0.08,
      temperatureKelvin: temperature,
      volumeLitres: volume,
    );
    final halved = (volume - 0.6).abs() < 0.06 && (temperature - 300).abs() < 8;
    return LabFrame(
      spec: pistonSpec,
      challengeMet: halved,
      readout:
          'P = ${pressure.toStringAsFixed(2)}   ·   V = ${volume.toStringAsFixed(2)} L   ·   T = ${temperature.round()} K',
      stage: LabStage(
        onDrag: (local, size) {
          final t = ((local.dx - 80) / (size.width - 160)).clamp(0.0, 1.0);
          setState(() => volume = 0.5 + t * 1.8);
        },
        child: CustomPaint(
          painter: _PistonPainter(
            volume: volume,
            temperature: temperature,
            phase: phase,
          ),
          child: const SizedBox.expand(),
        ),
      ),
      controls: Column(
        children: [
          LabSlider(
            label: 'Volume',
            value: '${volume.toStringAsFixed(2)} L',
            min: 0.5,
            max: 2.3,
            current: volume,
            onChanged: (v) => setState(() => volume = v),
          ),
          LabSlider(
            label: 'Temperature',
            value: '${temperature.round()} K',
            min: 250,
            max: 450,
            current: temperature,
            onChanged: (v) => setState(() => temperature = v),
          ),
        ],
      ),
    );
  }
}

class _PistonPainter extends CustomPainter {
  final double volume;
  final double temperature;
  final double phase;
  const _PistonPainter({
    required this.volume,
    required this.temperature,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final chamber = Rect.fromLTWH(70, 80, size.width - 140, size.height - 150);
    final span = (volume - 0.5) / 1.8;
    final pistonX = chamber.left + 24 + span * (chamber.width - 70);
    canvas.drawRRect(
      RRect.fromRectAndRadius(chamber, const Radius.circular(12)),
      Paint()..color = AppColors.primarySoft,
    );
    canvas.drawRect(
      Rect.fromLTRB(chamber.left, chamber.top, pistonX, chamber.bottom),
      Paint()..color = const Color(0xFFD7F3EE),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(pistonX - 8, chamber.top - 8, 18, chamber.height + 16),
        const Radius.circular(4),
      ),
      Paint()..color = AppColors.ink,
    );
    final speed = 40 + (temperature - 250) / 4 + (2.3 - volume) * 30;
    for (var i = 0; i < 14; i++) {
      final u = (phase * speed / 80 + i * 0.17) % 1;
      final x = chamber.left + 16 + u * (pistonX - chamber.left - 28);
      final y = chamber.top + 18 + ((i * 47) % (chamber.height - 36));
      canvas.drawCircle(
        Offset(x, y),
        5,
        Paint()..color = AppColors.accentTeal.withValues(alpha: 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PistonPainter oldDelegate) => true;
}

const pendulumSpec = LabSpec(
  id: 'pendulum',
  subject: 'Physics',
  title: 'Simple pendulum',
  blurb: 'Length and gravity set the period. Drag the bob.',
  idea:
      'A pendulum swings because gravity pulls the bob back toward the middle. A longer string swings more slowly. Stronger gravity swings it faster. The period is the time for one full swing: about 2π times the square root of length divided by gravity. Damping is friction. It does not change the timing much, but the swing dies away.',
  how:
      'Drag the bob to a new angle. Then change length and gravity and watch the timing.',
  challenge: 'Make the period about 2.0 seconds.',
  icon: Icons.schedule_rounded,
  color: AppColors.primary,
  build: PendulumLab.new,
);

const waveSpec = LabSpec(
  id: 'wave',
  subject: 'Physics',
  title: 'Traveling wave',
  blurb: 'Frequency, amplitude, and a point you can follow.',
  idea:
      'A wave carries a disturbance along without carrying the material with it. Amplitude is how far a point moves from the middle. Frequency is how many waves pass each second. Drag along the wave to read the displacement at one place.',
  how:
      'Drag across the wave. Then raise the frequency and watch the crests pack closer.',
  challenge: 'Set the frequency so two full wavelengths fit across the stage.',
  icon: Icons.graphic_eq_rounded,
  color: AppColors.accentTeal,
  build: WaveLab.new,
);

const raySpec = LabSpec(
  id: 'ray',
  subject: 'Physics',
  title: 'Ray box',
  blurb: 'A ray leaves glass and can reflect back inside.',
  idea:
      'Light speeds up when it leaves glass for air, so it bends away from the normal. The normal is the dashed line at right angles to the surface. Past a critical angle, there is no path out: the ray reflects inside the glass. That is total internal reflection. A higher refractive index makes the critical angle smaller.',
  how: 'Raise the angle from the normal. The gold ray is the one you control.',
  challenge: 'Find an angle where the ray reflects inside the glass.',
  icon: Icons.wb_twilight_rounded,
  color: AppColors.worldExams,
  build: RayLab.new,
);

const momentsSpec = LabSpec(
  id: 'moments',
  subject: 'Physics',
  title: 'Balancing moments',
  blurb: 'A beam tips until both sides pull equally.',
  idea:
      'The turning effect of a force is its moment: mass times distance from the pivot, when the weights hang straight down. The beam balances when the anticlockwise moment equals the clockwise moment. A light mass far from the pivot can balance a heavy mass close in.',
  how:
      'Move the masses and their distances. The beam tilts toward the larger moment.',
  challenge: 'Balance 200 g at 40 cm on the left.',
  icon: Icons.straighten_rounded,
  color: Color(0xFF8A5A2A),
  build: MomentsLab.new,
);

const pistonSpec = LabSpec(
  id: 'piston',
  subject: 'Physics',
  title: 'Gas piston',
  blurb: 'Squeeze the gas and the pressure rises.',
  idea:
      'The same amount of gas in a smaller volume hits the walls more often, so the pressure rises. Warming the gas makes the particles faster, so the pressure rises even if you do not move the piston. Here pressure stays proportional to temperature divided by volume.',
  how:
      'Drag the piston, or use the sliders. The dots are a picture of the particles, not a count of real molecules.',
  challenge:
      'Halve the volume without changing temperature, and watch the pressure double.',
  icon: Icons.compress_rounded,
  color: AppColors.accentTeal,
  build: PistonLab.new,
);

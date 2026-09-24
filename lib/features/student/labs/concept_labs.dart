import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../theme/app_colors.dart';
import 'lab_frame.dart';
import 'lab_math.dart';

class OsmosisLab extends StatefulWidget {
  const OsmosisLab({super.key});

  @override
  State<OsmosisLab> createState() => _OsmosisLabState();
}

class _OsmosisLabState extends State<OsmosisLab>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double leftSolute = 0.2;
  double rightSolute = 0.8;
  double shift = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      if (MediaQuery.disableAnimationsOf(context)) {
        setState(() => shift = (rightSolute - leftSolute).clamp(-1.0, 1.0));
        return;
      }
      final target = (rightSolute - leftSolute).clamp(-1.0, 1.0);
      setState(() => shift += (target - shift) * 0.08);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final equal = (leftSolute - rightSolute).abs() < 0.05;
    final toward = leftSolute == rightSolute
        ? 'both sides'
        : leftSolute > rightSolute
        ? 'the left'
        : 'the right';
    return LabFrame(
      spec: osmosisSpec,
      challengeMet: equal,
      readout: equal
          ? 'The levels settle. Water has no preferred direction.'
          : 'Water is moving toward $toward, where the solution is stronger.',
      stage: CustomPaint(
        painter: _OsmosisPainter(
          leftSolute: leftSolute,
          rightSolute: rightSolute,
          shift: shift,
        ),
        child: const SizedBox.expand(),
      ),
      controls: Column(
        children: [
          LabSlider(
            label: 'Left sugar',
            value: '${(leftSolute * 100).round()}%',
            min: 0,
            max: 1,
            current: leftSolute,
            onChanged: (v) => setState(() => leftSolute = v),
          ),
          LabSlider(
            label: 'Right sugar',
            value: '${(rightSolute * 100).round()}%',
            min: 0,
            max: 1,
            current: rightSolute,
            onChanged: (v) => setState(() => rightSolute = v),
          ),
        ],
      ),
    );
  }
}

class _OsmosisPainter extends CustomPainter {
  final double leftSolute;
  final double rightSolute;
  final double shift;

  const _OsmosisPainter({
    required this.leftSolute,
    required this.rightSolute,
    required this.shift,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final well = Rect.fromLTWH(28, 40, size.width - 56, size.height - 80);
    final mid = well.center.dx;
    canvas.drawRRect(
      RRect.fromRectAndRadius(well, const Radius.circular(16)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.ink,
    );
    void side(Rect rect, double solute, double level) {
      final liquid = Rect.fromLTRB(
        rect.left + 2,
        rect.bottom - level,
        rect.right - 2,
        rect.bottom - 2,
      );
      canvas.drawRect(
        liquid,
        Paint()
          ..color = Color.lerp(
            const Color(0xFFD7F3EE),
            const Color(0xFF7A4E9A),
            solute,
          )!,
      );
      final dots = (solute * 10).round();
      for (var i = 0; i < dots; i++) {
        final x = rect.left + 18 + (i % 4) * ((rect.width - 36) / 3);
        final y = rect.bottom - 24 - (i ~/ 4) * 28;
        if (y < liquid.top + 8) continue;
        canvas.drawCircle(
          Offset(x, y),
          5,
          Paint()..color = const Color(0xFF3B2158),
        );
      }
    }

    final base = well.height * 0.42;
    side(
      Rect.fromLTRB(well.left, well.top, mid - 8, well.bottom),
      leftSolute,
      base - shift * 48,
    );
    side(
      Rect.fromLTRB(mid + 8, well.top, well.right, well.bottom),
      rightSolute,
      base + shift * 48,
    );
    canvas.drawLine(
      Offset(mid, well.top + 8),
      Offset(mid, well.bottom - 8),
      Paint()
        ..color = AppColors.inkSoft
        ..strokeWidth = 6,
    );
    final arrow = shift >= 0 ? 1.0 : -1.0;
    if (shift.abs() > 0.08) {
      final y = well.center.dy;
      final paint = Paint()
        ..color = AppColors.primary
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(mid - 26, y), Offset(mid + 26 * arrow, y), paint);
    }
    _text(canvas, 'partially permeable', Offset(mid - 58, well.bottom + 10));
  }

  void _text(Canvas canvas, String text, Offset at) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: AppColors.inkSoft,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _OsmosisPainter oldDelegate) => true;
}

class FoodWebLab extends StatefulWidget {
  const FoodWebLab({super.key});

  @override
  State<FoodWebLab> createState() => _FoodWebLabState();
}

class _FoodWebLabState extends State<FoodWebLab>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  bool grassOn = true;
  bool hopperOn = true;
  bool frogOn = true;
  bool hawkOn = true;
  double grass = 0.62;
  double hopper = 0.4;
  double frog = 0.28;
  double hawk = 0.2;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      final target = foodWebTarget(
        grass: grassOn,
        hopper: hopperOn,
        frog: frogOn,
        hawk: hawkOn,
      );
      final step = MediaQuery.disableAnimationsOf(context) ? 1.0 : 0.06;
      setState(() {
        grass += (target.grass - grass) * step;
        hopper += (target.hopper - hopper) * step;
        frog += (target.frog - frog) * step;
        hawk += (target.hawk - hawk) * step;
      });
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LabFrame(
      spec: foodWebSpec,
      challengeMet: !hawkOn && frog > 0.45 && grassOn && hopperOn,
      readout: _readout,
      stage: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Column(
          children: [
            _Bar(name: 'Grass', value: grass, color: AppColors.success),
            _Bar(name: 'Grasshoppers', value: hopper, color: AppColors.spark),
            _Bar(name: 'Frogs', value: frog, color: AppColors.accentTeal),
            _Bar(name: 'Hawks', value: hawk, color: AppColors.primary),
          ],
        ),
      ),
      controls: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _Toggle(
            label: 'Grass',
            on: grassOn,
            onChanged: (v) => setState(() => grassOn = v),
          ),
          _Toggle(
            label: 'Grasshoppers',
            on: hopperOn,
            onChanged: (v) => setState(() => hopperOn = v),
          ),
          _Toggle(
            label: 'Frogs',
            on: frogOn,
            onChanged: (v) => setState(() => frogOn = v),
          ),
          _Toggle(
            label: 'Hawks',
            on: hawkOn,
            onChanged: (v) => setState(() => hawkOn = v),
          ),
        ],
      ),
    );
  }

  String get _readout {
    if (!grassOn) {
      return 'Without grass, every animal in this web runs out of food.';
    }
    if (!hopperOn) {
      return 'No grasshoppers. The grass grows, and the frogs go hungry.';
    }
    if (!frogOn && !hawkOn) {
      return 'Nothing is eating the grasshoppers, so they rise and the grass falls.';
    }
    if (!frogOn) {
      return 'Hawks have little to eat once the frogs are gone.';
    }
    if (!hawkOn) {
      return 'Frogs are safe from hawks, so they rise and eat more grasshoppers.';
    }
    return 'Each bar is easing toward the balance for the animals you left in.';
  }
}

class _Bar extends StatelessWidget {
  final String name;
  final double value;
  final Color color;
  const _Bar({required this.name, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(name, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: value.clamp(0, 1),
                minHeight: 16,
                color: color,
                backgroundColor: AppColors.line,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final bool on;
  final ValueChanged<bool> onChanged;
  const _Toggle({
    required this.label,
    required this.on,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: on,
      onSelected: onChanged,
      selectedColor: AppColors.primarySoft,
      checkmarkColor: AppColors.primary,
    );
  }
}

class BillLab extends StatefulWidget {
  const BillLab({super.key});

  @override
  State<BillLab> createState() => _BillLabState();
}

class _BillLabState extends State<BillLab> {
  bool assembly = true;
  bool president = false;
  bool court = true;

  @override
  Widget build(BuildContext context) {
    final stop = billOutcome(
      assemblyPasses: assembly,
      presidentSigns: president,
      courtUpholds: court,
    );
    return LabFrame(
      spec: billSpec,
      challengeMet: stop == BillStop.law,
      readout: _sentence(stop),
      stage: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _BillTrack(stop: stop),
        ),
      ),
      controls: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('National Assembly passes it'),
            value: assembly,
            onChanged: (v) => setState(() => assembly = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('President signs it'),
            value: president,
            onChanged: (v) => setState(() => president = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Court upholds it'),
            value: court,
            onChanged: (v) => setState(() => court = v),
          ),
        ],
      ),
    );
  }

  String _sentence(BillStop stop) {
    return switch (stop) {
      BillStop.assembly =>
        'It stops in the Assembly. A bill that is not passed never reaches the President.',
      BillStop.president =>
        'The Assembly passed it, and it is waiting on the President’s signature.',
      BillStop.court =>
        'It was signed, then a court set it aside. It does not remain law.',
      BillStop.law => 'Passed, signed, and upheld. It is law.',
    };
  }
}

class _BillTrack extends StatelessWidget {
  final BillStop stop;
  const _BillTrack({required this.stop});

  @override
  Widget build(BuildContext context) {
    const stops = [
      (BillStop.assembly, 'Assembly', 'Pass or stop'),
      (BillStop.president, 'President', 'Sign or hold'),
      (BillStop.court, 'Court', 'Uphold or set aside'),
      (BillStop.law, 'Law', 'In force'),
    ];
    final reached = stop.index;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < stops.length; i++) ...[
                  if (i > 0)
                    Container(
                      width: 28,
                      height: 3,
                      margin: const EdgeInsets.only(bottom: 36),
                      color: i <= reached ? AppColors.primary : AppColors.line,
                    ),
                  SizedBox(
                    width: 108,
                    child: _Station(
                      title: stops[i].$2,
                      caption: stops[i].$3,
                      done: i < reached || stop == BillStop.law,
                      here: i == reached && stop != BillStop.law,
                    ),
                  ),
                ],
              ],
            ),
          );
        }
        return Row(
          children: [
            for (var i = 0; i < stops.length; i++) ...[
              if (i > 0)
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.only(bottom: 36),
                    color: i <= reached ? AppColors.primary : AppColors.line,
                  ),
                ),
              Expanded(
                flex: 3,
                child: _Station(
                  title: stops[i].$2,
                  caption: stops[i].$3,
                  done: i < reached || stop == BillStop.law,
                  here: i == reached && stop != BillStop.law,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Station extends StatelessWidget {
  final String title;
  final String caption;
  final bool done;
  final bool here;
  const _Station({
    required this.title,
    required this.caption,
    required this.done,
    required this.here,
  });

  @override
  Widget build(BuildContext context) {
    final color = done
        ? AppColors.success
        : here
        ? AppColors.warning
        : AppColors.inkSoft;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(
            done
                ? Icons.check_rounded
                : here
                ? Icons.pause_rounded
                : Icons.circle_outlined,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text(
          caption,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

const osmosisSpec = LabSpec(
  id: 'osmosis',
  subject: 'Biology',
  title: 'Osmosis',
  blurb: 'Water crosses a membrane toward the stronger solution.',
  idea:
      'A partially permeable membrane lets water through and holds the sugar back. Water moves from the weaker solution to the stronger one, so the stronger side rises. When both sides have the same strength, the levels settle. The dots are sugar. They do not cross.',
  how: 'Change the sugar on each side and watch which level rises.',
  challenge: 'Make the two levels settle at the same height.',
  icon: Icons.water_drop_rounded,
  color: AppColors.accentTeal,
  build: OsmosisLab.new,
);

const foodWebSpec = LabSpec(
  id: 'food-web',
  subject: 'Biology',
  title: 'A small food web',
  blurb: 'Remove one living thing and watch the others shift.',
  idea:
      'Grass feeds grasshoppers. Grasshoppers feed frogs. Frogs feed hawks. Take one out and the others move: prey rise when their hunter is gone, and a hunter falls when its food is gone. This is a simplified teaching picture with four on/off populations. It is not a full ecosystem, and the bars are not real counts.',
  how: 'Turn each population on or off. The bars ease toward a new balance.',
  challenge: 'Remove only the hawks, and watch the frogs rise.',
  icon: Icons.park_rounded,
  color: AppColors.success,
  build: FoodWebLab.new,
);

const billSpec = LabSpec(
  id: 'bill',
  subject: 'Government',
  title: 'How a bill becomes law',
  blurb: 'A bill has to clear the Assembly, the President, and the court.',
  idea:
      'In this simplified Nigerian path, a bill starts in the National Assembly. If they pass it, it goes to the President to sign. A signed Act can still be taken to court. If the court sets it aside, it does not stay in force. This bench leaves out committees, the two chambers, and a veto override, so you can see the three decisions that stop or pass a bill.',
  how: 'Flip each decision. The track stops at the first one that fails.',
  challenge: 'Get the bill all the way to law.',
  icon: Icons.account_balance_rounded,
  color: AppColors.worldExams,
  build: BillLab.new,
);

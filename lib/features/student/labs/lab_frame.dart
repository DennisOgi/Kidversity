import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../widgets/surfaces.dart';

class LabSpec {
  final String id;
  final String subject;
  final String title;
  final String blurb;
  final String idea;
  final String how;
  final String challenge;
  final IconData icon;
  final Color color;
  final Widget Function() build;

  const LabSpec({
    required this.id,
    required this.subject,
    required this.title,
    required this.blurb,
    required this.idea,
    required this.how,
    required this.challenge,
    required this.icon,
    required this.color,
    required this.build,
  });
}

class LabFrame extends StatelessWidget {
  final LabSpec spec;
  final Widget stage;
  final Widget controls;
  final String readout;
  final bool challengeMet;

  const LabFrame({
    super.key,
    required this.spec,
    required this.stage,
    required this.controls,
    required this.readout,
    this.challengeMet = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 860;
        final deck = _StageDeck(
          spec: spec,
          stage: stage,
          readout: readout,
          tall: wide,
        );
        final story = _LabStory(
          spec: spec,
          controls: controls,
          challengeMet: challengeMet,
        );
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [deck, const SizedBox(height: 16), story],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: deck),
            const SizedBox(width: 22),
            Expanded(flex: 2, child: story),
          ],
        );
      },
    );
  }
}

class _StageDeck extends StatelessWidget {
  final LabSpec spec;
  final Widget stage;
  final String readout;
  final bool tall;

  const _StageDeck({
    required this.spec,
    required this.stage,
    required this.readout,
    required this.tall,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: spec.color.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 6, color: spec.color),
            SizedBox(
              height: tall ? 460 : 320,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const CustomPaint(painter: _BenchGridPainter()),
                  stage,
                ],
              ),
            ),
            ColoredBox(
              color: AppColors.primarySoft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Text(
                  readout,
                  style: text.titleSmall?.copyWith(
                    color: AppColors.primary,
                    height: 1.35,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenchGridPainter extends CustomPainter {
  const _BenchGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF8F7F2),
    );
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LabStory extends StatelessWidget {
  final LabSpec spec;
  final Widget controls;
  final bool challengeMet;

  const _LabStory({
    required this.spec,
    required this.controls,
    required this.challengeMet,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tone = challengeMet ? AppColors.success : AppColors.warning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(spec.subject, color: spec.color),
        const SizedBox(height: 8),
        Text(spec.title, style: text.headlineSmall),
        const SizedBox(height: 14),
        Text('The idea', style: text.titleSmall),
        const SizedBox(height: 6),
        Text(spec.idea, style: text.bodyLarge?.copyWith(height: 1.45)),
        const SizedBox(height: 14),
        Text('How to use it', style: text.titleSmall),
        const SizedBox(height: 6),
        Text(
          spec.how,
          style: text.bodyMedium?.copyWith(
            color: AppColors.inkSoft,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        DecoratedBox(
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border(left: BorderSide(color: tone, width: 4)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  challengeMet
                      ? Icons.check_circle_rounded
                      : Icons.flag_rounded,
                  size: 18,
                  color: tone,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    challengeMet ? 'Done. ${spec.challenge}' : spec.challenge,
                    style: text.bodyMedium?.copyWith(height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Controls', style: text.titleSmall),
                const SizedBox(height: 4),
                controls,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class LabSlider extends StatelessWidget {
  final String label;
  final String value;
  final double min;
  final double max;
  final double current;
  final ValueChanged<double> onChanged;

  const LabSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: AppColors.primary),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: current.clamp(min, max),
            min: min,
            max: max,
            activeColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class LabStage extends StatelessWidget {
  final Widget child;
  final void Function(Offset local, Size size)? onDrag;

  const LabStage({super.key, required this.child, this.onDrag});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: onDrag == null
              ? null
              : (details) => onDrag!(details.localPosition, size),
          onPanUpdate: onDrag == null
              ? null
              : (details) => onDrag!(details.localPosition, size),
          child: child,
        );
      },
    );
  }
}

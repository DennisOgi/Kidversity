import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'surfaces.dart';

/// Featured door into the labs bench. Painted header, then the title.
class LabsEntryCard extends StatelessWidget {
  final VoidCallback onTap;
  final bool featured;

  const LabsEntryCard({super.key, required this.onTap, this.featured = false});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Labs', color: AppColors.accentTeal),
        const SizedBox(height: 6),
        Text(
          featured ? 'A bench for the ideas in class' : 'Run an experiment',
          style: text.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Physics, chemistry, biology, maths, the water cycle, and how government works. Change one thing and watch the result.',
          style: text.bodyMedium,
        ),
      ],
    );
    return LiftCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      hoverBorder: AppColors.accentTeal.withValues(alpha: 0.45),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sideBySide = constraints.maxWidth >= 640;
          const art = ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
            child: SizedBox(
              height: 168,
              width: double.infinity,
              child: CustomPaint(painter: _ShelfPainter()),
            ),
          );
          if (!sideBySide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                art,
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: copy,
                ),
              ],
            );
          }
          return Row(
            children: [
              const ClipRRect(
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(17),
                ),
                child: SizedBox(
                  width: 280,
                  height: 168,
                  child: CustomPaint(painter: _ShelfPainter()),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: copy,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.inkSoft,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ShelfPainter extends CustomPainter {
  const _ShelfPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE7F6F3), Color(0xFFF7F4EC), Color(0xFFEDE8FF)],
        ).createShader(rect),
    );
    final bench = Paint()
      ..color = const Color(0xFF8A5A2A)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(18, size.height * 0.78),
      Offset(size.width - 18, size.height * 0.78),
      bench,
    );

    final pivot = Offset(size.width * 0.22, size.height * 0.22);
    final bob = pivot + const Offset(18, 62);
    canvas.drawLine(
      pivot + const Offset(-16, 0),
      pivot + const Offset(16, 0),
      Paint()
        ..color = AppColors.ink
        ..strokeWidth = 3,
    );
    canvas.drawLine(
      pivot,
      bob,
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 2,
    );
    canvas.drawCircle(bob, 10, Paint()..color = AppColors.spark);

    final flask = Path()
      ..moveTo(size.width * 0.48, size.height * 0.34)
      ..lineTo(size.width * 0.42, size.height * 0.7)
      ..quadraticBezierTo(
        size.width * 0.55,
        size.height * 0.84,
        size.width * 0.68,
        size.height * 0.7,
      )
      ..lineTo(size.width * 0.62, size.height * 0.34)
      ..close();
    canvas.drawPath(
      flask,
      Paint()..color = const Color(0xFFE24B8A).withValues(alpha: 0.55),
    );
    canvas.drawPath(
      flask,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.ink,
    );

    final wave = Path();
    final base = size.height * 0.28;
    for (var i = 0; i <= 8; i++) {
      final x = size.width * 0.72 + i * ((size.width * 0.24) / 8);
      final y = base + (i.isEven ? -10 : 10);
      if (i == 0) {
        wave.moveTo(x, y);
      } else {
        wave.lineTo(x, y);
      }
    }
    canvas.drawPath(
      wave,
      Paint()
        ..color = AppColors.accentTeal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(size.width * 0.84, size.height * 0.16),
      8,
      Paint()..color = AppColors.spark,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

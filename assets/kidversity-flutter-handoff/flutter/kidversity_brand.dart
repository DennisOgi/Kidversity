import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'kidversity_theme.dart';

/// Font-independent canonical open-door mark; matches assets/brand/*.svg.
class KidversityMark extends StatelessWidget {
  const KidversityMark({super.key, this.size = 32, this.color = KvColors.primary});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(painter: _DoorPainter(color)),
        ),
      );
}

class _DoorPainter extends CustomPainter {
  const _DoorPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64, size.height / 64);
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..moveTo(8, 60)
      ..lineTo(8, 28)
      ..cubicTo(8, 14.745, 18.745, 4, 32, 4)
      ..cubicTo(45.255, 4, 56, 14.745, 56, 28)
      ..lineTo(56, 60)
      ..close()
      ..moveTo(26, 60)
      ..lineTo(26, 29)
      ..cubicTo(26, 23.477, 30.477, 19, 36, 19)
      ..cubicTo(41.523, 19, 46, 23.477, 46, 29)
      ..lineTo(46, 60)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DoorPainter oldDelegate) => oldDelegate.color != color;
}

class KidversityBrand extends StatelessWidget {
  const KidversityBrand({super.key, this.compact = false, this.reversed = false});
  final bool compact;
  final bool reversed;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          KidversityMark(size: compact ? 24 : 32, color: reversed ? Colors.white : KvColors.primary),
          SizedBox(width: compact ? 8 : 10),
          Text('kidversity', style: GoogleFonts.plusJakartaSans(
            fontSize: compact ? 20 : 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
            color: reversed ? Colors.white : KvColors.ink,
          )),
        ],
      );
}

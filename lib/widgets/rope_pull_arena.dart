import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/rope_pull_models.dart';
import '../theme/app_colors.dart';
import 'common.dart';

const kRopeBlue = Color(0xFF3D7CFF);
const kRopeRed = Color(0xFFC44536);

TextStyle ropePullText({
  double size = 15,
  FontWeight weight = FontWeight.w700,
  Color color = AppColors.ink,
  double height = 1.25,
  double letterSpacing = 0,
}) {
  return GoogleFonts.nunito(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

class RopePullArenaLayout {
  final double width;
  final double height;
  final double pull;
  final double centerX;
  final double ropeY;
  final double foxW;
  final double foxH;
  final double foxTop;
  final double leftFoxX;
  final double rightFoxX;
  final double knotX;
  final double knotSize;
  final Offset leftHand;
  final Offset rightHand;

  const RopePullArenaLayout({
    required this.width,
    required this.height,
    required this.pull,
    required this.centerX,
    required this.ropeY,
    required this.foxW,
    required this.foxH,
    required this.foxTop,
    required this.leftFoxX,
    required this.rightFoxX,
    required this.knotX,
    required this.knotSize,
    required this.leftHand,
    required this.rightHand,
  });

  factory RopePullArenaLayout.of({
    required double width,
    required double height,
    required double pull,
  }) {
    final centerX = width / 2;
    const pad = 8.0;
    final maxShift = (width * 0.055).clamp(8.0, 18.0);
    final knotSize = (height * 0.30).clamp(44.0, 64.0);
    final gap = (knotSize + 20).clamp(60.0, 84.0);
    final maxFox = ((width - gap - pad * 2 - maxShift * 2) / 2).clamp(
      72.0,
      150.0,
    );
    final foxW = math.min(height * 0.82, maxFox);
    final foxH = foxW;
    final total = foxW * 2 + gap;
    final origin = (width - total) / 2;
    final shift = pull * maxShift;
    final leftFoxX = origin + shift;
    final rightFoxX = origin + foxW + gap + shift;
    final foxTop = ((height - foxH) * 0.42).clamp(8.0, height * 0.2);
    final ropeY = foxTop + foxH * 0.54;
    final leftHand = Offset(leftFoxX + foxW * 0.58, ropeY);
    final rightHand = Offset(rightFoxX + foxW * 0.42, ropeY);
    final t = (0.5 + pull * 0.36).clamp(0.14, 0.86);
    final knotX = leftHand.dx + (rightHand.dx - leftHand.dx) * t;
    return RopePullArenaLayout(
      width: width,
      height: height,
      pull: pull,
      centerX: centerX,
      ropeY: ropeY,
      foxW: foxW,
      foxH: foxH,
      foxTop: foxTop,
      leftFoxX: leftFoxX,
      rightFoxX: rightFoxX,
      knotX: knotX,
      knotSize: knotSize,
      leftHand: leftHand,
      rightHand: rightHand,
    );
  }
}

class RopePullArena extends StatefulWidget {
  final RopePullSnapshot snapshot;
  final double height;
  final bool showScores;

  const RopePullArena({
    super.key,
    required this.snapshot,
    this.height = 220,
    this.showScores = true,
  });

  @override
  State<RopePullArena> createState() => _RopePullArenaState();
}

class _RopePullArenaState extends State<RopePullArena>
    with TickerProviderStateMixin {
  late final AnimationController _wobble;
  late final AnimationController _tug;
  int _lastScore = 0;

  @override
  void initState() {
    super.initState();
    _wobble = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _tug = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _lastScore = widget.snapshot.room.ropeScore;
  }

  @override
  void didUpdateWidget(covariant RopePullArena oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot.room.ropeScore != widget.snapshot.room.ropeScore) {
      _tug.forward(from: 0);
      _lastScore = widget.snapshot.room.ropeScore;
    }
  }

  @override
  void dispose() {
    _wobble.dispose();
    _tug.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snap = widget.snapshot;
    final pull = (_lastScore / 10).clamp(-1.0, 1.0);
    return AnimatedBuilder(
      animation: Listenable.merge([_wobble, _tug]),
      builder: (context, _) {
        final bounce = math.sin(_tug.value * math.pi);
        final yank = Curves.easeOutBack.transform(
          (_tug.value * 1.15).clamp(0.0, 1.0),
        );
        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: widget.height,
            child: LayoutBuilder(
              builder: (context, box) {
                final layout = RopePullArenaLayout.of(
                  width: box.maxWidth,
                  height: box.maxHeight,
                  pull: pull,
                );
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    const Positioned.fill(
                      child: WarmAssetImage(
                        'assets/rope_pull/courtyard.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                    const Positioned.fill(child: _SideWash()),
                    Positioned(
                      left: layout.leftFoxX,
                      top: layout.foxTop + bounce * -3,
                      width: layout.foxW,
                      height: layout.foxH,
                      child: _TeamPullers(
                        left: true,
                        empty: snap.blue.isEmpty,
                        pull: pull,
                        yank: yank,
                      ),
                    ),
                    Positioned(
                      left: layout.rightFoxX,
                      top: layout.foxTop + bounce * -3,
                      width: layout.foxW,
                      height: layout.foxH,
                      child: _TeamPullers(
                        left: false,
                        empty: snap.red.isEmpty,
                        pull: pull,
                        yank: yank,
                      ),
                    ),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ThresholdPainter(
                          centerX: layout.centerX,
                          ropeY: layout.ropeY,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ConnectedRopePainter(
                          leftHand: layout.leftHand,
                          rightHand: layout.rightHand,
                          thickness: (layout.foxW * 0.07).clamp(8.0, 12.0),
                        ),
                      ),
                    ),
                    if (yank > 0.08 && yank < 0.9)
                      Positioned(
                        left: layout.knotX - 36,
                        top: layout.ropeY + layout.knotSize * 0.34,
                        child: const _DustBurst(),
                      ),
                    Positioned(
                      left: layout.knotX - layout.knotSize / 2,
                      top: layout.ropeY - layout.knotSize / 2 + bounce * -3,
                      width: layout.knotSize,
                      height: layout.knotSize,
                      child: Transform.rotate(
                        angle: pull * 0.08,
                        child: const _FoxKnot(),
                      ),
                    ),
                    if (widget.showScores) ...[
                      _TeamBadge(
                        left: true,
                        title: 'Blue',
                        score: snap.blueTugs,
                        color: kRopeBlue,
                        avatars: snap.blue.map((p) => p.avatar).toList(),
                      ),
                      _TeamBadge(
                        left: false,
                        title: 'Red',
                        score: snap.redTugs,
                        color: kRopeRed,
                        avatars: snap.red.map((p) => p.avatar).toList(),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class RopePullHubBanner extends StatelessWidget {
  const RopePullHubBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 168,
        width: double.infinity,
        child: Stack(
          children: [
            const Positioned.fill(
              child: WarmAssetImage(
                'assets/rope_pull/environment/campus-court.png',
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AppColors.ink.withValues(alpha: 0.72),
                      AppColors.ink.withValues(alpha: 0.18),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned(
              right: 92,
              bottom: -4,
              width: 108,
              height: 156,
              child: WarmAssetImage(
                'assets/rope_pull/characters/indigo-captain.png',
                fit: BoxFit.contain,
              ),
            ),
            const Positioned(
              right: 4,
              bottom: -4,
              width: 108,
              height: 156,
              child: WarmAssetImage(
                'assets/rope_pull/characters/teal-captain.png',
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              left: 20,
              right: 210,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'TEAM GAME',
                      style: ropePullText(
                        size: 11,
                        weight: FontWeight.w800,
                        color: AppColors.gold,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rope Pull',
                    style: ropePullText(
                      size: 30,
                      weight: FontWeight.w800,
                      color: AppColors.paper,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Words, past questions, or mental maths.',
                    style: ropePullText(
                      size: 14,
                      color: const Color(0xFFF3E6D4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamBadge extends StatelessWidget {
  final bool left;
  final String title;
  final int score;
  final Color color;
  final List<String> avatars;

  const _TeamBadge({
    required this.left,
    required this.title,
    required this.score,
    required this.color,
    this.avatars = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: left ? Alignment.topLeft : Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Text(
                  '$score',
                  style: ropePullText(
                    size: 12,
                    weight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: ropePullText(
                  size: 13,
                  weight: FontWeight.w800,
                  color: color,
                ),
              ),
              if (avatars.isNotEmpty) ...[
                const SizedBox(width: 6),
                EmojiText(avatars.first, size: 14),
                if (avatars.length > 1)
                  Text(
                    '+${avatars.length - 1}',
                    style: ropePullText(
                      size: 11,
                      weight: FontWeight.w800,
                      color: color,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SideWash extends StatelessWidget {
  const _SideWash();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: ColoredBox(color: kRopeBlue.withValues(alpha: 0.08))),
        Expanded(child: ColoredBox(color: kRopeRed.withValues(alpha: 0.08))),
      ],
    );
  }
}

class _ThresholdPainter extends CustomPainter {
  final double centerX;
  final double ropeY;

  const _ThresholdPainter({required this.centerX, required this.ropeY});

  @override
  void paint(Canvas canvas, Size size) {
    final chalk = Paint()
      ..color = const Color(0xFF4A2E14).withValues(alpha: 0.78)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;
    const dash = 7.0;
    var y = 28.0;
    while (y < size.height - 18) {
      canvas.drawLine(Offset(centerX, y), Offset(centerX, y + 4), chalk);
      y += dash;
    }
    final stone = Path()
      ..moveTo(centerX - 10, size.height - 8)
      ..lineTo(centerX + 10, size.height - 8)
      ..lineTo(centerX, size.height - 22)
      ..close();
    canvas.drawPath(stone, Paint()..color = const Color(0xFFC44536));
    canvas.drawCircle(
      Offset(centerX, ropeY),
      6,
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );
    canvas.drawCircle(
      Offset(centerX, ropeY),
      4,
      Paint()
        ..color = const Color(0xFFE8B84A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
  }

  @override
  bool shouldRepaint(covariant _ThresholdPainter oldDelegate) =>
      oldDelegate.centerX != centerX || oldDelegate.ropeY != ropeY;
}

class _ConnectedRopePainter extends CustomPainter {
  final Offset leftHand;
  final Offset rightHand;
  final double thickness;

  const _ConnectedRopePainter({
    required this.leftHand,
    required this.rightHand,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(leftHand.dx, leftHand.dy)
      ..lineTo(rightHand.dx, rightHand.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF6B3F1A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness + 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFC9A066)
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFE8C98A).withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, thickness * 0.28)
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ConnectedRopePainter oldDelegate) =>
      oldDelegate.leftHand != leftHand ||
      oldDelegate.rightHand != rightHand ||
      oldDelegate.thickness != thickness;
}

class _DustBurst extends StatelessWidget {
  const _DustBurst();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Container(
            width: 7 + (i % 3) * 3,
            height: 7 + (i % 3) * 3,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF8B5A2B).withValues(alpha: 0.28),
            ),
          ),
      ],
    );
  }
}

class _FoxKnot extends StatelessWidget {
  const _FoxKnot();

  @override
  Widget build(BuildContext context) {
    return const WarmAssetImage(
      'assets/rope_pull/knot_clear.png',
      fit: BoxFit.contain,
    );
  }
}

class _TeamPullers extends StatelessWidget {
  final bool left;
  final bool empty;
  final double pull;
  final double yank;

  const _TeamPullers({
    required this.left,
    required this.empty,
    required this.pull,
    required this.yank,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: empty ? 0.45 : 1,
      child: Transform.rotate(
        angle:
            (left ? -0.03 : 0.03) + pull * 0.10 + yank * (left ? -0.05 : 0.05),
        child: WarmAssetImage(
          left
              ? 'assets/rope_pull/jade_puller_clear.png'
              : 'assets/rope_pull/cinnabar_puller_clear.png',
          fit: BoxFit.contain,
          alignment: Alignment.center,
        ),
      ),
    );
  }
}

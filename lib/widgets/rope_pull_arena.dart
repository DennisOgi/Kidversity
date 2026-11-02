// Shared Rope Pull text style and the hub banner.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import 'common.dart';

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
                'assets/rope_pull/scene/hero.jpg',
                fit: BoxFit.cover,
                alignment: Alignment(0.6, 0.2),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: const [0.0, 0.55, 1.0],
                    colors: [
                      AppColors.ink.withValues(alpha: 0.82),
                      AppColors.ink.withValues(alpha: 0.35),
                      AppColors.ink.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 120,
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

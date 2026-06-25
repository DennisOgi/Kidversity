import 'package:flutter/material.dart';

/// Central color palette for Kidversity.
///
/// The palette is intentionally playful (great for K-12) while staying
/// premium and accessible (AA contrast on the primary actions).
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF6C5CE7); // violet
  static const Color primaryDark = Color(0xFF4B3FC4);
  static const Color primarySoft = Color(0xFFEDEBFF);

  static const Color secondary = Color(0xFFFF7A59); // coral
  static const Color secondarySoft = Color(0xFFFFE6DE);

  static const Color accentTeal = Color(0xFF00CEC9);
  static const Color accentYellow = Color(0xFFFFC233);
  static const Color accentPink = Color(0xFFFF5DA2);
  static const Color accentBlue = Color(0xFF4DA3FF);

  // Semantic
  static const Color success = Color(0xFF22C55E);
  static const Color successSoft = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerSoft = Color(0xFFFEE2E2);

  // Neutrals
  static const Color ink = Color(0xFF1B1830);
  static const Color inkSoft = Color(0xFF514E6A);
  static const Color muted = Color(0xFF8E8BA7);
  static const Color line = Color(0xFFE9E7F3);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF6F5FC);
  static const Color backgroundAlt = Color(0xFFF0EEFB);

  // Gradients
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C6CFF), Color(0xFF6C5CE7), Color(0xFF5A4FD6)],
  );

  static const LinearGradient sunsetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF9A6C), Color(0xFFFF7A59)],
  );

  static const LinearGradient tealGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2BE3D8), Color(0xFF00CEC9)],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD86B), Color(0xFFFFB020)],
  );

  static const List<Color> subjectColors = [
    Color(0xFF6C5CE7),
    Color(0xFFFF7A59),
    Color(0xFF00CEC9),
    Color(0xFF4DA3FF),
    Color(0xFFFF5DA2),
    Color(0xFFFFC233),
  ];
}

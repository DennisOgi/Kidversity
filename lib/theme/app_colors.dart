import 'package:flutter/material.dart';

/// Central color palette for Kidversity.
///
/// The palette is intentionally playful (great for K-12) while staying
/// premium and accessible (AA contrast on the primary actions).
class AppColors {
  AppColors._();

  // Mandarin Foundation brand
  static const Color cinnabar = Color(0xFFC44536);
  static const Color cinnabarDark = Color(0xFF943126);
  static const Color cinnabarSoft = Color(0xFFF5DED8);
  static const Color paper = Color(0xFFF7F1E8);
  static const Color gold = Color(0xFFE8B84A);
  static const Color jade = Color(0xFF2F6B5A);

  static const Color primary = cinnabar;
  static const Color primaryDark = cinnabarDark;
  static const Color primarySoft = cinnabarSoft;

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
  static const Color ink = Color(0xFF1A1410);
  static const Color inkSoft = Color(0xFF5B5048);
  static const Color muted = Color(0xFF887A70);
  static const Color line = Color(0xFFE5D9CA);
  static const Color surface = Color(0xFFFFFCF7);
  static const Color background = paper;
  static const Color backgroundAlt = Color(0xFFEFE5D8);

  // Gradients
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD35B49), cinnabar, cinnabarDark],
  );

  static const LinearGradient mandarinGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF38271E), ink, Color(0xFF562A22)],
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
    cinnabar,
    jade,
    gold,
    Color(0xFF527A8E),
    Color(0xFF9B5A6D),
    Color(0xFFB9793B),
  ];
}

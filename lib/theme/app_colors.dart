import 'package:flutter/material.dart';

/// Kidversity light theme. Neutral surfaces, indigo actions, world accents.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF4433CC);
  static const Color primaryPressed = Color(0xFF3526A6);
  static const Color primarySoft = Color(0xFFEEEBFF);
  static const Color primaryTint = primarySoft;

  static const Color ink = Color(0xFF20213B);
  static const Color inkSoft = Color(0xFF595B72);
  static const Color muted = Color(0xFF73778B);
  static const Color line = Color(0xFFDADDEA);
  static const Color controlBorder = Color(0xFF73778B);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color paper = Color(0xFFF5F6FB);
  static const Color background = paper;
  static const Color backgroundAlt = Color(0xFFEEEFF6);

  static const Color spark = Color(0xFFF5C56A);
  static const Color worldLanguage = Color(0xFF6751B5);
  static const Color worldExams = Color(0xFF2456A6);
  static const Color worldPlay = Color(0xFF916015);

  static const Color success = Color(0xFF16714A);
  static const Color successSoft = Color(0xFFE5F6EE);
  static const Color warning = Color(0xFF865B00);
  static const Color danger = Color(0xFFB42332);
  static const Color dangerSoft = Color(0xFFFDECEE);

  // Names kept so existing screens follow the new system.
  static const Color cinnabar = primary;
  static const Color cinnabarDark = primaryPressed;
  static const Color cinnabarSoft = primarySoft;
  static const Color emerald = primary;
  static const Color emeraldDark = primaryPressed;
  static const Color emeraldSoft = primarySoft;
  static const Color coral = primary;
  static const Color coralDark = primaryPressed;
  static const Color coralSoft = primarySoft;
  static const Color jade = success;
  static const Color gold = spark;
  static const Color sun = spark;
  static const Color cobalt = worldExams;

  static const Color primaryDark = primaryPressed;
  static const Color secondary = worldLanguage;
  static const Color secondarySoft = Color(0xFFEDE8F8);
  static const Color accentTeal = Color(0xFF0F766E);
  static const Color accentYellow = spark;
  static const Color accentPink = Color(0xFF9D4E6C);
  static const Color accentBlue = worldExams;

  static const LinearGradient brandGradient = LinearGradient(
    colors: [primary, primaryPressed],
  );
  static const LinearGradient energyGradient = brandGradient;
  static const LinearGradient sunsetGradient = brandGradient;
  static const LinearGradient mandarinGradient = LinearGradient(
    colors: [Color(0xFF2A2458), Color(0xFF17142E)],
  );
  static const LinearGradient tealGradient = LinearGradient(
    colors: [worldExams, Color(0xFF1A3E78)],
  );
  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFE8B85A), spark],
  );
  static const LinearGradient examGradient = tealGradient;
  static const LinearGradient playGradient = LinearGradient(
    colors: [Color(0xFF8A5A12), worldPlay],
  );

  static const List<Color> subjectColors = [
    primary,
    worldLanguage,
    worldExams,
    worldPlay,
    success,
  ];
}

// Integration starter. Verify against the Flutter SDK in the target repository.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class KvColors {
  static const primary = Color(0xFF4433CC);
  static const primaryPressed = Color(0xFF3526A6);
  static const primaryTint = Color(0xFFEEEBFF);
  static const ink = Color(0xFF20213B);
  static const secondaryText = Color(0xFF595B72);
  static const canvas = Color(0xFFF5F6FB);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFDADDEA);
  static const controlBorder = Color(0xFF73778B);
  static const spark = Color(0xFFF5C56A);
  static const language = Color(0xFF6751B5);
  static const exams = Color(0xFF2456A6);
  static const play = Color(0xFF916015);
  static const success = Color(0xFF16714A);
  static const error = Color(0xFFB42332);
  static const warning = Color(0xFF865B00);
}

abstract final class KvLayout {
  static const compactMax = 600.0;
  static const expandedMin = 1024.0;
  static const contentMax = 1200.0;
  static const readingMax = 720.0;
  static const authMax = 440.0;
  static const navigationWidth = 220.0;
  static const controlRadius = 8.0;
  static const surfaceRadius = 12.0;
  static const minTarget = 48.0;
}

ThemeData buildKidversityLightTheme() {
  const scheme = ColorScheme.light(
    primary: KvColors.primary,
    onPrimary: Colors.white,
    primaryContainer: KvColors.primaryTint,
    onPrimaryContainer: KvColors.primaryPressed,
    secondary: KvColors.primary,
    onSecondary: Colors.white,
    secondaryContainer: KvColors.primaryTint,
    onSecondaryContainer: KvColors.ink,
    surface: KvColors.surface,
    onSurface: KvColors.ink,
    error: KvColors.error,
    onError: Colors.white,
    outline: KvColors.controlBorder,
  );
  final body = GoogleFonts.dmSansTextTheme().apply(
    bodyColor: KvColors.ink,
    displayColor: KvColors.ink,
  );
  TextStyle heading(double size, {double height = 1.2}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: height,
        color: KvColors.ink,
      );
  final text = body.copyWith(
    displayLarge: heading(48, height: 1.12),
    headlineLarge: heading(32),
    headlineMedium: heading(26),
    titleLarge: heading(22, height: 1.3),
    titleMedium: heading(18, height: 1.35),
    bodyLarge: GoogleFonts.dmSans(fontSize: 18, height: 1.6, color: KvColors.ink),
    bodyMedium: GoogleFonts.dmSans(fontSize: 16, height: 1.5, color: KvColors.ink),
    bodySmall: GoogleFonts.dmSans(fontSize: 13, height: 1.45, color: KvColors.secondaryText),
    labelLarge: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600, height: 1.35),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: KvColors.canvas,
    textTheme: text,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    appBarTheme: const AppBarTheme(
      backgroundColor: KvColors.surface,
      foregroundColor: KvColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: KvColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: KvColors.ink,
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: KvColors.controlBorder),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: text.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: KvColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: KvColors.controlBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: KvColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: KvColors.error),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: KvColors.surface,
      indicatorColor: KvColors.primaryTint,
      elevation: 0,
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: KvColors.surface,
      indicatorColor: KvColors.primaryTint,
      selectedIconTheme: IconThemeData(color: KvColors.primary),
      unselectedIconTheme: IconThemeData(color: KvColors.secondaryText),
    ),
    dividerColor: KvColors.border,
  );
}

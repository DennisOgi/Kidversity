import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ACE brand: deep navy with an amber "advance" accent. Academic and calm,
/// distinct from Kidversity's playful palette.
abstract final class Ace {
  static const navy = Color(0xFF0B1F3A);
  static const navySoft = Color(0xFF16325C);
  static const amber = Color(0xFFF2A900);
  static const amberSoft = Color(0xFFFFF4D6);
  static const paper = Color(0xFFF6F7FB);
  static const ink = Color(0xFF14213D);
  static const inkSoft = Color(0xFF5B6478);
  static const line = Color(0xFFE2E5EE);
  static const maths = Color(0xFF2F6FED);
  static const mathsSoft = Color(0xFFE8F0FF);
  static const physics = Color(0xFF0E9F8A);
  static const physicsSoft = Color(0xFFE2F6F2);
  static const good = Color(0xFF1C8C4E);
  static const goodSoft = Color(0xFFE3F5EA);
  static const warn = Color(0xFFB45309);
  static const warnSoft = Color(0xFFFFF1DE);
  static const bad = Color(0xFFB42318);
  static const badSoft = Color(0xFFFDECEA);

  static Color subject(String subject) =>
      subject == 'Physics' ? physics : maths;
  static Color subjectSoft(String subject) =>
      subject == 'Physics' ? physicsSoft : mathsSoft;

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: navy,
        primary: navy,
        secondary: amber,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: paper,
    );
    final text = GoogleFonts.interTextTheme(
      base.textTheme,
    ).apply(bodyColor: ink, displayColor: ink);
    return base.copyWith(
      textTheme: text.copyWith(
        headlineMedium: GoogleFonts.spaceGrotesk(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: ink,
          height: 1.15,
        ),
        titleLarge: GoogleFonts.spaceGrotesk(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navy,
          side: const BorderSide(color: line, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
      ),
    );
  }
}

/// The ACE mark: an upward arrow in a rounded square.
class AceMark extends StatelessWidget {
  final double size;
  final bool onDark;

  const AceMark({super.key, this.size = 34, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: onDark ? Ace.amber : Ace.navy,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(
        Icons.north_east_rounded,
        size: size * 0.62,
        color: onDark ? Ace.navy : Ace.amber,
      ),
    );
  }
}

class AceWordmark extends StatelessWidget {
  final bool onDark;

  const AceWordmark({super.key, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AceMark(onDark: onDark),
        const SizedBox(width: 10),
        Text(
          'ACE',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: onDark ? Colors.white : Ace.navy,
          ),
        ),
      ],
    );
  }
}

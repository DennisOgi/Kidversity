import 'package:flutter/material.dart';

/// A bright color with a soft background and a dark text shade that passes
/// 4.5:1 on the soft background.
@immutable
class AppTint {
  /// Fills: icon tiles, progress bars, decorative shapes.
  final Color strong;

  /// Backgrounds: tinted cards, chips, selected nav items.
  final Color soft;

  /// Text and icons on [soft] or white.
  final Color ink;

  const AppTint(this.strong, this.soft, this.ink);

  static const violet = AppTint(
    Color(0xFF5B3FE0),
    Color(0xFFEEEAFE),
    Color(0xFF4433CC),
  );
  static const coral = AppTint(
    Color(0xFFFF6B5B),
    Color(0xFFFFE9E5),
    Color(0xFFB03A28),
  );
  static const mint = AppTint(
    Color(0xFF22B07D),
    Color(0xFFDDF6EC),
    Color(0xFF0F6B4A),
  );
  static const sky = AppTint(
    Color(0xFF2F8FEA),
    Color(0xFFE0EFFD),
    Color(0xFF1B5FA8),
  );
  static const sun = AppTint(
    Color(0xFFFFC845),
    Color(0xFFFFF1C9),
    Color(0xFF7A5200),
  );
  static const pink = AppTint(
    Color(0xFFE0457B),
    Color(0xFFFDE4F1),
    Color(0xFFA3306F),
  );
  static const slate = AppTint(
    Color(0xFF20213B),
    Color(0xFFE8E9F2),
    Color(0xFF20213B),
  );

  /// Cycled through for nav icon tiles that do not name their own tint.
  static const cycle = [violet, coral, mint, sky, sun, pink];

  /// One color per learning area, used the same way on every screen.
  static const mandarin = coral;
  static const maths = mint;
  static const exams = sky;
  static const labs = sun;
}

/// The color of one role's space: its nav highlight, page background and the
/// label shown in the account menu.
@immutable
class RoleStyle {
  final String label;
  final AppTint tint;
  final Color background;

  const RoleStyle(this.label, this.tint, this.background);

  Color get accent => tint.ink;

  static const student = RoleStyle(
    'Student',
    AppTint.violet,
    Color(0xFFF7F5FF),
  );
  static const teacher = RoleStyle(
    'Teacher',
    AppTint(Color(0xFF15916B), Color(0xFFDDF6EC), Color(0xFF0F6B4A)),
    Color(0xFFF3FAF7),
  );
  static const parent = RoleStyle('Parent', AppTint.coral, Color(0xFFFFF8F5));
  static const school = RoleStyle(
    'School admin',
    AppTint(Color(0xFF4433CC), Color(0xFFE9E8F7), Color(0xFF2E2B6B)),
    Color(0xFFF5F5FB),
  );
  static const reviewer = RoleStyle('Reviewer', AppTint.sky, Color(0xFFF4F8FD));
  static const admin = RoleStyle(
    'Platform admin',
    AppTint.slate,
    Color(0xFFF5F6FB),
  );
}

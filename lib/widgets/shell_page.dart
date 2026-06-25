import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'aurora_background.dart';

/// Full-height backdrop for routes inside the student/teacher shell.
class ShellPage extends StatelessWidget {
  final Widget child;
  final Color accent;

  const ShellPage({
    super.key,
    required this.child,
    this.accent = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return AuroraBackground(
      orbColors: [accent, AppColors.accentTeal, AppColors.accentBlue, accent],
      child: SizedBox.expand(child: child),
    );
  }
}

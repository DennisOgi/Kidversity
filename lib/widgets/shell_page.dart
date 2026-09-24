import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Full-height backdrop for routes inside the student/teacher shell.
class ShellPage extends StatelessWidget {
  final Widget child;

  const ShellPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.paper,
      child: SizedBox.expand(child: child),
    );
  }
}

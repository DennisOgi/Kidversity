import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/common.dart';

/// Quiet mark while authentication bootstraps.
/// Routing stays with GoRouter so this screen never races auth state.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  late final Animation<double> _mark = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOut,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Kidversity',
      child: Scaffold(
        backgroundColor: AppColors.paper,
        body: Center(
          child: FadeTransition(
            opacity: _mark,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [_SplashMark(), SizedBox(height: 28), _SplashBar()],
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashMark extends StatelessWidget {
  const _SplashMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 72,
      height: 72,
      child: KidversityMark(size: 56),
    );
  }
}

class _SplashBar extends StatelessWidget {
  const _SplashBar();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: const SizedBox(
        width: 72,
        child: LinearProgressIndicator(
          minHeight: 3,
          backgroundColor: AppColors.line,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

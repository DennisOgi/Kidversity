import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
  final String? subtitle;

  const NavItem(this.icon, this.activeIcon, this.label, this.path, [this.subtitle]);
}

/// Tab shell — static gradient backdrop + page content + bottom nav.
class AppShell extends StatelessWidget {
  final String currentPath;
  final List<NavItem> items;
  final Widget child;
  final Color accent;

  const AppShell({
    super.key,
    required this.currentPath,
    required this.items,
    required this.child,
    this.accent = AppColors.primary,
  });

  int _selectedIndex() {
    final i = items.indexWhere((item) => item.path == currentPath);
    return i >= 0 ? i : 0;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedIndex();
    final current = items[selected];
    final narrow = MediaQuery.sizeOf(context).width < 380;

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: false,
      body: Column(
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.10),
                    AppColors.background,
                    AppColors.accentBlue.withValues(alpha: 0.08),
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DashboardAppBar(
                      title: current.label,
                      subtitle: current.subtitle,
                      accent: accent,
                      icon: current.activeIcon,
                      onBrandTap: () => context.go(items.first.path),
                    ),
                    Expanded(child: child),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(narrow ? 10 : 16, 6, narrow ? 10 : 16, narrow ? 8 : 10),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: narrow ? 4 : 8, vertical: narrow ? 6 : 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: 0.10),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    for (int i = 0; i < items.length; i++)
                      _NavButton(
                        item: items[i],
                        selected: selected == i,
                        accent: accent,
                        compact: narrow,
                        onTap: () {
                          if (selected != i) context.go(items[i].path);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final NavItem item;
  final bool selected;
  final Color accent;
  final bool compact;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.selected,
    required this.accent,
    this.compact = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(vertical: compact ? 8 : 10),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? item.activeIcon : item.icon,
                  color: selected ? accent : AppColors.muted, size: compact ? 22 : 24),
              SizedBox(height: compact ? 2 : 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 240),
                  style: TextStyle(
                    fontSize: compact ? 10 : 11,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? accent : AppColors.muted,
                  ),
                  child: Text(item.label),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

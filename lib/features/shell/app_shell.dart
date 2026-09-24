import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
  final String? subtitle;

  const NavItem(
    this.icon,
    this.activeIcon,
    this.label,
    this.path, [
    this.subtitle,
  ]);
}

/// Responsive shell. Bottom nav under 600px, navigation rail from 600px.
class AppShell extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = _selectedIndex();
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= 600;

    void select(int index) {
      if (selected != index) context.go(items[index].path);
    }

    Future<void> signOut() async {
      await ref.read(authControllerProvider).signOut();
      if (context.mounted) context.go('/');
    }

    final page = Expanded(
      child: ColoredBox(color: AppColors.paper, child: child),
    );

    if (useRail) {
      return Scaffold(
        backgroundColor: AppColors.paper,
        body: Row(
          children: [
            _SideNav(
              items: items,
              selected: selected,
              onSelect: select,
              onBrandTap: () => context.go(items.first.path),
              onSignOut: signOut,
            ),
            page,
          ],
        ),
      );
    }

    final header = SafeArea(
      bottom: false,
      child: DashboardAppBar(
        onBrandTap: () => context.go(items.first.path),
        onSignOut: signOut,
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Column(children: [header, page]),
      bottomNavigationBar: _BottomNavBar(
        narrow: width < 380,
        accent: accent,
        selected: selected,
        items: items,
        onSelect: select,
      ),
    );
  }
}

class _SideNav extends StatelessWidget {
  final List<NavItem> items;
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onBrandTap;
  final VoidCallback onSignOut;

  const _SideNav({
    required this.items,
    required this.selected,
    required this.onSelect,
    required this.onBrandTap,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        child: SizedBox(
          width: 220,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KidversityBrandMark(compact: true, onTap: onBrandTap),
                const SizedBox(height: 22),
                for (var i = 0; i < items.length; i++) ...[
                  _SideNavButton(
                    item: items[i],
                    selected: selected == i,
                    onTap: () => onSelect(i),
                  ),
                  const SizedBox(height: 6),
                ],
                const Spacer(),
                TextButton.icon(
                  onPressed: onSignOut,
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Sign out'),
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    foregroundColor: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SideNavButton extends StatelessWidget {
  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _SideNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: selected ? AppColors.primaryPressed : AppColors.primarySoft,
        splashColor: selected ? Colors.white24 : AppColors.primarySoft,
        highlightColor: selected
            ? Colors.white.withValues(alpha: 0.08)
            : AppColors.primarySoft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(
                selected ? item.activeIcon : item.icon,
                size: 20,
                color: selected ? Colors.white : AppColors.inkSoft,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? Colors.white : AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width footer nav so Path content and tabs read as one page.
class _BottomNavBar extends StatelessWidget {
  final bool narrow;
  final Color accent;
  final int selected;
  final List<NavItem> items;
  final ValueChanged<int> onSelect;

  const _BottomNavBar({
    required this.narrow,
    required this.accent,
    required this.selected,
    required this.items,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.paper,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.paper,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              narrow ? 8 : 20,
              8,
              narrow ? 8 : 20,
              narrow ? 8 : 10,
            ),
            child: Row(
              key: const Key('bottomNavPill'),
              children: [
                for (int i = 0; i < items.length; i++)
                  _NavButton(
                    item: items[i],
                    selected: selected == i,
                    accent: accent,
                    compact: narrow,
                    onTap: () => onSelect(i),
                  ),
              ],
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
            color: selected
                ? accent.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? item.activeIcon : item.icon,
                color: selected ? accent : AppColors.muted,
                size: compact ? 22 : 24,
              ),
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

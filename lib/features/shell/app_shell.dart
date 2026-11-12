import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/auth_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/motion.dart';
import '../../theme/role_style.dart';
import '../../widgets/common.dart';

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
  final String? subtitle;

  /// Icon tile color in the sidebar. Falls back to [AppTint.cycle].
  final AppTint? tint;

  const NavItem(
    this.icon,
    this.activeIcon,
    this.label,
    this.path, [
    this.subtitle,
    this.tint,
  ]);
}

/// Responsive shell for every signed-in space.
///
/// * 1024px and wider: sidebar with labels, plus a top bar.
/// * 600 to 1023px: a slim rail, plus a top bar.
/// * Under 600px: a compact header and a bottom nav.
class AppShell extends ConsumerWidget {
  final String currentPath;
  final List<NavItem> items;
  final Widget child;
  final RoleStyle style;

  const AppShell({
    super.key,
    required this.currentPath,
    required this.items,
    required this.child,
    this.style = RoleStyle.student,
  });

  int _selectedIndex() {
    final i = items.indexWhere((item) => item.path == currentPath);
    return i >= 0 ? i : 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = _selectedIndex();
    final width = MediaQuery.sizeOf(context).width;
    final auth = ref.watch(authControllerProvider);

    void select(int index) {
      if (selected != index || currentPath != items[index].path) {
        context.go(items[index].path);
      }
    }

    Future<void> signOut() async {
      await ref.read(authControllerProvider).signOut();
      if (context.mounted) context.go('/');
    }

    final account = _AccountButton(
      name: auth.displayName.trim(),
      style: style,
      onSignOut: signOut,
      compact: width < 600,
    );

    final page = ColoredBox(color: style.background, child: child);

    if (width >= 600) {
      final wide = width >= 1024;
      return Scaffold(
        backgroundColor: style.background,
        body: Row(
          children: [
            _SideNav(
              items: items,
              selected: selected,
              style: style,
              wide: wide,
              onSelect: select,
              onBrandTap: () => select(0),
            ),
            Expanded(
              child: Column(
                children: [
                  _TopBar(item: items[selected], account: account),
                  Expanded(child: page),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: style.background,
      body: Column(
        children: [
          _MobileHeader(onBrandTap: () => select(0), account: account),
          Expanded(child: page),
        ],
      ),
      bottomNavigationBar: items.length < 2
          ? null
          : _BottomNavBar(
              narrow: width < 380,
              style: style,
              selected: selected,
              items: items,
              onSelect: select,
            ),
    );
  }
}

AppTint _tintFor(List<NavItem> items, int index) =>
    items[index].tint ?? AppTint.cycle[index % AppTint.cycle.length];

class _SideNav extends StatelessWidget {
  final List<NavItem> items;
  final int selected;
  final RoleStyle style;
  final bool wide;
  final ValueChanged<int> onSelect;
  final VoidCallback onBrandTap;

  const _SideNav({
    required this.items,
    required this.selected,
    required this.style,
    required this.wide,
    required this.onSelect,
    required this.onBrandTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: wide ? 248 : 92,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              wide ? 14 : 10,
              18,
              wide ? 14 : 10,
              14,
            ),
            child: Column(
              crossAxisAlignment: wide
                  ? CrossAxisAlignment.stretch
                  : CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: wide ? 6 : 0),
                  child: KidversityBrandMark(
                    compact: true,
                    showLabel: wide,
                    onTap: onBrandTap,
                  ),
                ),
                const SizedBox(height: 26),
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => SizedBox(height: wide ? 4 : 8),
                    itemBuilder: (context, i) => _SideNavButton(
                      item: items[i],
                      tint: _tintFor(items, i),
                      style: style,
                      selected: selected == i,
                      wide: wide,
                      onTap: () => onSelect(i),
                    ),
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

class _NavTile extends StatelessWidget {
  final IconData icon;
  final AppTint tint;
  final bool selected;

  const _NavTile({
    required this.icon,
    required this.tint,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.of(context, AppMotion.hint),
      curve: AppMotion.curve(context),
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: selected ? tint.strong : tint.soft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        size: 19,
        color: selected
            ? (tint == AppTint.sun ? AppColors.ink : Colors.white)
            : tint.ink,
      ),
    );
  }
}

class _SideNavButton extends StatelessWidget {
  final NavItem item;
  final AppTint tint;
  final RoleStyle style;
  final bool selected;
  final bool wide;
  final VoidCallback onTap;

  const _SideNavButton({
    required this.item,
    required this.tint,
    required this.style,
    required this.selected,
    required this.wide,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tile = _NavTile(
      icon: selected ? item.activeIcon : item.icon,
      tint: tint,
      selected: selected,
    );

    final content = wide
        ? Row(
            children: [
              tile,
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? style.accent : AppColors.ink,
                  ),
                ),
              ),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              tile,
              const SizedBox(height: 4),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? style.accent : AppColors.inkSoft,
                ),
              ),
            ],
          );

    final button = Semantics(
      selected: selected,
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: Material(
        color: selected ? style.tint.soft : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: style.tint.soft.withValues(alpha: 0.6),
          child: Padding(
            padding: wide
                ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
                : const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: content,
          ),
        ),
      ),
    );
    return wide ? button : Tooltip(message: item.label, child: button);
  }
}

class _TopBar extends StatelessWidget {
  final NavItem item;
  final Widget account;

  const _TopBar({required this.item, required this.account});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        bottom: false,
        left: false,
        child: SizedBox(
          height: 68,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                          height: 1.2,
                        ),
                      ),
                      if (item.subtitle != null)
                        Text(
                          item.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.inkSoft,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                account,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileHeader extends StatelessWidget {
  final VoidCallback onBrandTap;
  final Widget account;

  const _MobileHeader({required this.onBrandTap, required this.account});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Row(
            children: [
              KidversityBrandMark(onTap: onBrandTap, compact: true),
              const Spacer(),
              account,
            ],
          ),
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty && RegExp(r'[A-Za-z]').hasMatch(part))
      .toList();
  if (parts.isEmpty) return '?';
  final letters = parts.length == 1
      ? parts.first.substring(0, 1)
      : '${parts.first[0]}${parts.last[0]}';
  return letters.toUpperCase();
}

class _AccountButton extends StatelessWidget {
  final String name;
  final RoleStyle style;
  final VoidCallback onSignOut;
  final bool compact;

  const _AccountButton({
    required this.name,
    required this.style,
    required this.onSignOut,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final shown = name.isEmpty ? 'Your account' : name;
    final avatar = Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: style.tint.soft, shape: BoxShape.circle),
      child: Text(
        _initials(name),
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 14,
          color: style.accent,
        ),
      ),
    );

    return PopupMenuButton<String>(
      tooltip: 'Account',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (value) {
        if (value == 'signout') onSignOut();
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shown,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              Text(
                style.label,
                style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'signout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 20),
              SizedBox(width: 12),
              Text('Sign out'),
            ],
          ),
        ),
      ],
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: EdgeInsets.fromLTRB(4, 4, compact ? 4 : 14, 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            avatar,
            if (!compact) ...[
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shown,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.ink,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      style.label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.inkSoft,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.expand_more_rounded,
                size: 20,
                color: AppColors.inkSoft,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final bool narrow;
  final RoleStyle style;
  final int selected;
  final List<NavItem> items;
  final ValueChanged<int> onSelect;

  const _BottomNavBar({
    required this.narrow,
    required this.style,
    required this.selected,
    required this.items,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              narrow ? 4 : 10,
              6,
              narrow ? 4 : 10,
              6,
            ),
            child: Row(
              key: const Key('bottomNavPill'),
              children: [
                for (int i = 0; i < items.length; i++)
                  _NavButton(
                    item: items[i],
                    selected: selected == i,
                    style: style,
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
  final RoleStyle style;
  final bool compact;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.selected,
    required this.style,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? style.accent : AppColors.inkSoft;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: item.label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: AppMotion.of(context, AppMotion.hint),
                  curve: AppMotion.curve(context),
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 12 : 18,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? style.tint.soft : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Icon(
                    selected ? item.activeIcon : item.icon,
                    color: color,
                    size: compact ? 22 : 24,
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: compact ? 11 : 12,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: color,
                    ),
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

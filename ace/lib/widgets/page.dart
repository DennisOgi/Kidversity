import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme.dart';
import 'effects.dart';

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

/// Page frame: a clean top bar with the ACE wordmark and an account menu,
/// and a centred, width-limited body. [header] renders full-bleed above the
/// body (used for hero bands).
class AcePage extends StatelessWidget {
  final List<Widget> children;
  final Widget? header;
  final Future<void> Function()? onRefresh;

  const AcePage({
    super.key,
    required this.children,
    this.header,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final side = width < 600 ? 16.0 : 32.0;
    final list = ListView(
      padding: EdgeInsets.only(bottom: 56),
      children: [
        ?header,
        Padding(
          padding: EdgeInsets.fromLTRB(side, header == null ? 28 : 24, side, 0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(height: 20),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: Ace.navy.withValues(alpha: 0.2),
        titleSpacing: side,
        toolbarHeight: 68,
        title: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.go('/'),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: AceWordmark(),
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: side),
            child: const _AccountMenu(),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Ace.line),
        ),
      ),
      body: onRefresh == null
          ? list
          : RefreshIndicator(onRefresh: onRefresh!, child: list),
    );
  }
}

class _AccountMenu extends StatelessWidget {
  const _AccountMenu();

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const SizedBox.shrink();
    final name =
        (user.userMetadata?['display_name'] as String?) ?? user.email ?? '';
    final compact = MediaQuery.sizeOf(context).width < 600;
    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (v) {
        if (v == 'out') Supabase.instance.client.auth.signOut();
        if (v == 'home') context.go('/');
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Ace.ink,
                ),
              ),
              Text(
                user.email ?? '',
                style: const TextStyle(color: Ace.inkSoft, fontSize: 12.5),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'home', child: Text('My channels')),
        const PopupMenuItem(value: 'out', child: Text('Sign out')),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(5, 5, 12, 5),
        decoration: BoxDecoration(
          border: Border.all(color: Ace.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Ace.navy,
              child: Text(
                _initials(name),
                style: const TextStyle(
                  color: Ace.amber,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Ace.ink,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded, size: 18, color: Ace.inkSoft),
          ],
        ),
      ),
    );
  }
}

/// A full-width navy hero band with the drifting backdrop.
class HeroBand extends StatelessWidget {
  final Widget child;
  final Color? accent;

  const HeroBand({super.key, required this.child, this.accent});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final side = width < 600 ? 16.0 : 32.0;
    return AuroraBackdrop(
      child: Padding(
        padding: EdgeInsets.fromLTRB(side, 34, side, 38),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// White rounded card with an optional coloured edge and hover lift.
class AceCard extends StatelessWidget {
  final Widget child;
  final Color? accent;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const AceCard({
    super.key,
    required this.child,
    this.accent,
    this.onTap,
    this.padding = const EdgeInsets.all(22),
  });

  @override
  Widget build(BuildContext context) {
    final card = Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: accent?.withValues(alpha: 0.28) ?? Ace.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
    return onTap == null ? card : HoverLift(child: card);
  }
}

class AceChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  const AceChip(
    this.label, {
    super.key,
    required this.color,
    required this.background,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading / error states shared by the screens.
class AceAsync<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;
  final String Function(Object error) message;

  const AceAsync({
    super.key,
    required this.future,
    required this.builder,
    required this.onRetry,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snap) {
        if (snap.hasError) {
          return AcePage(
            children: [
              AceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message(snap.error!)),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: onRetry,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        if (!snap.hasData) {
          return const AcePage(
            children: [
              Padding(
                padding: EdgeInsets.all(64),
                child: Center(
                  child: CircularProgressIndicator(color: Ace.amber),
                ),
              ),
            ],
          );
        }
        return builder(snap.data as T);
      },
    );
  }
}

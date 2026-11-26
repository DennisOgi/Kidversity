import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../theme.dart';

/// Page frame: top bar with the ACE wordmark and sign out, a staging banner
/// outside production, and a centred, width-limited body.
class AcePage extends StatelessWidget {
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  const AcePage({super.key, required this.children, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final side = width < 600 ? 16.0 : 32.0;
    final list = ListView(
      padding: EdgeInsets.fromLTRB(side, 24, side, 48),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
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
      ],
    );
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: side,
        title: InkWell(
          onTap: () => context.go('/'),
          child: const AceWordmark(),
        ),
        actions: [
          if (Supabase.instance.client.auth.currentSession != null)
            Padding(
              padding: EdgeInsets.only(right: side),
              child: TextButton.icon(
                onPressed: () => Supabase.instance.client.auth.signOut(),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign out'),
              ),
            ),
        ],
        bottom: AceConfig.environment == 'production'
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Container(
                  height: 28,
                  color: Ace.amberSoft,
                  alignment: Alignment.center,
                  child: const Text(
                    'Staging · draft content for review, not yet released to learners',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Ace.warn,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
      ),
      body: onRefresh == null
          ? list
          : RefreshIndicator(onRefresh: onRefresh!, child: list),
    );
  }
}

/// White rounded card with an optional coloured edge.
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
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accent?.withValues(alpha: 0.35) ?? Ace.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class AceChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;

  const AceChip(
    this.label, {
    super.key,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
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
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          );
        }
        return builder(snap.data as T);
      },
    );
  }
}

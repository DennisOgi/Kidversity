import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/api.dart';
import '../theme.dart';

/// Who the signed-in staff member is, loaded once per session for the shell
/// (role, school, marking badge). Pages call [StaffSession.refresh] after
/// changes that move the counts.
class StaffSession {
  static final info = ValueNotifier<Map<String, dynamic>?>(null);
  static Future<void>? _loading;

  static Future<void> ensure() =>
      info.value != null ? Future.value() : (_loading ??= refresh());

  static Future<void> refresh() async {
    try {
      info.value = await AceApi.instance.staffOverview();
    } finally {
      _loading = null;
    }
  }

  static void clear() => info.value = null;

  static bool get isAdmin => info.value?['role'] == 'admin';
  static int get toMark =>
      ((info.value?['counts'] as Map?)?['to_mark'] as num?)?.toInt() ?? 0;
}

class _NavItem {
  final String path;
  final String label;
  final IconData icon;
  final bool adminOnly;
  const _NavItem(this.path, this.label, this.icon, {this.adminOnly = false});
}

const _items = [
  _NavItem('/staff', 'Overview', Icons.space_dashboard_rounded),
  _NavItem('/staff/marking', 'Marking', Icons.rate_review_rounded),
  _NavItem('/staff/progress', 'Progress', Icons.grid_view_rounded),
  _NavItem('/staff/people', 'People', Icons.groups_rounded, adminOnly: true),
  _NavItem('/staff/content', 'Content', Icons.auto_stories_rounded),
];

/// Workspace frame for teachers and school admins: a navy sidebar on wide
/// screens, a bottom bar on phones, and a page header with actions.
class StaffShell extends StatefulWidget {
  final String current;
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;
  final bool scroll;

  const StaffShell({
    super.key,
    required this.current,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.scroll = true,
  });

  @override
  State<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends State<StaffShell> {
  @override
  void initState() {
    super.initState();
    StaffSession.ensure();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 980;
    return ValueListenableBuilder(
      valueListenable: StaffSession.info,
      builder: (context, info, _) {
        final items = [
          for (final i in _items)
            if (!i.adminOnly || StaffSession.isAdmin) i,
        ];
        final header = Padding(
          padding: EdgeInsets.fromLTRB(
            wide ? 36 : 16,
            wide ? 32 : 18,
            wide ? 36 : 16,
            18,
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 16,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: wide ? 30 : 24,
                      fontWeight: FontWeight.w700,
                      color: Ace.ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (widget.subtitle != null)
                    Text(
                      widget.subtitle!,
                      style: const TextStyle(color: Ace.inkSoft),
                    ),
                ],
              ),
              if (widget.actions.isNotEmpty)
                Wrap(spacing: 10, runSpacing: 10, children: widget.actions),
            ],
          ),
        );
        final body = widget.scroll
            ? ListView(
                padding: const EdgeInsets.only(bottom: 40),
                children: [
                  header,
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: wide ? 36 : 16),
                    child: widget.child,
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        wide ? 36 : 16,
                        0,
                        wide ? 36 : 16,
                        wide ? 28 : 12,
                      ),
                      child: widget.child,
                    ),
                  ),
                ],
              );

        if (wide) {
          return Scaffold(
            backgroundColor: const Color(0xFFF3F5FA),
            body: Row(
              children: [
                _Sidebar(items: items, current: widget.current, info: info),
                Expanded(child: body),
              ],
            ),
          );
        }
        final index = items.indexWhere((i) => i.path == widget.current);
        return Scaffold(
          backgroundColor: const Color(0xFFF3F5FA),
          appBar: AppBar(
            backgroundColor: Ace.navy,
            foregroundColor: Colors.white,
            title: const AceWordmark(onDark: true),
            actions: [
              IconButton(
                tooltip: 'Sign out',
                onPressed: _signOut,
                icon: const Icon(Icons.logout_rounded),
              ),
            ],
          ),
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: index < 0 ? 0 : index,
            backgroundColor: Colors.white,
            indicatorColor: Ace.amberSoft,
            onDestinationSelected: (i) => context.go(items[i].path),
            destinations: [
              for (final i in items)
                NavigationDestination(
                  icon: _badge(i, Icon(i.icon)),
                  label: i.label,
                ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> _signOut() async {
  StaffSession.clear();
  await Supabase.instance.client.auth.signOut();
}

Widget _badge(_NavItem item, Widget icon) {
  final n = StaffSession.toMark;
  if (item.path != '/staff/marking' || n == 0) return icon;
  return Badge(label: Text('$n'), backgroundColor: Ace.bad, child: icon);
}

class _Sidebar extends StatelessWidget {
  final List<_NavItem> items;
  final String current;
  final Map<String, dynamic>? info;

  const _Sidebar({
    required this.items,
    required this.current,
    required this.info,
  });

  @override
  Widget build(BuildContext context) {
    final school = (info?['school'] as Map?)?['name'] as String?;
    final name = info?['display_name'] as String? ?? '';
    final role = info?['role'] == 'admin' ? 'School admin' : 'Teacher';
    return Container(
      width: 252,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Ace.navy, Color(0xFF0E2650)],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 24, 22, 6),
              child: AceWordmark(onDark: true),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
              child: Text(
                school ?? '',
                style: const TextStyle(color: Color(0xFF9FB0CF), fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            for (final i in items)
              _SideTile(item: i, selected: i.path == current),
            const Spacer(),
            Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Ace.amber,
                    child: Text(
                      initials(name),
                      style: const TextStyle(
                        color: Ace.navy,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          role,
                          style: const TextStyle(
                            color: Color(0xFF9FB0CF),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sign out',
                    onPressed: _signOut,
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFF9FB0CF),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideTile extends StatelessWidget {
  final _NavItem item;
  final bool selected;

  const _SideTile({required this.item, required this.selected});

  @override
  Widget build(BuildContext context) {
    final n = item.path == '/staff/marking' ? StaffSession.toMark : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.go(item.path),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 21,
                  color: selected ? Ace.amber : const Color(0xFF9FB0CF),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFFC9D3E6),
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (n > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Ace.amber,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '$n',
                      style: const TextStyle(
                        color: Ace.navy,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
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

String initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

String timeAgo(Object? iso) {
  final t = DateTime.tryParse('${iso ?? ''}');
  if (t == null) return 'never';
  final d = DateTime.now().difference(t.toLocal());
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays < 7) return '${d.inDays} d ago';
  return '${t.day}/${t.month}/${t.year}';
}

/// White panel with an optional title row.
class Panel extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? action;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const Panel({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.action,
    this.padding = const EdgeInsets.all(22),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E8F1)),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title!,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Ace.ink,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            color: Ace.inkSoft,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }
}

/// Headline number tile.
class Kpi extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? caption;
  final VoidCallback? onTap;
  final bool highlight;

  const Kpi({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.caption,
    this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlight ? Ace.navy : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: highlight ? Ace.navy : const Color(0xFFE4E8F1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: highlight
                          ? Colors.white.withValues(alpha: 0.12)
                          : color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      icon,
                      color: highlight ? Ace.amber : color,
                      size: 21,
                    ),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: highlight ? Colors.white70 : Ace.inkSoft,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                value,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: highlight ? Colors.white : Ace.ink,
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: highlight ? Colors.white : Ace.ink,
                ),
              ),
              if (caption != null)
                Text(
                  caption!,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: highlight ? const Color(0xFFC9D3E6) : Ace.inkSoft,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lay [children] out in a responsive grid of equal-width tiles.
class TileGrid extends StatelessWidget {
  final List<Widget> children;
  final double minWidth;
  final double gap;

  const TileGrid({
    super.key,
    required this.children,
    this.minWidth = 220,
    this.gap = 16,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final cols = (box.maxWidth / minWidth).floor().clamp(
          1,
          children.length.clamp(1, 6),
        );
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final c in children) SizedBox(width: w, child: c)],
        );
      },
    );
  }
}

/// Status of an attempt in teacher-friendly words.
(String, Color, Color) statusLook(String? status, String? state) {
  if (state == 'teacher_marked') return ('Marked', Ace.good, Ace.goodSoft);
  if (state == 'needs_review') return ('To mark', Ace.warn, Ace.warnSoft);
  return switch (status) {
    'final_answer_match' ||
    'option_match' => ('Correct', Ace.good, Ace.goodSoft),
    'unit_mismatch' => ('Unit wrong', Ace.warn, Ace.warnSoft),
    'try_again' || 'option_wrong' => ('Incorrect', Ace.bad, Ace.badSoft),
    'invalid_numeric_input' => ('Unreadable', Ace.warn, Ace.warnSoft),
    _ => ('Submitted', Ace.inkSoft, const Color(0xFFEDEFF5)),
  };
}

class StatusPill extends StatelessWidget {
  final String? status;
  final String? state;

  const StatusPill({super.key, this.status, this.state});

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = statusLook(status, state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  final String name;
  final double radius;

  const Avatar(this.name, {super.key, this.radius = 18});

  static const _palette = [
    Ace.maths,
    Ace.physics,
    Color(0xFF8B5CF6),
    Color(0xFFE0457B),
    Color(0xFFF97316),
  ];

  @override
  Widget build(BuildContext context) {
    final c = _palette[name.hashCode.abs() % _palette.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: c.withValues(alpha: 0.14),
      child: Text(
        initials(name),
        style: TextStyle(
          color: c,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.72,
        ),
      ),
    );
  }
}

/// Loading, error and data states for staff pages.
class StaffAsync<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;

  const StaffAsync({
    super.key,
    required this.future,
    required this.builder,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snap) {
        if (snap.hasError) {
          return Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AceApi.message(snap.error!)),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: onRetry,
                  child: const Text('Try again'),
                ),
              ],
            ),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(60),
            child: Center(child: CircularProgressIndicator(color: Ace.amber)),
          );
        }
        return builder(snap.data as T);
      },
    );
  }
}

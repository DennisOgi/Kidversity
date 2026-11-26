import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../data/api.dart';
import '../theme.dart';
import 'staff_ui.dart';

const _roleLabels = {
  'student': 'Student',
  'teacher': 'Teacher',
  'admin': 'School admin',
};

/// School admin: join code, and everyone in the school with their role.
class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  late Future<List<Map<String, dynamic>>> _people = AceApi.instance
      .schoolPeople();
  String _filter = 'all';
  String _query = '';

  void _reload() => setState(() => _people = AceApi.instance.schoolPeople());

  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      _reload();
      StaffSession.refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AceApi.message(e))));
      }
    }
  }

  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    // Wait for the staff details before deciding whether this is an admin.
    return ValueListenableBuilder(
      valueListenable: StaffSession.info,
      builder: (context, info, _) => _build(context, info),
    );
  }

  Widget _build(BuildContext context, Map<String, dynamic>? info) {
    final admin = StaffSession.isAdmin;
    final code = (info?['school'] as Map?)?['join_code'] as String?;
    return StaffShell(
      current: '/staff/people',
      title: 'People',
      subtitle: 'Students and staff in your school.',
      child: info == null
          ? const Padding(
              padding: EdgeInsets.all(60),
              child: Center(child: CircularProgressIndicator(color: Ace.amber)),
            )
          : !admin
          ? const Panel(
              child: Text(
                'Only a school admin can manage people.',
                style: TextStyle(color: Ace.inkSoft),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (code != null)
                  _CodeCard(
                    code: code,
                    onNewCode: () async {
                      if (!await _confirm(
                        'Make a new join code?',
                        'The current code stops working straight away. Students who already joined are not affected.',
                        'Make new code',
                      )) {
                        return;
                      }
                      await _run(
                        () => AceApi.instance.newJoinCode(),
                        'New join code ready',
                      );
                    },
                  ),
                const SizedBox(height: 16),
                StaffAsync<List<Map<String, dynamic>>>(
                  future: _people,
                  onRetry: _reload,
                  builder: (people) {
                    final counts = {
                      for (final r in ['student', 'teacher', 'admin'])
                        r: people.where((p) => p['role'] == r).length,
                    };
                    final shown = people.where((p) {
                      final okRole = _filter == 'all' || p['role'] == _filter;
                      final okName =
                          _query.isEmpty ||
                          '${p['name']}'.toLowerCase().contains(
                            _query.toLowerCase(),
                          );
                      return okRole && okName;
                    }).toList();
                    return Panel(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final f in [
                                    ('all', 'All ${people.length}'),
                                    (
                                      'student',
                                      'Students ${counts['student']}',
                                    ),
                                    (
                                      'teacher',
                                      'Teachers ${counts['teacher']}',
                                    ),
                                    ('admin', 'Admins ${counts['admin']}'),
                                  ])
                                    ChoiceChip(
                                      label: Text(f.$2),
                                      selected: _filter == f.$1,
                                      showCheckmark: false,
                                      selectedColor: Ace.navy,
                                      labelStyle: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: _filter == f.$1
                                            ? Colors.white
                                            : Ace.ink,
                                      ),
                                      onSelected: (_) =>
                                          setState(() => _filter = f.$1),
                                    ),
                                ],
                              ),
                              SizedBox(
                                width: 260,
                                child: TextField(
                                  onChanged: (v) => setState(() => _query = v),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    prefixIcon: Icon(Icons.search_rounded),
                                    hintText: 'Search by name',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          for (final p in shown)
                            _PersonRow(
                              person: p,
                              onRole: (role) async {
                                if (role == p['role']) return;
                                if (!await _confirm(
                                  'Change role?',
                                  '${p['name']} will become ${_roleLabels[role]!.toLowerCase()}.',
                                  'Change role',
                                )) {
                                  return;
                                }
                                await _run(
                                  () => AceApi.instance.setMemberRole(
                                    p['user_id'] as String,
                                    role,
                                  ),
                                  '${p['name']} is now ${_roleLabels[role]!.toLowerCase()}',
                                );
                              },
                              onRemove: () async {
                                if (!await _confirm(
                                  'Remove ${p['name']}?',
                                  'They lose access to your school\'s subjects. Their past answers are kept. They can rejoin with the join code.',
                                  'Remove',
                                )) {
                                  return;
                                }
                                await _run(
                                  () => AceApi.instance.removeMember(
                                    p['user_id'] as String,
                                  ),
                                  '${p['name']} removed from the school',
                                );
                              },
                            ),
                          if (shown.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                'Nobody matches.',
                                style: TextStyle(color: Ace.inkSoft),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  final Map<String, dynamic> person;
  final ValueChanged<String> onRole;
  final VoidCallback onRemove;

  const _PersonRow({
    required this.person,
    required this.onRole,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final me = person['is_me'] == true;
    final role = person['role'] as String;
    final narrow = MediaQuery.sizeOf(context).width < 700;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFEDEFF5))),
      ),
      child: Row(
        children: [
          Avatar(person['name'] as String? ?? '?'),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: role == 'student'
                  ? () => context.go('/staff/students/${person['user_id']}')
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${person['name']}${me ? ' (you)' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    role == 'student'
                        ? '${person['attempts']} answers · last active ${timeAgo(person['last_active'])}'
                        : 'Joined ${timeAgo(person['joined'])}',
                    style: const TextStyle(color: Ace.inkSoft, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ),
          if (me)
            _RoleBadge(role: role)
          else ...[
            PopupMenuButton<String>(
              tooltip: 'Change role',
              onSelected: onRole,
              itemBuilder: (_) => [
                for (final r in _roleLabels.entries)
                  CheckedPopupMenuItem(
                    value: r.key,
                    checked: r.key == role,
                    child: Text(r.value),
                  ),
              ],
              child: _RoleBadge(role: role, editable: true),
            ),
            SizedBox(width: narrow ? 0 : 6),
            IconButton(
              tooltip: 'Remove from school',
              onPressed: onRemove,
              icon: const Icon(
                Icons.person_remove_rounded,
                color: Ace.inkSoft,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  final bool editable;

  const _RoleBadge({required this.role, this.editable = false});

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (role) {
      'admin' => (Ace.navy, Ace.amberSoft),
      'teacher' => (Ace.physics, Ace.physicsSoft),
      _ => (Ace.maths, Ace.mathsSoft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _roleLabels[role] ?? role,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          if (editable) ...[
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded, size: 16, color: fg),
          ],
        ],
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  final String code;
  final VoidCallback onNewCode;

  const _CodeCard({required this.code, required this.onNewCode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(colors: [Ace.navy, Ace.navySoft]),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 14,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Join code',
                style: TextStyle(
                  color: Color(0xFFC9D3E6),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                code,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 5,
                ),
              ),
              const Text(
                'Students enter this after creating an account. New joiners start as students.',
                style: TextStyle(color: Color(0xFFC9D3E6), fontSize: 13),
              ),
            ],
          ),
          Wrap(
            spacing: 10,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Ace.amber,
                  foregroundColor: Ace.navy,
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Join code copied')),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                ),
                onPressed: onNewCode,
                icon: const Icon(Icons.autorenew_rounded, size: 18),
                label: const Text('New code'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The school's subjects, opened as students see them.
class ContentScreen extends StatelessWidget {
  const ContentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StaffShell(
      current: '/staff/content',
      title: 'Content',
      subtitle: 'Your school\'s subjects, exactly as students see them.',
      child: ValueListenableBuilder(
        valueListenable: StaffSession.info,
        builder: (context, info, _) {
          final channels = [
            for (final c in (info?['channels'] as List? ?? const []))
              Map<String, dynamic>.from(c as Map),
          ];
          if (info == null) {
            return const Padding(
              padding: EdgeInsets.all(60),
              child: Center(child: CircularProgressIndicator(color: Ace.amber)),
            );
          }
          return TileGrid(
            minWidth: 260,
            children: [
              for (final c in channels)
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => context.push('/c/${c['id']}'),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE4E8F1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Ace.subjectSoft(c['subject'] as String),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              c['subject'] == 'Physics'
                                  ? Icons.bolt_rounded
                                  : Icons.functions_rounded,
                              color: Ace.subject(c['subject'] as String),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            '${c['stage']} ${c['subject']}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${c['questions']} practice questions',
                            style: const TextStyle(color: Ace.inkSoft),
                          ),
                          const SizedBox(height: 12),
                          const Row(
                            children: [
                              Text(
                                'Open lessons',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Ace.navy,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: Ace.navy,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

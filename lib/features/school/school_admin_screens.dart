import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/app_state.dart';
import '../../models/school_models.dart';
import '../../router/navigation.dart';
import '../../services/school_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/role_style.dart';
import '../../widgets/error_boundary.dart';
import '../../widgets/kv_ui.dart';

const _publicOrigin = 'https://kidversity.vercel.app';

String _origin() => kIsWeb ? Uri.base.origin : _publicOrigin;

/// The link a teacher opens to sign up straight into the school.
String staffInviteLink(String code) =>
    '${_origin()}${AppRoutes.joinStaff(code)}';

void _refreshSchool(WidgetRef ref) {
  ref.invalidate(schoolAdminProvider);
  ref.invalidate(schoolDirectoryProvider);
  ref.invalidate(schoolOverviewProvider);
}

Future<void> _copy(BuildContext context, String text, String what) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) context.showSuccessSnackbar('$what copied.');
}

/// Shows [child] only to school admins; everyone else gets a way back.
class _AdminGate extends ConsumerWidget {
  final Widget Function(SchoolOverview overview) builder;

  const _AdminGate({required this.builder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(schoolOverviewProvider);
    return overview.when(
      loading: () => const KvPage(
        children: [LoadingIndicator(message: 'Opening the school…')],
      ),
      error: (error, _) => KvPage(
        children: [
          ErrorDisplay(
            message: 'The school could not be loaded.',
            error: error,
            onRetry: () => ref.invalidate(schoolOverviewProvider),
          ),
        ],
      ),
      data: (value) {
        if (!value.isAdmin) {
          return KvPage(
            children: [
              KvCard(
                tint: AppTint.sun,
                child: KvListRow(
                  divider: false,
                  leading: const TintIcon(
                    tint: AppTint.sun,
                    icon: Icons.lock_outline_rounded,
                  ),
                  title: 'Only school admins can open this page',
                  detail: value.hasSchool
                      ? 'Ask your school admin if you need to manage staff or students.'
                      : 'Set up a school from your class page, or join one with a staff code.',
                  trailing: [
                    FilledButton(
                      onPressed: () => context.go(AppRoutes.teacherDashboard),
                      child: const Text('Go to my classes'),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        return builder(value);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Teachers
// ---------------------------------------------------------------------------

class SchoolTeachersScreen extends ConsumerWidget {
  const SchoolTeachersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _AdminGate(
      builder: (overview) {
        final info = ref.watch(schoolAdminProvider);
        return KvPage(
          onRefresh: () async {
            _refreshSchool(ref);
            await ref.read(schoolAdminProvider.future);
          },
          children: [
            HeroBanner(
              colors: HeroColors.school,
              eyebrow: overview.schoolName ?? 'Your school',
              title: 'Bring your teachers in',
              body:
                  'Teachers join with the staff code or an email invite. Then give each one a class on Overview.',
            ),
            ...info.when(
              loading: () => const [
                LoadingIndicator(message: 'Loading staff…'),
              ],
              error: (error, _) => [
                ErrorDisplay(
                  message: 'Staff could not be loaded.',
                  error: error,
                  onRetry: () => ref.invalidate(schoolAdminProvider),
                ),
              ],
              data: (value) => [
                AdaptiveRow(
                  breakpoint: 900,
                  children: [
                    _StaffCodeCard(code: value.staffCode),
                    const _InviteByEmailCard(),
                  ],
                ),
                if (value.invites.isNotEmpty) _PendingInvites(info: value),
                _StaffList(info: value),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _StaffCodeCard extends ConsumerWidget {
  final String code;

  const _StaffCodeCard({required this.code});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = staffInviteLink(code);
    final message =
        'Join our school on Kidversity. Open $link and sign up as a teacher, '
        'or enter the staff code $code when you sign up.';
    return KvCard(
      tint: AppTint.violet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const KvSectionTitle(
            title: 'Share the staff code',
            subtitle: 'Anyone with it can join as a teacher. Keep it to staff.',
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: SelectableText(
              code.isEmpty ? '—' : code,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: code.isEmpty
                    ? null
                    : () => _copy(context, link, 'Invite link'),
                icon: const Icon(Icons.link_rounded),
                label: const Text('Copy invite link'),
              ),
              OutlinedButton.icon(
                onPressed: code.isEmpty
                    ? null
                    : () => _copy(context, message, 'Invite message'),
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Copy message'),
              ),
              OutlinedButton.icon(
                onPressed: code.isEmpty
                    ? null
                    : () => _copy(context, code, 'Staff code'),
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy code'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Paste the message into WhatsApp or email. Change the code in Settings if it gets out.',
            style: TextStyle(fontSize: 13, color: AppTint.violet.ink),
          ),
        ],
      ),
    );
  }
}

class _InviteByEmailCard extends ConsumerStatefulWidget {
  const _InviteByEmailCard();

  @override
  ConsumerState<_InviteByEmailCard> createState() => _InviteByEmailCardState();
}

class _InviteByEmailCardState extends ConsumerState<_InviteByEmailCard> {
  final _email = TextEditingController();
  String _role = 'teacher';
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (email.isEmpty || _busy) return;
    setState(() => _busy = true);
    final result = await SchoolService.instance.inviteStaff(
      email: email,
      role: _role,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.isFailure) {
      context.showErrorSnackbar(
        result.error ?? 'The invite could not be sent.',
      );
      return;
    }
    _email.clear();
    _refreshSchool(ref);
    context.showSuccessSnackbar(
      result.data == true
          ? '$email already had an account and is now on your staff.'
          : 'Invite saved. $email joins your school when they sign up with this email. Send them the invite link too.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return KvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const KvSectionTitle(
            title: 'Invite by email',
            subtitle:
                'Existing accounts join now. New ones join the moment they sign up.',
          ),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            onSubmitted: (_) => _send(),
            decoration: const InputDecoration(
              labelText: 'Teacher’s email',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'teacher',
                label: Text('Teacher'),
                icon: Icon(Icons.co_present_rounded),
              ),
              ButtonSegment(
                value: 'admin',
                label: Text('Co-admin'),
                icon: Icon(Icons.admin_panel_settings_outlined),
              ),
            ],
            selected: {_role},
            onSelectionChanged: (value) => setState(() => _role = value.first),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _busy ? null : _send,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
            label: const Text('Send invite'),
          ),
        ],
      ),
    );
  }
}

class _PendingInvites extends ConsumerWidget {
  final SchoolAdminInfo info;

  const _PendingInvites({required this.info});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return KvCard(
      tint: AppTint.sun,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KvSectionTitle(
            title: 'Waiting to sign up',
            subtitle:
                '${info.invites.length} invite${info.invites.length == 1 ? '' : 's'}. They join automatically when they create an account with this email.',
          ),
          for (var i = 0; i < info.invites.length; i++)
            KvListRow(
              divider: i > 0,
              leading: const TintIcon(
                tint: AppTint.sun,
                icon: Icons.hourglass_top_rounded,
              ),
              title: info.invites[i].email,
              detail: info.invites[i].role == 'admin' ? 'Co-admin' : 'Teacher',
              trailing: [
                TextButton(
                  onPressed: () async {
                    final result = await SchoolService.instance.revokeInvite(
                      info.invites[i].id,
                    );
                    if (!context.mounted) return;
                    if (result.isFailure) {
                      context.showErrorSnackbar(result.error!);
                      return;
                    }
                    _refreshSchool(ref);
                    context.showSuccessSnackbar('Invite cancelled.');
                  },
                  child: const Text('Cancel invite'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StaffList extends ConsumerWidget {
  final SchoolAdminInfo info;

  const _StaffList({required this.info});

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    SchoolStaffMember person,
  ) async {
    final classes = person.classes.map((c) => c.name).join(', ');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove ${person.displayName} from the school?'),
        content: Text(
          classes.isEmpty
              ? 'They keep their Kidversity account but leave your school.'
              : 'They keep their Kidversity account but leave your school. $classes will need a new teacher.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final result = await SchoolService.instance.removeMember(person.userId);
    if (!context.mounted) return;
    if (result.isFailure) {
      context.showErrorSnackbar(result.error!);
      return;
    }
    _refreshSchool(ref);
    context.showSuccessSnackbar('${person.displayName} left the school.');
  }

  Future<void> _setRole(
    BuildContext context,
    WidgetRef ref,
    SchoolStaffMember person,
    String role,
  ) async {
    final result = await SchoolService.instance.setStaffRole(
      person.userId,
      role,
    );
    if (!context.mounted) return;
    if (result.isFailure) {
      context.showErrorSnackbar(result.error!);
      return;
    }
    _refreshSchool(ref);
    context.showSuccessSnackbar(
      role == 'admin'
          ? '${person.displayName} is now a co-admin.'
          : '${person.displayName} is now a teacher.',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = SupabaseService.instance.currentUser?.id;
    final staff = info.staff;
    return KvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KvSectionTitle(
            title: 'Staff',
            subtitle:
                '${staff.length} ${staff.length == 1 ? 'person' : 'people'} · ${info.adminCount} admin${info.adminCount == 1 ? '' : 's'}',
          ),
          if (staff.isEmpty)
            const KvListRow(
              divider: false,
              leading: TintIcon(
                tint: AppTint.sky,
                icon: Icons.person_add_alt_1_rounded,
                solid: false,
              ),
              title: 'No teachers yet',
              detail: 'Share the staff code above to bring them in.',
            ),
          for (var i = 0; i < staff.length; i++)
            KvListRow(
              divider: i > 0,
              leading: _Initials(
                name: staff[i].displayName,
                tint: AppTint.cycle[i % AppTint.cycle.length],
              ),
              title: staff[i].userId == me
                  ? '${staff[i].displayName} (you)'
                  : staff[i].displayName,
              detail: [
                staff[i].email,
                staff[i].classes.isEmpty
                    ? 'No class yet'
                    : staff[i].classes.map((c) => c.name).join(', '),
              ].join(' · '),
              trailing: [
                StatusChip(
                  label: staff[i].isAdmin ? 'Admin' : 'Teacher',
                  tint: staff[i].isAdmin ? AppTint.violet : AppTint.sky,
                ),
                if (staff[i].userId != me)
                  PopupMenuButton<String>(
                    tooltip: 'Options for ${staff[i].displayName}',
                    onSelected: (value) => switch (value) {
                      'admin' => _setRole(context, ref, staff[i], 'admin'),
                      'teacher' => _setRole(context, ref, staff[i], 'teacher'),
                      _ => _remove(context, ref, staff[i]),
                    },
                    itemBuilder: (_) => [
                      if (staff[i].isAdmin)
                        const PopupMenuItem(
                          value: 'teacher',
                          child: Text('Make teacher (not admin)'),
                        )
                      else
                        const PopupMenuItem(
                          value: 'admin',
                          child: Text('Make co-admin'),
                        ),
                      const PopupMenuItem(
                        value: 'remove',
                        child: Text('Remove from school'),
                      ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  final String name;
  final AppTint tint;

  const _Initials({required this.name, required this.tint});

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.isEmpty
        ? '?'
        : parts.length == 1
        ? parts.first.substring(0, 1)
        : '${parts.first[0]}${parts.last[0]}';
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tint.soft, shape: BoxShape.circle),
      child: Text(
        letters.toUpperCase(),
        style: TextStyle(fontWeight: FontWeight.w800, color: tint.ink),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Students
// ---------------------------------------------------------------------------

class SchoolStudentsScreen extends ConsumerStatefulWidget {
  const SchoolStudentsScreen({super.key});

  @override
  ConsumerState<SchoolStudentsScreen> createState() =>
      _SchoolStudentsScreenState();
}

class _SchoolStudentsScreenState extends ConsumerState<SchoolStudentsScreen> {
  static const _pageSize = 50;
  final _search = TextEditingController();
  bool _onlyUnplaced = true;
  int _shown = _pageSize;
  final Set<String> _busy = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _place(SchoolPerson student, SchoolClassInfo target) async {
    setState(() => _busy.add(student.userId));
    final result = await SchoolService.instance.placeStudent(
      classId: target.id,
      userId: student.userId,
    );
    if (!mounted) return;
    setState(() => _busy.remove(student.userId));
    if (result.isFailure) {
      context.showErrorSnackbar(result.error!);
      return;
    }
    _refreshSchool(ref);
    context.showSuccessSnackbar(
      '${student.displayName} is now in ${result.data}.',
    );
  }

  Future<void> _remove(SchoolPerson student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove ${student.displayName} from the school?'),
        content: const Text(
          'They keep their account and progress, but leave your school and its classes. They can join again with a class code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await SchoolService.instance.removeMember(student.userId);
    if (!mounted) return;
    if (result.isFailure) {
      context.showErrorSnackbar(result.error!);
      return;
    }
    _refreshSchool(ref);
    context.showSuccessSnackbar('${student.displayName} left the school.');
  }

  @override
  Widget build(BuildContext context) {
    return _AdminGate(
      builder: (overview) {
        final directory = ref.watch(schoolDirectoryProvider);
        final classes = overview.classes;
        final classNames = {for (final c in classes) c.id: c.name};
        return KvPage(
          onRefresh: () async {
            _refreshSchool(ref);
            await ref.read(schoolDirectoryProvider.future);
          },
          children: [
            HeroBanner(
              colors: HeroColors.school,
              eyebrow: overview.schoolName ?? 'Your school',
              title: 'Every student in a class',
              body:
                  'Students join with their class code. Anyone who joined the school without a class shows up here so you can place them.',
            ),
            ...directory.when(
              loading: () => const [
                LoadingIndicator(message: 'Loading students…'),
              ],
              error: (error, _) => [
                ErrorDisplay(
                  message: 'Students could not be loaded.',
                  error: error,
                  onRetry: () => ref.invalidate(schoolDirectoryProvider),
                ),
              ],
              data: (value) {
                final all = value.students;
                final unplaced = all.where((s) => s.classIds.isEmpty).length;
                final query = _search.text.trim().toLowerCase();
                final filtered = [
                  for (final s in all)
                    if ((!_onlyUnplaced || s.classIds.isEmpty) &&
                        (query.isEmpty ||
                            s.displayName.toLowerCase().contains(query) ||
                            s.email.toLowerCase().contains(query)))
                      s,
                ];
                final page = filtered.take(_shown).toList();
                return [
                  AdaptiveGrid(
                    minTileWidth: 150,
                    maxColumns: 3,
                    children: [
                      MetricTile(
                        tint: AppTint.violet,
                        icon: Icons.school_rounded,
                        label: 'Students',
                        value: '${all.length}',
                        caption: 'In the school',
                      ),
                      MetricTile(
                        tint: unplaced > 0 ? StatusChip.alert : AppTint.mint,
                        icon: Icons.person_search_rounded,
                        label: 'Not in a class',
                        value: '$unplaced',
                        caption: unplaced > 0
                            ? 'Place them below'
                            : 'Everyone is placed',
                      ),
                      MetricTile(
                        tint: AppTint.mint,
                        icon: Icons.groups_rounded,
                        label: 'Classes',
                        value: '${classes.length}',
                        caption: 'To place students in',
                      ),
                    ],
                  ),
                  KvCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: 320,
                              child: TextField(
                                controller: _search,
                                onChanged: (_) =>
                                    setState(() => _shown = _pageSize),
                                decoration: const InputDecoration(
                                  hintText: 'Search by name or email',
                                  prefixIcon: Icon(Icons.search_rounded),
                                ),
                              ),
                            ),
                            SegmentedButton<bool>(
                              segments: [
                                ButtonSegment(
                                  value: true,
                                  label: Text('Not in a class ($unplaced)'),
                                ),
                                ButtonSegment(
                                  value: false,
                                  label: Text('All (${all.length})'),
                                ),
                              ],
                              selected: {_onlyUnplaced},
                              onSelectionChanged: (value) => setState(() {
                                _onlyUnplaced = value.first;
                                _shown = _pageSize;
                              }),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (classes.isEmpty)
                          const KvListRow(
                            divider: false,
                            leading: TintIcon(
                              tint: AppTint.sun,
                              icon: Icons.info_outline_rounded,
                              solid: false,
                            ),
                            title: 'Create a class first',
                            detail:
                                'Go to Overview and tap New class. Then come back to place students.',
                          ),
                        if (page.isEmpty)
                          KvListRow(
                            divider: false,
                            leading: const TintIcon(
                              tint: AppTint.mint,
                              icon: Icons.check_rounded,
                            ),
                            title: _onlyUnplaced && query.isEmpty
                                ? 'Every student is in a class'
                                : 'No students match',
                            detail: _onlyUnplaced && query.isEmpty
                                ? 'New students who join without a class show up here.'
                                : 'Try a different name or email.',
                          ),
                        for (var i = 0; i < page.length; i++)
                          KvListRow(
                            divider: i > 0,
                            leading: _Initials(
                              name: page[i].displayName,
                              tint:
                                  AppTint.cycle[(i + 2) % AppTint.cycle.length],
                            ),
                            title: page[i].displayName,
                            detail: page[i].email,
                            trailing: [
                              page[i].classIds.isEmpty
                                  ? const StatusChip(
                                      label: 'No class',
                                      tint: StatusChip.alert,
                                    )
                                  : StatusChip(
                                      label:
                                          classNames[page[i].classIds.first] ??
                                          'In a class',
                                      tint: AppTint.mint,
                                    ),
                              if (_busy.contains(page[i].userId))
                                const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              else
                                PopupMenuButton<Object>(
                                  tooltip: 'Place ${page[i].displayName}',
                                  onSelected: (value) =>
                                      value is SchoolClassInfo
                                      ? _place(page[i], value)
                                      : _remove(page[i]),
                                  itemBuilder: (_) => [
                                    for (final c in classes)
                                      PopupMenuItem<Object>(
                                        value: c,
                                        enabled: !page[i].classIds.contains(
                                          c.id,
                                        ),
                                        child: Text(
                                          page[i].classIds.isEmpty
                                              ? 'Place in ${c.name}'
                                              : 'Move to ${c.name}',
                                        ),
                                      ),
                                    if (classes.isNotEmpty)
                                      const PopupMenuDivider(),
                                    const PopupMenuItem<Object>(
                                      value: 'remove',
                                      child: Text('Remove from school'),
                                    ),
                                  ],
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    child: Text(
                                      page[i].classIds.isEmpty
                                          ? 'Place'
                                          : 'Move',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        if (filtered.length > page.length)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Center(
                              child: OutlinedButton(
                                onPressed: () =>
                                    setState(() => _shown += _pageSize),
                                child: Text(
                                  'Show more (${filtered.length - page.length} left)',
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ];
              },
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

class SchoolSettingsScreen extends ConsumerStatefulWidget {
  const SchoolSettingsScreen({super.key});

  @override
  ConsumerState<SchoolSettingsScreen> createState() =>
      _SchoolSettingsScreenState();
}

class _SchoolSettingsScreenState extends ConsumerState<SchoolSettingsScreen> {
  final _name = TextEditingController();
  bool _nameLoaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _rename() async {
    final name = _name.text.trim();
    if (name.length < 2 || _saving) return;
    setState(() => _saving = true);
    final result = await SchoolService.instance.renameSchool(name);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isFailure) {
      context.showErrorSnackbar(result.error!);
      return;
    }
    _refreshSchool(ref);
    context.showSuccessSnackbar('The school is now called ${result.data}.');
  }

  Future<void> _newCode() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Make a new staff code?'),
        content: const Text(
          'The old code and invite link stop working. Teachers already on staff are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Make new code'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await SchoolService.instance.regenerateStaffCode();
    if (!mounted) return;
    if (result.isFailure) {
      context.showErrorSnackbar(result.error!);
      return;
    }
    _refreshSchool(ref);
    context.showSuccessSnackbar('New staff code: ${result.data}');
  }

  @override
  Widget build(BuildContext context) {
    return _AdminGate(
      builder: (overview) {
        final info = ref.watch(schoolAdminProvider).asData?.value;
        if (!_nameLoaded && (overview.schoolName ?? '').isNotEmpty) {
          _name.text = overview.schoolName!;
          _nameLoaded = true;
        }
        return KvPage(
          maxWidth: 820,
          children: [
            KvCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const KvSectionTitle(
                    title: 'School name',
                    subtitle: 'Teachers, students, and parents see this name.',
                  ),
                  TextField(
                    controller: _name,
                    maxLength: 80,
                    textCapitalization: TextCapitalization.words,
                    onSubmitted: (_) => _rename(),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.apartment_rounded),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _saving ? null : _rename,
                      child: const Text('Save name'),
                    ),
                  ),
                ],
              ),
            ),
            KvCard(
              tint: AppTint.violet,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const KvSectionTitle(
                    title: 'Staff code',
                    subtitle:
                        'Teachers use it to join your school. Make a new one if the old one was shared too widely.',
                  ),
                  KvListRow(
                    divider: false,
                    leading: const TintIcon(
                      tint: AppTint.violet,
                      icon: Icons.key_rounded,
                    ),
                    title: info?.staffCode ?? 'Loading…',
                    detail: info == null
                        ? null
                        : staffInviteLink(info.staffCode),
                    trailing: [
                      OutlinedButton(
                        onPressed: info == null ? null : _newCode,
                        child: const Text('Make new code'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            KvCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const KvSectionTitle(
                    title: 'Class join codes',
                    subtitle:
                        'Each class has its own code for students. Open a class on Overview to see or change it.',
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => context.go(AppRoutes.schoolHome),
                      icon: const Icon(Icons.groups_rounded),
                      label: const Text('Open classes'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

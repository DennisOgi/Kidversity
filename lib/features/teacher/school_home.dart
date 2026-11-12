import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../models/school_models.dart';
import '../../router/navigation.dart';
import '../../services/school_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/dashboard_guide.dart';
import '../../widgets/empty_panel.dart';
import '../../widgets/error_boundary.dart';
import '../../widgets/surfaces.dart';
import '../../widgets/kv_ui.dart';
import '../../theme/role_style.dart';

class SchoolHome extends ConsumerWidget {
  const SchoolHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(schoolOverviewProvider);
    return overviewAsync.when(
      loading: () => const ShellScrollView(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: LoadingIndicator(message: 'Opening the school…'),
          ),
        ],
      ),
      error: (_, _) => ShellScrollView(
        children: [
          ErrorDisplay(
            message: 'The school could not be loaded.',
            onRetry: () => ref.invalidate(schoolOverviewProvider),
          ),
        ],
      ),
      data: (overview) {
        // Teachers who signed up on their own have a class but no school.
        // The school overview has nothing to list for them, so show their
        // own class and its join code directly.
        if (!overview.hasSchool) return const _SoloTeacherHome();
        final selectedId = ref.watch(selectedClassIdProvider);
        final known = overview.classes.any((item) => item.id == selectedId);
        if (!known && overview.classes.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            final current = ref.read(selectedClassIdProvider);
            final stillKnown = overview.classes.any(
              (item) => item.id == current,
            );
            if (!stillKnown) {
              ref.read(selectedClassIdProvider.notifier).state =
                  overview.classes.first.id;
            }
          });
        }
        SchoolClassInfo? selected;
        for (final item in overview.classes) {
          if (item.id == selectedId) selected = item;
        }
        selected ??= overview.classes.firstOrNull;
        final youId = SupabaseService.instance.currentUser?.id;
        final teachesSelected = selected != null && selected.teacherId == youId;

        return ShellScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: HeroBanner(
                        colors: overview.isAdmin
                            ? HeroColors.school
                            : HeroColors.teacher,
                        eyebrow: overview.isAdmin
                            ? 'School admin'
                            : 'Your classes',
                        title: overview.schoolName ?? 'School',
                        body: overview.isAdmin
                            ? 'Create classes, give each one a teacher, and help every student into a class.'
                            : 'Create your class, then share the code. Students open Me and join with it.',
                        actions: [
                          if (overview.canManageClasses)
                            SunButton(
                              label: 'New class',
                              icon: Icons.add_rounded,
                              onPressed: () => _createClass(context, ref),
                            ),
                          if (overview.isAdmin)
                            HeroGhostButton(
                              label: 'Invite teachers',
                              icon: Icons.person_add_alt_1_rounded,
                              onPressed: () =>
                                  context.go(AppRoutes.schoolTeachers),
                            ),
                        ],
                      ),
                    ),
                    if (overview.memberships.length > 1) ...[
                      const SizedBox(height: 16),
                      _SchoolSwitcher(overview: overview),
                    ],
                    if (overview.isAdmin) ...[
                      const SizedBox(height: 20),
                      _SetupChecklist(overview: overview),
                    ] else ...[
                      const SizedBox(height: 16),
                      DashboardGuide.teacher(),
                    ],
                    const SizedBox(height: 20),
                    _StatRow(overview: overview),
                    if (overview.isAdmin) ...[
                      const SizedBox(height: 20),
                      const _AdminShortcuts(),
                    ],
                    const SizedBox(height: 28),
                    const SectionHeader(
                      title: 'Classes',
                      subtitle:
                          'Pick a class. Progress, Assign, and Live use this class.',
                    ),
                    const SizedBox(height: 12),
                    if (overview.classes.isEmpty)
                      EmptyPanel(
                        icon: Icons.groups_rounded,
                        title: overview.isAdmin
                            ? 'No classes yet'
                            : 'No class yet',
                        body: overview.isAdmin
                            ? 'Create a class, assign a teacher from the people list, then they share a join code.'
                            : 'Tap New class. Then share the class code so students can join from Me.',
                      )
                    else
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final item in overview.classes)
                            _ClassTile(
                              schoolClass: item,
                              selected: selected?.id == item.id,
                              onTap: () {
                                ref
                                        .read(selectedClassIdProvider.notifier)
                                        .state =
                                    item.id;
                              },
                            ),
                        ],
                      ),
                    if (selected != null) ...[
                      const SizedBox(height: 16),
                      _SelectedClassPanel(
                        schoolClass: selected,
                        isAdmin: overview.isAdmin,
                        teachesIt: teachesSelected,
                        onAssignTeacher: () =>
                            _assignTeacher(context, ref, selected!.id),
                        onAddStudent: overview.isAdmin
                            ? () => _assignStudent(context, ref, selected!.id)
                            : null,
                      ),
                    ],
                    if (overview.isAdmin || teachesSelected) ...[
                      const SizedBox(height: 22),
                      const SectionHeader(
                        title: 'Learners in this class',
                        subtitle: 'Students who joined with the class code',
                      ),
                      const SizedBox(height: 12),
                      _SelectedRoster(
                        canEdit: overview.isAdmin || teachesSelected,
                        classId: selected?.id,
                      ),
                    ],
                    const SizedBox(height: 28),
                    SectionHeader(
                      title: 'School ranking',
                      subtitle:
                          '${overview.studentCount} students · lessons this week, then exam answers and mental maths',
                    ),
                    const SizedBox(height: 12),
                    const _SchoolRankList(limit: 15),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createClass(BuildContext context, WidgetRef ref) async {
    final name = await _ask(
      context,
      title: 'New class',
      hint: 'Year 4 Blue',
      action: 'Create',
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    final schoolId = ref.read(schoolOverviewProvider).asData?.value.schoolId;
    final result = await SchoolService.instance.createClass(
      name,
      schoolId: schoolId,
    );
    if (!context.mounted) return;
    if (result.isFailure) {
      context.showErrorSnackbar(result.error ?? 'Could not create the class.');
      return;
    }
    ref.read(selectedClassIdProvider.notifier).state = result.data?.id;
    ref.invalidate(schoolOverviewProvider);
    ref.invalidate(schoolDirectoryProvider);
    ref.invalidate(rosterProvider);
    ref.invalidate(classBoardProvider);
    final code = result.data?.joinCode?.trim();
    context.showSuccessSnackbar(
      code == null || code.isEmpty
          ? '${result.data?.name ?? 'Class'} is ready.'
          : '${result.data?.name ?? 'Class'} is ready. Share code $code with your students.',
    );
  }

  Future<void> _assignTeacher(
    BuildContext context,
    WidgetRef ref,
    String classId,
  ) async {
    final directory =
        ref.read(schoolDirectoryProvider).asData?.value ??
        SchoolDirectory.empty;
    // Only staff can teach a class. New teachers are invited on Teachers.
    final staff = <String, SchoolPerson>{};
    for (final person in [...directory.teachers, ...directory.people]) {
      if (person.email.isNotEmpty &&
          (person.role == 'teacher' || person.role == 'admin')) {
        staff[person.email] = person;
      }
    }
    if (staff.isEmpty) {
      context.showErrorSnackbar(
        'No teachers at this school yet. Invite one on the Teachers page first.',
      );
      return;
    }
    final email = await _pickPerson(
      context,
      title: 'Assign a teacher',
      people: staff.values.toList(),
      allowEmail: false,
    );
    if (email == null || email.isEmpty || !context.mounted) return;
    final result = await SchoolService.instance.assignTeacherToClass(
      classId: classId,
      email: email,
    );
    if (!context.mounted) return;
    if (result.isFailure) {
      context.showErrorSnackbar(
        result.error ?? 'Could not assign that teacher.',
      );
      return;
    }
    ref.invalidate(schoolOverviewProvider);
    ref.invalidate(schoolDirectoryProvider);
    context.showSuccessSnackbar('${result.data} now teaches this class.');
  }

  Future<void> _assignStudent(
    BuildContext context,
    WidgetRef ref,
    String classId,
  ) async {
    final directory =
        ref.read(schoolDirectoryProvider).asData?.value ??
        SchoolDirectory.empty;
    final available = [
      ...directory.students,
      ...directory.people.where((person) => person.role == 'student'),
    ];
    final unique = <String, SchoolPerson>{};
    for (final person in available) {
      if (person.email.isNotEmpty && !person.inClass(classId)) {
        unique[person.email] = person;
      }
    }
    final picked = await _pickPerson(
      context,
      title: 'Place a student',
      people: unique.values.toList(),
      allowEmail: true,
    );
    final email = picked;
    if (email == null || email.isEmpty || !context.mounted) return;
    final result = await SchoolService.instance.assignStudentToClass(
      classId: classId,
      email: email,
    );
    if (!context.mounted) return;
    if (result.isFailure) {
      context.showErrorSnackbar(result.error ?? 'Could not add that student.');
      return;
    }
    ref.invalidate(schoolOverviewProvider);
    ref.invalidate(schoolDirectoryProvider);
    ref.invalidate(rosterProvider);
    ref.invalidate(classBoardProvider);
    ref.invalidate(foundationClassProgressProvider);
    ref.invalidate(foundationClassDashboardProvider);
    context.showSuccessSnackbar('${result.data} is in this class.');
  }

  Future<String?> _pickPerson(
    BuildContext context, {
    required String title,
    required List<SchoolPerson> people,
    bool allowEmail = false,
  }) {
    final query = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            final needle = query.text.trim().toLowerCase();
            final shown = people
                .where(
                  (person) =>
                      needle.isEmpty ||
                      person.displayName.toLowerCase().contains(needle) ||
                      person.email.toLowerCase().contains(needle),
                )
                .take(40)
                .toList();
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: query,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search by name or email',
                      ),
                      onChanged: (_) => setLocal(() {}),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: shown.isEmpty
                          ? Text(
                              people.isEmpty
                                  ? 'Nobody to pick yet. Add them by email.'
                                  : 'No match.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: shown.length,
                              itemBuilder: (context, index) {
                                final person = shown[index];
                                return ListTile(
                                  title: Text(person.displayName),
                                  subtitle: Text(person.email),
                                  onTap: () => Navigator.pop(
                                    dialogContext,
                                    person.email,
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                if (allowEmail)
                  TextButton(
                    onPressed: () async {
                      final typed = await _ask(
                        context,
                        title: title,
                        hint: 'name@school.org',
                        action: 'Use email',
                        keyboard: TextInputType.emailAddress,
                      );
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, typed);
                      }
                    },
                    child: const Text('Use email'),
                  ),
              ],
            );
          },
        );
      },
    ).whenComplete(query.dispose);
  }

  Future<String?> _ask(
    BuildContext context, {
    required String title,
    required String hint,
    required String action,
    TextInputType keyboard = TextInputType.text,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: keyboard,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(action),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }
}

class _StatRow extends StatelessWidget {
  final SchoolOverview overview;

  const _StatRow({required this.overview});

  @override
  Widget build(BuildContext context) {
    final classes = overview.classes;
    final withTeacher = classes.where((item) => item.hasTeacher).length;
    final seated = classes.fold<int>(0, (sum, item) => sum + item.memberCount);
    final teachers = {
      for (final item in classes)
        if (item.hasTeacher) item.teacherId,
    }.length;
    return SizedBox(
      width: double.infinity,
      child: AdaptiveGrid(
        minTileWidth: 150,
        children: [
          MetricTile(
            tint: AppTint.violet,
            icon: Icons.school_rounded,
            label: 'Students',
            value: '${overview.studentCount}',
            caption: '$seated seated in a class',
          ),
          MetricTile(
            tint: AppTint.mint,
            icon: Icons.groups_rounded,
            label: 'Classes',
            value: '${classes.length}',
            caption: classes.isEmpty ? 'Create the first one' : 'This school',
          ),
          if (overview.isAdmin) ...[
            MetricTile(
              tint: withTeacher < classes.length
                  ? StatusChip.alert
                  : AppTint.sky,
              icon: Icons.person_rounded,
              label: 'With a teacher',
              value: '$withTeacher / ${classes.length}',
              caption: withTeacher < classes.length
                  ? '${classes.length - withTeacher} need a teacher'
                  : 'All covered',
            ),
            MetricTile(
              tint: AppTint.sun,
              icon: Icons.co_present_rounded,
              label: 'Teachers with a class',
              value: '$teachers',
              caption: 'Assigned to at least one',
            ),
          ],
        ],
      ),
    );
  }
}

/// Setup steps a school admin works through. Hidden once all are done.
class _SetupChecklist extends ConsumerWidget {
  final SchoolOverview overview;

  const _SetupChecklist({required this.overview});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classes = overview.classes;
    final directory = ref.watch(schoolDirectoryProvider).asData?.value;
    final teachers = directory?.teachers.length ?? 0;
    final unplaced =
        directory?.students.where((s) => s.classIds.isEmpty).length ?? 0;
    final steps = [
      (
        'Invite teachers',
        teachers == 0
            ? 'Share the staff code'
            : '$teachers teacher${teachers == 1 ? '' : 's'} joined',
        teachers > 0,
        AppRoutes.schoolTeachers,
      ),
      (
        'Create classes',
        classes.isEmpty
            ? 'Tap New class above'
            : '${classes.length} class${classes.length == 1 ? '' : 'es'}',
        classes.isNotEmpty,
        null,
      ),
      (
        'Give every class a teacher',
        classes.isEmpty
            ? 'After the first class'
            : '${classes.where((c) => !c.hasTeacher).length} without one',
        classes.isNotEmpty && classes.every((c) => c.hasTeacher),
        null,
      ),
      (
        'Every student in a class',
        directory == null
            ? 'Checking…'
            : unplaced == 0
            ? 'All ${overview.studentCount} placed'
            : '$unplaced not in a class',
        directory != null && overview.studentCount > 0 && unplaced == 0,
        AppRoutes.schoolStudents,
      ),
    ];
    final done = steps.where((s) => s.$3).length;
    if (done == steps.length) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: KvCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KvSectionTitle(
              title: 'Finish setting up',
              subtitle:
                  '$done of ${steps.length} done. This card goes away when every step is done.',
            ),
            KvBar(value: done / steps.length, tint: AppTint.mint, height: 10),
            const SizedBox(height: 16),
            AdaptiveGrid(
              minTileWidth: 210,
              maxColumns: 4,
              gap: 12,
              children: [
                for (var i = 0; i < steps.length; i++)
                  KvCard(
                    tint: steps[i].$3 ? AppTint.mint : AppTint.sun,
                    padding: const EdgeInsets.all(14),
                    onTap: steps[i].$3 || steps[i].$4 == null
                        ? null
                        : () => context.go(steps[i].$4!),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: steps[i].$3
                                ? AppTint.mint.ink
                                : AppColors.surface,
                            shape: BoxShape.circle,
                            border: steps[i].$3
                                ? null
                                : Border.all(color: AppTint.sun.ink, width: 2),
                          ),
                          child: steps[i].$3
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 18,
                                  semanticLabel: 'Done',
                                )
                              : Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    color: AppTint.sun.ink,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                steps[i].$1,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                steps[i].$2,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassTile extends StatelessWidget {
  final SchoolClassInfo schoolClass;
  final bool selected;
  final VoidCallback onTap;

  const _ClassTile({
    required this.schoolClass,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: 240,
      child: Material(
        color: selected ? AppColors.primarySoft : AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: const Cubic(0.23, 1, 0.32, 1),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.45)
                    : AppColors.ink.withValues(alpha: 0.08),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(schoolClass.name, style: text.titleMedium),
                const SizedBox(height: 6),
                Text(
                  schoolClass.hasTeacher
                      ? schoolClass.teacherName
                      : 'No teacher yet',
                  style: text.bodyMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  '${schoolClass.memberCount} learners',
                  style: text.labelLarge?.copyWith(color: AppColors.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedClassPanel extends ConsumerWidget {
  final SchoolClassInfo schoolClass;
  final bool isAdmin;
  final bool teachesIt;
  final VoidCallback onAssignTeacher;
  final VoidCallback? onAddStudent;

  const _SelectedClassPanel({
    required this.schoolClass,
    required this.isAdmin,
    required this.teachesIt,
    required this.onAssignTeacher,
    this.onAddStudent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final code = schoolClass.joinCode ?? '';
    return GlassCard(
      gradient: AppColors.brandGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            schoolClass.name,
            style: text.titleLarge?.copyWith(color: Colors.white, fontSize: 20),
          ),
          const SizedBox(height: 4),
          Text(
            schoolClass.hasTeacher
                ? '${schoolClass.teacherName} teaches this class. Students join with the code.'
                : 'Assign a teacher. They share this code with the class.',
            style: text.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          if (code.isEmpty && (isAdmin || teachesIt)) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
              ),
              onPressed: () async {
                final result = await SupabaseService.instance
                    .regenerateClassCode(schoolClass.id);
                if (!context.mounted) return;
                if (result.isSuccess) {
                  ref.invalidate(schoolOverviewProvider);
                  context.showSuccessSnackbar('Class code ready.');
                } else {
                  context.showErrorSnackbar(
                    result.error ?? 'Could not make a class code.',
                  );
                }
              },
              icon: const Icon(Icons.vpn_key_rounded),
              label: const Text('Make a class code'),
            ),
          ],
          if (code.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Text(
                      code,
                      style: text.headlineSmall?.copyWith(
                        color: Colors.white,
                        letterSpacing: 5,
                        fontSize: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (context.mounted) {
                      context.showSuccessSnackbar('Code copied.');
                    }
                  },
                  icon: const Icon(Icons.copy_rounded),
                ),
                if (isAdmin || teachesIt)
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final result = await SupabaseService.instance
                          .regenerateClassCode(schoolClass.id);
                      if (!context.mounted) return;
                      if (result.isSuccess) {
                        ref.invalidate(schoolOverviewProvider);
                        context.showSuccessSnackbar(
                          'New class code generated.',
                        );
                      } else {
                        context.showErrorSnackbar(
                          result.error ?? 'Could not regenerate the code.',
                        );
                      }
                    },
                    icon: const Icon(Icons.refresh_rounded),
                  ),
              ],
            ),
          ],
          if (isAdmin || teachesIt) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (isAdmin)
                  FilledButton.tonal(
                    onPressed: onAssignTeacher,
                    child: Text(
                      schoolClass.hasTeacher
                          ? 'Change teacher'
                          : 'Assign teacher',
                    ),
                  ),
                if (isAdmin && onAddStudent != null)
                  FilledButton.tonal(
                    onPressed: onAddStudent,
                    child: const Text('Place a student'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class SchoolStudentRank extends ConsumerWidget {
  const SchoolStudentRank({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(schoolOverviewProvider).asData?.value;
    if (overview == null || !overview.hasSchool || overview.canManageClasses) {
      return const SizedBox.shrink();
    }
    if (overview.entries.every((entry) => entry.weeklyXp == 0)) {
      return const SizedBox.shrink();
    }
    final text = Theme.of(context).textTheme;
    final you = overview.you;
    final shown = overview.entries.take(5).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(overview.schoolName ?? 'School', style: text.titleMedium),
            if (overview.memberships.length > 1) ...[
              const SizedBox(height: 8),
              _SchoolSwitcher(overview: overview),
            ],
            const SizedBox(height: 4),
            Text(
              you == null
                  ? '${overview.studentCount} students. Your place shows once you are in a class and practising.'
                  : 'You are #${you.rank} this week · ${overview.studentCount} students',
              style: text.bodyMedium,
            ),
            if (shown.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final entry in shown)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${entry.rank}',
                          style: text.titleMedium?.copyWith(
                            color: entry.isYou
                                ? AppColors.primary
                                : AppColors.inkSoft,
                          ),
                        ),
                      ),
                      Text(entry.avatar, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          entry.isYou
                              ? '${entry.displayName} (you)'
                              : entry.displayName,
                          style: text.titleMedium?.copyWith(fontSize: 15),
                        ),
                      ),
                      Text('${entry.weeklyXp} XP', style: text.bodyMedium),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SchoolSwitcher extends ConsumerWidget {
  final SchoolOverview overview;

  const _SchoolSwitcher({required this.overview});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final school in overview.memberships)
          ChoiceChip(
            label: Text(school.name),
            selected: school.id == overview.schoolId,
            onSelected: (_) {
              ref.read(selectedSchoolIdProvider.notifier).state = school.id;
              ref.read(selectedClassIdProvider.notifier).state = null;
            },
          ),
      ],
    );
  }
}

class _SchoolRankList extends ConsumerWidget {
  final int limit;

  const _SchoolRankList({required this.limit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(schoolOverviewProvider).asData?.value;
    final text = Theme.of(context).textTheme;
    if (overview == null) return const SizedBox.shrink();
    final shown = overview.entries.take(limit).toList();
    if (shown.isEmpty || shown.every((entry) => entry.weeklyXp == 0)) {
      return const EmptyPanel(
        icon: Icons.emoji_events_outlined,
        title: 'Ranking opens as students practise',
        body:
            'Everyone starts at zero. Lessons this week come first, then exam answers and mental maths.',
      );
    }
    return GlassCard(
      child: Column(
        children: [
          for (final entry in shown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  _RankMark(rank: entry.rank, highlight: entry.isYou),
                  const SizedBox(width: 10),
                  Text(entry.avatar, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.isYou
                          ? '${entry.displayName} (you)'
                          : entry.displayName,
                      style: text.titleMedium?.copyWith(fontSize: 15),
                    ),
                  ),
                  Text('${entry.weeklyXp} XP', style: text.bodyMedium),
                ],
              ),
            ),
          if (overview.entries.length > shown.length)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${overview.entries.length - shown.length} more students',
                style: text.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }
}

class _RankMark extends StatelessWidget {
  final int rank;
  final bool highlight;

  const _RankMark({required this.rank, required this.highlight});

  @override
  Widget build(BuildContext context) {
    final color = switch (rank) {
      1 => const Color(0xFFD4A017),
      2 => const Color(0xFF8A93A8),
      3 => const Color(0xFFB0723A),
      _ => highlight ? AppColors.primary : AppColors.inkSoft,
    };
    return SizedBox(
      width: 28,
      child: Text(
        '$rank',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
      ),
    );
  }
}

class _SelectedRoster extends ConsumerWidget {
  final bool canEdit;
  final String? classId;

  const _SelectedRoster({required this.canEdit, this.classId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rosterAsync = ref.watch(rosterProvider);
    final text = Theme.of(context).textTheme;
    return rosterAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => ErrorDisplay(
        message: 'This class could not be loaded.',
        onRetry: () => ref.invalidate(rosterProvider),
      ),
      data: (roster) {
        if (roster.isEmpty) {
          return const EmptyPanel(
            icon: Icons.person_add_alt_1_rounded,
            title: 'No learners in this class yet',
            body:
                'Share the class code. Students open Me, tap Join your class, and type it in.',
          );
        }
        return GlassCard(
          child: Column(
            children: [
              for (final student in roster)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          student.avatarEmoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(student.name, style: text.titleMedium),
                      ),
                      if (canEdit &&
                          classId != null &&
                          student.userId.isNotEmpty)
                        IconButton(
                          tooltip: 'Remove from class',
                          onPressed: () async {
                            final result = await SchoolService.instance
                                .removeStudentFromClass(
                                  classId: classId!,
                                  userId: student.userId,
                                );
                            if (!context.mounted) return;
                            if (result.isFailure) {
                              context.showErrorSnackbar(
                                result.error ?? 'Could not remove them.',
                              );
                              return;
                            }
                            ref.invalidate(rosterProvider);
                            ref.invalidate(schoolOverviewProvider);
                            ref.invalidate(schoolDirectoryProvider);
                            ref.invalidate(foundationClassProgressProvider);
                            ref.invalidate(foundationClassDashboardProvider);
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Home for a teacher with no school yet: their class, its code, roster.
class _SoloTeacherHome extends ConsumerWidget {
  const _SoloTeacherHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(teacherClassInfoProvider);
    return ShellScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PageIntro(
                  eyebrow: 'Your class',
                  title: 'Share your class code',
                  body:
                      'Students open Me, tap Join your class, and type this code.',
                ),
                const SizedBox(height: 16),
                DashboardGuide.teacher(),
                const SizedBox(height: 18),
                info.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: LoadingIndicator(message: 'Opening your class…'),
                  ),
                  error: (_, _) => ErrorDisplay(
                    message: 'Your class code could not be loaded.',
                    onRetry: () => ref.invalidate(teacherClassInfoProvider),
                  ),
                  data: (value) => value == null
                      ? ErrorDisplay(
                          message: 'Your class could not be set up yet.',
                          onRetry: () =>
                              ref.invalidate(teacherClassInfoProvider),
                        )
                      : _SoloClassCard(
                          id: value.id,
                          name: value.name,
                          code: value.code,
                        ),
                ),
                const SizedBox(height: 22),
                const SectionHeader(
                  title: 'Learners in this class',
                  subtitle: 'Students who joined with your code',
                ),
                const SizedBox(height: 12),
                const _SelectedRoster(canEdit: true),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SoloClassCard extends ConsumerWidget {
  final String id;
  final String name;
  final String code;

  const _SoloClassCard({
    required this.id,
    required this.name,
    required this.code,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    Future<void> regenerate() async {
      final result = await SupabaseService.instance.regenerateClassCode(id);
      if (!context.mounted) return;
      if (result.isSuccess) {
        ref.invalidate(teacherClassInfoProvider);
        context.showSuccessSnackbar('New class code generated.');
      } else {
        context.showErrorSnackbar(result.error ?? 'Could not make a new code.');
      }
    }

    return GlassCard(
      gradient: AppColors.brandGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: text.titleLarge?.copyWith(color: Colors.white, fontSize: 20),
          ),
          const SizedBox(height: 16),
          if (code.isEmpty)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
              ),
              onPressed: regenerate,
              icon: const Icon(Icons.vpn_key_rounded),
              label: const Text('Make a class code'),
            )
          else
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: SelectableText(
                      code,
                      style: text.headlineSmall?.copyWith(
                        color: Colors.white,
                        letterSpacing: 5,
                        fontSize: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Copy code',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (context.mounted) {
                      context.showSuccessSnackbar('Code copied.');
                    }
                  },
                  icon: const Icon(Icons.copy_rounded),
                ),
                IconButton.filled(
                  tooltip: 'New code',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: regenerate,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Big tappable cards to the admin pages.
class _AdminShortcuts extends ConsumerWidget {
  const _AdminShortcuts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final directory = ref.watch(schoolDirectoryProvider).asData?.value;
    final teachers = directory?.teachers.length;
    final unplaced = directory?.students
        .where((s) => s.classIds.isEmpty)
        .length;
    final items = [
      (
        AppTint.sky,
        Icons.co_present_rounded,
        'Teachers',
        teachers == null ? 'Invite and manage staff' : '$teachers on staff',
        AppRoutes.schoolTeachers,
      ),
      (
        AppTint.violet,
        Icons.school_rounded,
        'Students',
        unplaced == null || unplaced == 0
            ? 'Find and place students'
            : '$unplaced need a class',
        AppRoutes.schoolStudents,
      ),
      (
        AppTint.sun,
        Icons.settings_rounded,
        'Settings',
        'School name and staff code',
        AppRoutes.schoolSettings,
      ),
    ];
    return SizedBox(
      width: double.infinity,
      child: AdaptiveGrid(
        minTileWidth: 200,
        maxColumns: 3,
        children: [
          for (final item in items)
            KvCard(
              tint: item.$1,
              onTap: () => context.go(item.$5),
              semanticLabel: 'Open ${item.$3}. ${item.$4}',
              child: Row(
                children: [
                  TintIcon(tint: item.$1, icon: item.$2),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$3,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          item.$4,
                          style: TextStyle(fontSize: 13, color: item.$1.ink),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, color: item.$1.ink),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

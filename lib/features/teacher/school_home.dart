import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_state.dart';
import '../../models/school_models.dart';
import '../../services/school_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/empty_panel.dart';
import '../../widgets/error_boundary.dart';
import '../../widgets/surfaces.dart';

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
        final teachesSelected =
            selected != null && selected.teacherId == youId;

        return ShellScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PageIntro(
                      eyebrow: overview.isAdmin ? 'School' : 'Your classes',
                      title: overview.schoolName ?? 'School',
                      body: overview.isAdmin
                          ? 'Create classes, then assign teachers and students to them.'
                          : 'Classes the school assigned to you.',
                    ),
                    if (overview.memberships.length > 1) ...[
                      const SizedBox(height: 12),
                      _SchoolSwitcher(overview: overview),
                    ],
                    const SizedBox(height: 18),
                    _StatRow(overview: overview),
                    if (overview.isAdmin) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: () => _createClass(context, ref),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('New class'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _addTeacher(
                              context,
                              ref,
                              overview.schoolId,
                            ),
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: const Text('Add a teacher'),
                          ),
                        ],
                      ),
                    ],
                    if (overview.isAdmin) ...[
                      const SizedBox(height: 28),
                      const SectionHeader(
                        title: 'Teachers',
                        subtitle: 'Staff at this school. Assign them a class next.',
                      ),
                      const SizedBox(height: 12),
                      const _TeacherStaffList(),
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
                            : 'No class assigned yet',
                        body: overview.isAdmin
                            ? 'Create a class, assign a teacher, then add students by email.'
                            : 'When the school admin assigns you a class, it will show here with the students in it.',
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
                        onAssignTeacher: () => _assignTeacher(
                          context,
                          ref,
                          selected!.id,
                        ),
                        onAddStudent: () => _assignStudent(
                          context,
                          ref,
                          selected!.id,
                        ),
                      ),
                    ],
                    if (overview.isAdmin || teachesSelected) ...[
                      const SizedBox(height: 22),
                      const SectionHeader(
                        title: 'Learners in this class',
                        subtitle: 'Everyone the school placed here',
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
    context.showSuccessSnackbar('${result.data?.name ?? 'Class'} is ready.');
  }

  Future<void> _addTeacher(
    BuildContext context,
    WidgetRef ref,
    String? schoolId,
  ) async {
    final email = await _ask(
      context,
      title: 'Add a teacher',
      hint: 'name@school.org',
      action: 'Add',
      keyboard: TextInputType.emailAddress,
    );
    if (email == null || email.isEmpty || !context.mounted) return;
    final result = await SchoolService.instance.addTeacher(
      email,
      schoolId: schoolId,
    );
    if (!context.mounted) return;
    if (result.isFailure) {
      context.showErrorSnackbar(result.error ?? 'Could not add that teacher.');
      return;
    }
    ref.invalidate(schoolOverviewProvider);
    ref.invalidate(schoolDirectoryProvider);
    context.showSuccessSnackbar(
      '${result.data} is a teacher at this school. Assign them a class next.',
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
    final picked = await _pickPerson(
      context,
      title: 'Assign a teacher',
      people: directory.teachers,
      allowEmail: true,
    );
    final email = picked;
    if (email == null || email.isEmpty || !context.mounted) return;
    final result = await SchoolService.instance.assignTeacherToClass(
      classId: classId,
      email: email,
    );
    if (!context.mounted) return;
    if (result.isFailure) {
      context.showErrorSnackbar(result.error ?? 'Could not assign that teacher.');
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
    final available = directory.students
        .where((person) => !person.inClass(classId))
        .toList();
    final picked = await _pickPerson(
      context,
      title: 'Add a student',
      people: available,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final tiles = [
          _StatTile(
            label: 'Students',
            value: '${overview.studentCount}',
            icon: Icons.school_rounded,
            color: AppColors.primary,
          ),
          _StatTile(
            label: 'Classes',
            value: '${overview.classes.length}',
            icon: Icons.groups_rounded,
            color: AppColors.worldLanguage,
          ),
          _StatTile(
            label: 'Assigned',
            value:
                '${overview.classes.where((item) => item.hasTeacher).length}',
            icon: Icons.person_rounded,
            color: AppColors.worldExams,
          ),
        ];
        if (wide) {
          return Row(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: tiles[i]),
              ],
            ],
          );
        }
        return Column(
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              tiles[i],
            ],
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: text.headlineSmall?.copyWith(fontSize: 26),
              ),
              Text(label, style: text.bodyMedium),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeacherStaffList extends ConsumerWidget {
  const _TeacherStaffList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final directory = ref.watch(schoolDirectoryProvider);
    final text = Theme.of(context).textTheme;
    return directory.when(
      loading: () => const LinearProgressIndicator(minHeight: 3),
      error: (_, _) => const SizedBox.shrink(),
      data: (value) {
        if (value.teachers.isEmpty) {
          return const EmptyPanel(
            icon: Icons.person_outline_rounded,
            title: 'No teachers yet',
            body:
                'Add a teacher by email. They get the teacher dashboard, then you assign them a class.',
          );
        }
        return GlassCard(
          child: Column(
            children: [
              for (final teacher in value.teachers)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(teacher.displayName, style: text.titleMedium),
                            Text(teacher.email, style: text.bodyMedium),
                          ],
                        ),
                      ),
                      Text(
                        teacher.classIds.isEmpty
                            ? 'No class'
                            : '${teacher.classIds.length} class${teacher.classIds.length == 1 ? '' : 'es'}',
                        style: text.bodyMedium,
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
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.line,
                width: selected ? 1.6 : 1,
              ),
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
  final VoidCallback onAddStudent;

  const _SelectedClassPanel({
    required this.schoolClass,
    required this.isAdmin,
    required this.teachesIt,
    required this.onAssignTeacher,
    required this.onAddStudent,
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
                ? '${schoolClass.teacherName} teaches this class.'
                : 'Assign a teacher, then add students by email.',
            style: text.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
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
                        context.showSuccessSnackbar('New class code generated.');
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
                FilledButton.tonal(
                  onPressed: onAddStudent,
                  child: const Text('Add student'),
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
    if (shown.isEmpty) {
      return const EmptyPanel(
        icon: Icons.emoji_events_outlined,
        title: 'Ranking opens as students practise',
        body:
            'Lessons this week come first, then correct exam answers and mental maths.',
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
                'Add students by name or email. They will appear here, then on Progress and Assign.',
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

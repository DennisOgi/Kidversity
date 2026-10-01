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

class SchoolHome extends ConsumerWidget {
  const SchoolHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(schoolOverviewProvider);
    final text = Theme.of(context).textTheme;
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
            final stillKnown = overview.classes.any((item) => item.id == current);
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
        final ownsSelected = selected != null && selected.teacherId == youId;
        return ShellScrollView(
          children: [
            Text(
              overview.schoolName ?? 'School',
              style: text.headlineSmall?.copyWith(fontSize: 26),
            ),
            if (overview.memberships.length > 1) ...[
              const SizedBox(height: 10),
              _SchoolSwitcher(overview: overview),
            ],
            const SizedBox(height: 6),
            Text(
              overview.isAdmin
                  ? 'Every class in the school, and how students are moving.'
                  : 'Your classes in this school. Share a code so learners can join.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (overview.canManageClasses)
                  FilledButton.icon(
                    onPressed: () => _createClass(context, ref),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('New class'),
                  ),
                if (overview.isAdmin) ...[
                  OutlinedButton.icon(
                    onPressed: () => _addTeacher(context, ref, overview.schoolId),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Add a teacher'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _createSchool(context, ref),
                    icon: const Icon(Icons.account_balance_rounded),
                    label: const Text('New school'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
            Text('Classes', style: text.titleLarge),
            const SizedBox(height: 10),
            if (overview.classes.isEmpty)
              const EmptyPanel(
                icon: Icons.groups_rounded,
                title: 'No classes yet',
                body:
                    'Create a class and share its code. Students open Profile, tap Join your class, and type it in.',
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in overview.classes)
                    ChoiceChip(
                      label: Text('${item.name} · ${item.memberCount}'),
                      selected: selected?.id == item.id,
                      onSelected: (_) {
                        ref.read(selectedClassIdProvider.notifier).state =
                            item.id;
                      },
                    ),
                ],
              ),
              if (selected != null) ...[
                const SizedBox(height: 8),
                Text(
                  ownsSelected
                      ? 'You teach ${selected.name}.'
                      : '${selected.teacherName} teaches ${selected.name}.',
                  style: text.bodyMedium,
                ),
                if ((selected.joinCode ?? '').isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _ClassCodeCard(schoolClass: selected),
                ],
              ],
            ],
            const SizedBox(height: 22),
            Text('School ranking', style: text.titleLarge),
            const SizedBox(height: 6),
            Text(
              '${overview.studentCount} students · this week’s lessons, then exam answers and mental maths.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 10),
            const _SchoolRankList(limit: 15),
            if (ownsSelected) ...[
              const SizedBox(height: 22),
              Text('Learners in this class', style: text.titleLarge),
              const SizedBox(height: 10),
              const _SelectedRoster(),
            ],
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
    ref.invalidate(rosterProvider);
    ref.invalidate(classBoardProvider);
    context.showSuccessSnackbar('${result.data?.name ?? 'Class'} is ready.');
  }

  Future<void> _createSchool(BuildContext context, WidgetRef ref) async {
    final name = await _ask(
      context,
      title: 'New school',
      hint: 'School name',
      action: 'Create',
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    final result = await SchoolService.instance.createSchool(name);
    if (!context.mounted) return;
    if (result.isFailure) {
      context.showErrorSnackbar(result.error ?? 'Could not create the school.');
      return;
    }
    ref.read(selectedSchoolIdProvider.notifier).state = result.data?.id;
    ref.read(selectedClassIdProvider.notifier).state = null;
    ref.invalidate(schoolOverviewProvider);
    context.showSuccessSnackbar('${result.data?.name ?? 'School'} is ready.');
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
    context.showSuccessSnackbar('${result.data} can now manage classes.');
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
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(action),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
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
                  ? '${overview.studentCount} students. Your place shows after you join.'
                  : 'You are #${you.rank} · ${overview.studentCount} students',
              style: text.bodyMedium,
            ),
            if (shown.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final entry in shown)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${entry.rank}. ${entry.displayName}${entry.isYou ? ' (you)' : ''} · ${entry.weeklyXp} XP',
                    style: text.bodyMedium,
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

class _ClassCodeCard extends ConsumerWidget {
  final SchoolClassInfo schoolClass;

  const _ClassCodeCard({required this.schoolClass});

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
            style: text.titleLarge?.copyWith(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            'Students tap Join your class in Profile and enter this code.',
            style: text.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Text(
                    code,
                    style: text.headlineSmall?.copyWith(
                      color: Colors.white,
                      letterSpacing: 6,
                      fontSize: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.22),
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
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.22),
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
      ),
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.isYou ? '${entry.displayName} (you)' : entry.displayName,
                      style: text.titleMedium?.copyWith(fontSize: 15),
                    ),
                  ),
                  Text(
                    '${entry.weeklyXp} XP',
                    style: text.bodyMedium,
                  ),
                ],
              ),
            ),
          if (overview.entries.length > shown.length)
            Padding(
              padding: const EdgeInsets.only(top: 6),
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

class _SelectedRoster extends ConsumerWidget {
  const _SelectedRoster();

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
            body: 'Share the code above. Names appear here after they join.',
          );
        }
        return Column(
          children: [
            for (final student in roster)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Text(
                      student.avatarEmoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(student.name, style: text.titleMedium),
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

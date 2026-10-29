import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_state.dart';
import '../../models/admin_models.dart';
import '../../services/admin_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/empty_panel.dart';
import '../../widgets/error_boundary.dart';
import '../../widgets/surfaces.dart';

class AdminSchoolsScreen extends ConsumerStatefulWidget {
  const AdminSchoolsScreen({super.key});

  @override
  ConsumerState<AdminSchoolsScreen> createState() => _AdminSchoolsScreenState();
}

class _AdminSchoolsScreenState extends ConsumerState<AdminSchoolsScreen> {
  String? _selectedId;
  String _query = '';

  Future<void> _createSchool() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create school'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'School name',
                hintText: 'Pearls Garden',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                labelText: 'School admin email (optional)',
                hintText: 'teacher@school.com',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final name = nameCtrl.text.trim();
    final email = emailCtrl.text.trim();
    if (name.length < 2) {
      context.showErrorSnackbar('Enter a school name.');
      return;
    }
    final result = await AdminService.instance.createSchool(
      name: name,
      adminEmail: email.isEmpty ? null : email,
    );
    if (!mounted) return;
    if (result.isFailure) {
      context.showErrorSnackbar(result.error ?? 'Could not create school.');
      return;
    }
    ref.invalidate(adminSchoolsProvider);
    ref.invalidate(adminOverviewProvider);
    setState(() => _selectedId = result.data?.id);
    context.showSuccessSnackbar('School created.');
  }

  Future<void> _assignAdmin(String schoolId) async {
    final emailCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign school admin'),
        content: TextField(
          controller: emailCtrl,
          decoration: const InputDecoration(
            labelText: 'Existing user email',
            hintText: 'teacher@school.com',
          ),
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Assign'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final email = emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      context.showErrorSnackbar('Enter a valid email.');
      return;
    }
    final users = await AdminService.instance.listUsers(search: email, limit: 5);
    if (!mounted) return;
    if (users.isFailure || users.data == null || users.data!.users.isEmpty) {
      context.showErrorSnackbar('No Kidversity account uses that email.');
      return;
    }
    final match = users.data!.users.firstWhere(
      (u) => (u.email ?? '').toLowerCase() == email,
      orElse: () => users.data!.users.first,
    );
    final result = await AdminService.instance.assignSchoolAdmin(
      schoolId: schoolId,
      userId: match.userId,
    );
    if (!mounted) return;
    if (result.isFailure) {
      context.showErrorSnackbar(result.error ?? 'Could not assign admin.');
      return;
    }
    ref.invalidate(adminSchoolDetailProvider(schoolId));
    ref.invalidate(adminSchoolsProvider);
    context.showSuccessSnackbar('${match.displayName} is now a school admin.');
  }

  @override
  Widget build(BuildContext context) {
    final schools = ref.watch(adminSchoolsProvider);

    return ShellScrollView(
      children: [
        PageIntro(
          eyebrow: 'Platform',
          title: 'Schools',
          body: 'Browse tenants, open detail, create a school, or assign a school admin.',
          trailing: FilledButton.icon(
            onPressed: _createSchool,
            icon: const Icon(Icons.add_rounded),
            label: const Text('New school'),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'Search schools',
          ),
          onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
        ),
        const SizedBox(height: 18),
        schools.when(
          loading: () => const LoadingIndicator(message: 'Loading schools…'),
          error: (error, _) => ErrorDisplay(
            message: 'Schools could not be loaded.',
            error: error,
            onRetry: () => ref.invalidate(adminSchoolsProvider),
          ),
          data: (items) {
            final filtered = items
                .where((s) => _query.isEmpty || s.name.toLowerCase().contains(_query))
                .toList();
            if (filtered.isEmpty) {
              return const EmptyPanel(
                icon: Icons.apartment_rounded,
                title: 'No schools',
                body: 'Create a school to get started.',
              );
            }
            final selectedId = _selectedId ?? filtered.first.id;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final school in filtered) ...[
                  _SchoolTile(
                    school: school,
                    selected: school.id == selectedId,
                    onTap: () => setState(() => _selectedId = school.id),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 12),
                _SchoolDetailPanel(
                  schoolId: selectedId,
                  onAssignAdmin: () => _assignAdmin(selectedId),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SchoolTile extends StatelessWidget {
  final AdminSchoolSummary school;
  final bool selected;
  final VoidCallback onTap;

  const _SchoolTile({
    required this.school,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      border: Border.all(
        color: selected ? AppColors.ink : AppColors.line,
        width: selected ? 1.6 : 1,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(school.name, style: text.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '${school.studentCount} students · ${school.teacherCount} staff · '
                  '${school.classCount} classes · ${school.weeklyXp} XP this week',
                  style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          if (selected)
            const Icon(Icons.check_circle_rounded, color: AppColors.ink),
        ],
      ),
    );
  }
}

class _SchoolDetailPanel extends ConsumerWidget {
  final String schoolId;
  final VoidCallback onAssignAdmin;

  const _SchoolDetailPanel({
    required this.schoolId,
    required this.onAssignAdmin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(adminSchoolDetailProvider(schoolId));
    return detail.when(
      loading: () => const LoadingIndicator(message: 'Opening school…'),
      error: (error, _) => ErrorDisplay(
        message: 'School detail could not be loaded.',
        error: error,
        onRetry: () => ref.invalidate(adminSchoolDetailProvider(schoolId)),
      ),
      data: (school) {
        final text = Theme.of(context).textTheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: school.name,
              subtitle: 'Classes, staff, and top learners this week',
              action: OutlinedButton.icon(
                onPressed: onAssignAdmin,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Assign admin'),
              ),
            ),
            Text('Classes', style: text.titleSmall),
            const SizedBox(height: 8),
            if (school.classes.isEmpty)
              Text(
                'No classes yet.',
                style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
              )
            else
              for (final item in school.classes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      '${item.name} · ${item.memberCount} learners · '
                      '${item.teacherName}'
                      '${item.joinCode == null ? '' : ' · code ${item.joinCode}'}',
                      style: text.bodyMedium,
                    ),
                  ),
                ),
            const SizedBox(height: 16),
            Text('Staff', style: text.titleSmall),
            const SizedBox(height: 8),
            if (school.staff.isEmpty)
              Text(
                'No staff yet.',
                style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
              )
            else
              for (final person in school.staff)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Text(person.avatarEmoji, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(person.displayName, style: text.titleSmall),
                              Text(
                                '${person.role}${person.email == null ? '' : ' · ${person.email}'}',
                                style: text.bodySmall?.copyWith(
                                  color: AppColors.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 16),
            Text('Top learners this week', style: text.titleSmall),
            const SizedBox(height: 8),
            if (school.topLearners.isEmpty)
              Text(
                'No learner activity this week.',
                style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
              )
            else
              for (final learner in school.topLearners)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Text(learner.avatarEmoji, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(learner.displayName, style: text.titleSmall),
                        ),
                        Text(
                          '${learner.weeklyXp} XP · ${learner.lessonsCompleted} lessons',
                          style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

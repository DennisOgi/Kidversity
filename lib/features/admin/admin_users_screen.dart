import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../models/admin_models.dart';
import '../../router/navigation.dart';
import '../../services/admin_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/empty_panel.dart';
import '../../widgets/error_boundary.dart';
import '../../widgets/surfaces.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: ref.read(adminUserSearchProvider));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _toggleActive(AdminUserSummary user) async {
    final next = !user.active;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(next ? 'Reactivate account?' : 'Deactivate account?'),
        content: Text(
          next
              ? '${user.displayName} will be able to sign in again.'
              : '${user.displayName} will be signed out of new sessions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(next ? 'Reactivate' : 'Deactivate'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final result = await AdminService.instance.setUserActive(
      userId: user.userId,
      active: next,
    );
    if (!mounted) return;
    if (result.isFailure) {
      context.showErrorSnackbar(result.error ?? 'Could not update account.');
      return;
    }
    ref.invalidate(adminUsersProvider);
    context.showSuccessSnackbar(
      next ? 'Account reactivated.' : 'Account deactivated.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(adminUsersProvider);
    final roleFilter = ref.watch(adminUserRoleFilterProvider);
    final schools = ref.watch(adminSchoolsProvider);
    final schoolId = ref.watch(adminSelectedSchoolIdProvider);

    return ShellScrollView(
      children: [
        const PageIntro(
          eyebrow: 'Platform',
          title: 'Users',
          body: 'Search accounts, filter by role or school, open performance, or deactivate.',
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _search,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'Search name or email',
          ),
          onChanged: (value) {
            ref.read(adminUserSearchProvider.notifier).state = value;
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in const [
              (null, 'All roles'),
              ('student', 'Students'),
              ('teacher', 'Teachers'),
              ('reviewer', 'Reviewers'),
              ('platform_admin', 'Admins'),
            ])
              FilterChip(
                label: Text(entry.$2),
                selected: roleFilter == entry.$1,
                onSelected: (_) {
                  ref.read(adminUserRoleFilterProvider.notifier).state =
                      entry.$1;
                },
              ),
          ],
        ),
        const SizedBox(height: 10),
        schools.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (items) => DropdownButtonFormField<String?>(
            key: ValueKey(schoolId ?? 'all'),
            initialValue: schoolId,
            decoration: const InputDecoration(labelText: 'School filter'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All schools'),
              ),
              for (final school in items)
                DropdownMenuItem<String?>(
                  value: school.id,
                  child: Text(school.name),
                ),
            ],
            onChanged: (value) {
              ref.read(adminSelectedSchoolIdProvider.notifier).state = value;
            },
          ),
        ),
        const SizedBox(height: 18),
        users.when(
          loading: () => const LoadingIndicator(message: 'Loading users…'),
          error: (error, _) => ErrorDisplay(
            message: 'Users could not be loaded.',
            error: error,
            onRetry: () => ref.invalidate(adminUsersProvider),
          ),
          data: (page) {
            if (page.users.isEmpty) {
              return const EmptyPanel(
                icon: Icons.people_rounded,
                title: 'No users match',
                body: 'Try another search or filter.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${page.total} account${page.total == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 10),
                for (final user in page.users) ...[
                  _UserTile(
                    user: user,
                    onOpen: () => context.go(
                      AppRoutes.adminUserPerformance(user.userId),
                    ),
                    onToggleActive: () => _toggleActive(user),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _UserTile extends StatelessWidget {
  final AdminUserSummary user;
  final VoidCallback onOpen;
  final VoidCallback onToggleActive;

  const _UserTile({
    required this.user,
    required this.onOpen,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final schoolLine = user.schools.isEmpty
        ? 'No school'
        : user.schools.map((s) => s.name).join(', ');
    return GlassCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Text(user.avatarEmoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(user.displayName, style: text.titleSmall),
                    ),
                    if (!user.active)
                      const Pill(
                        label: 'Inactive',
                        color: AppColors.cinnabar,
                      ),
                  ],
                ),
                Text(
                  '${user.role ?? 'unknown'} · ${user.email ?? 'no email'}',
                  style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                ),
                Text(
                  '$schoolLine · ${user.lessonsCompleted} lessons · ${user.xp} XP',
                  style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: user.active ? 'Deactivate' : 'Reactivate',
            onPressed: onToggleActive,
            icon: Icon(
              user.active
                  ? Icons.person_off_outlined
                  : Icons.person_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

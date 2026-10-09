import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../data/auth_state.dart';
import '../../theme/app_colors.dart';
import '../../models/user_preferences.dart';
import '../../router/navigation.dart';
import '../../services/supabase_service.dart';
import '../teacher/school_home.dart';
import '../../widgets/class_board_card.dart';
import '../../widgets/common.dart';
import '../../widgets/error_boundary.dart';
import '../../widgets/surfaces.dart';
import 'join_class.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final text = Theme.of(context).textTheme;
    final displayName = auth.displayName.isNotEmpty
        ? auth.displayName
        : 'Mandarin learner';
    final avatar = auth.avatarEmoji.isNotEmpty ? auth.avatarEmoji : '🦊';
    final school = ref.watch(schoolOverviewProvider).asData?.value;
    final placedClass = school?.classes.firstOrNull;
    final schoolLine = school == null || !school.hasSchool
        ? 'Kidversity learner'
        : placedClass == null
        ? '${school.schoolName} · waiting for a class'
        : '${school.schoolName} · ${placedClass.name}';

    Future<void> deleteAccount() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete account?'),
          content: const Text(
            'This permanently removes your account, class membership, and '
            'learning progress. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete permanently'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final response = await SupabaseService.instance.client.functions.invoke(
        'delete-account',
        body: {'confirmation': 'DELETE'},
      );
      if (!context.mounted) return;
      if (response.status >= 400) {
        context.showErrorSnackbar('Your account could not be deleted.');
        return;
      }
      await ref.read(authControllerProvider).signOut();
      if (context.mounted) context.go('/');
    }

    return ShellScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
        const PageIntro(
          eyebrow: 'Me',
          title: 'Your place at school',
          body: 'Class, progress, and how Kidversity feels to use.',
        ),
        const SizedBox(height: 18),
        GlassCard(
          gradient: AppColors.brandGradient,
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: EmojiText(avatar, size: 44),
              ),
              const SizedBox(height: 12),
              Text(
                displayName,
                style: text.headlineSmall?.copyWith(color: Colors.white),
              ),
                Text(
                schoolLine,
                style: text.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const _FoundationProfileProgress(),
        const SizedBox(height: 12),
        GlassCard(
          child: Row(
            children: [
              const SoftIcon(icon: Icons.insights_rounded, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Progress report', style: text.titleMedium),
                    Text(
                      'Mandarin, exams, and maths in one page. Print it or save a PDF for home.',
                      style: text.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => context.push(AppRoutes.studentReport),
                child: const Text('Open'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const SchoolStudentRank(),
        const _ClassBoardSection(),
        const SizedBox(height: 22),
        const _ClassMembershipCard(),
        const SizedBox(height: 22),
        const SectionHeader(title: 'Settings'),
        const _SettingsSection(),
        const SizedBox(height: 22),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton(
              onPressed: () => context.push('/privacy'),
              child: const Text('Privacy'),
            ),
            TextButton(
              onPressed: () => context.push('/terms'),
              child: const Text('Terms'),
            ),
            TextButton(
              onPressed: () => context.push('/guardian-consent'),
              child: const Text('Guardian consent'),
            ),
            TextButton(
              onPressed: deleteAccount,
              child: const Text('Delete my account'),
            ),
          ],
        ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ClassMembershipCard extends ConsumerWidget {
  const _ClassMembershipCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final school = ref.watch(schoolOverviewProvider).asData?.value;
    if (school != null && school.hasSchool) {
      final placed = school.classes.firstOrNull;
      if (placed != null) return const SizedBox.shrink();
      final text = Theme.of(context).textTheme;
      return GlassCard(
        child: Row(
          children: [
            const SoftIcon(icon: Icons.hourglass_top_rounded, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Waiting for a class', style: text.titleMedium),
                  Text(
                    '${school.schoolName} will place you. You do not need a class code.',
                    style: text.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return const JoinClassCard();
  }
}

class _FoundationProfileProgress extends ConsumerWidget {
  const _FoundationProfileProgress();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completed =
        ref
            .watch(foundationCompletedLessonIdsProvider)
            .whenOrNull(data: (value) => value.length) ??
        0;
    final total =
        ref.watch(mandarinCourseProvider).whenOrNull(
          data: (course) => course.lessons.length,
        ) ??
        30;
    final safeTotal = total == 0 ? 1 : total;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Foundation progress',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text('$completed of $total lessons complete'),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (completed / safeTotal).clamp(0, 1),
              minHeight: 9,
              backgroundColor: AppColors.backgroundAlt,
              color: AppColors.jade,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassBoardSection extends ConsumerWidget {
  const _ClassBoardSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(classBoardProvider);
    final prefs =
        ref.watch(userPreferencesProvider).whenOrNull(data: (d) => d) ??
        const UserPreferences();

    Future<void> setOptIn(bool value) async {
      await SupabaseService.instance.saveUserPreferences(
        prefs.copyWith(classLeaderboard: value),
      );
      ref.invalidate(userPreferencesProvider);
      ref.invalidate(classBoardProvider);
    }

    return board.when(
      loading: () => const GlassCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: LoadingIndicator(message: 'Opening the class board…'),
        ),
      ),
      error: (_, _) => GlassCard(
        child: ErrorDisplay(
          message: 'The class board could not be loaded.',
          onRetry: () => ref.invalidate(classBoardProvider),
        ),
      ),
      data: (snap) => ClassBoardCard(
        snapshot: snap,
        onOptInChanged: setOptIn,
      ),
    );
  }
}

class _SettingsSection extends ConsumerWidget {
  const _SettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs =
        ref.watch(userPreferencesProvider).whenOrNull(data: (d) => d) ??
        const UserPreferences();

    Future<void> update(UserPreferences next) async {
      await SupabaseService.instance.saveUserPreferences(next);
      ref.invalidate(userPreferencesProvider);
      ref.invalidate(classBoardProvider);
    }

    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          _SettingRow(
            icon: Icons.text_fields_rounded,
            label: 'Dyslexia-friendly text',
            trailing: Switch(
              value: prefs.dyslexiaFriendly,
              activeThumbColor: AppColors.primary,
              onChanged: (v) => update(prefs.copyWith(dyslexiaFriendly: v)),
            ),
          ),
          const Divider(indent: 16, endIndent: 16, height: 1),
          _SettingRow(
            icon: Icons.closed_caption_rounded,
            label: 'Always show captions',
            trailing: Switch(
              value: prefs.showCaptions,
              activeThumbColor: AppColors.primary,
              onChanged: (v) => update(prefs.copyWith(showCaptions: v)),
            ),
          ),
          const Divider(indent: 16, endIndent: 16, height: 1),
          _SettingRow(
            icon: Icons.groups_rounded,
            label: 'Show me on the class board',
            trailing: Switch(
              value: prefs.classLeaderboard,
              activeThumbColor: AppColors.primary,
              onChanged: (v) => update(prefs.copyWith(classLeaderboard: v)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget trailing;
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SoftIcon(icon: icon, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontSize: 15),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

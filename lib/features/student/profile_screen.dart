import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../data/auth_state.dart';
import '../../theme/app_colors.dart';
import '../../models/user_preferences.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common.dart';
import '../../widgets/error_boundary.dart';
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
      children: [
        Text('My profile', style: text.headlineSmall),
        const SizedBox(height: 8),
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
                'Mandarin Foundation learner',
                style: text.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const _FoundationProfileProgress(),
        const SizedBox(height: 22),
        const JoinClassCard(),
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
    );
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
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Foundation progress',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text('$completed of 30 lessons complete'),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: completed / 30,
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

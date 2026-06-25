import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../data/auth_state.dart';
import '../../router/navigation.dart';
import '../../theme/app_colors.dart';
import '../../models/user_preferences.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common.dart';
import '../../widgets/progress_ring.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learner = ref.watch(learnerProvider);
    final auth = ref.watch(authControllerProvider);
    final text = Theme.of(context).textTheme;
    final displayName = auth.displayName.isNotEmpty ? auth.displayName : learner.name;
    final avatar = auth.avatarEmoji.isNotEmpty ? auth.avatarEmoji : learner.avatarEmoji;

    return ShellScrollView(
      children: [
            Row(
              children: [
                Text('My profile', style: text.headlineSmall),
                const Spacer(),
                IconButton(
                  onPressed: () async {
                    ref.read(roleProvider.notifier).state = null;
                    await ref.read(authControllerProvider).signOut();
                    if (context.mounted) context.go(AppRoutes.home);
                  },
                  icon: const Icon(Icons.logout_rounded),
                  tooltip: 'Sign out',
                ),
              ],
            ),
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
                    child: Text(avatar, style: const TextStyle(fontSize: 44)),
                  ),
                  const SizedBox(height: 12),
                  Text(displayName, style: text.headlineSmall?.copyWith(color: Colors.white)),
                  Text('Level ${learner.level} Explorer',
                      style: text.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatColumn(value: '${learner.xp}', label: 'Total XP'),
                      _divider(),
                      _StatColumn(value: '${learner.lessonsCompleted}', label: 'Lessons'),
                      _divider(),
                      _StatColumn(value: '${learner.streakDays}', label: 'Streak'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SectionHeader(title: 'Skills mastered'),
            _SkillsSection(),
            const SizedBox(height: 22),
            const SectionHeader(title: 'Settings'),
            const _SettingsSection(),
          ],
    );
  }

  Widget _divider() => Container(width: 1, height: 34, color: Colors.white.withValues(alpha: 0.25));
}

class _SkillsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skills = ref.watch(subjectSkillsProvider).whenOrNull(data: (d) => d) ?? const [];
    if (skills.isEmpty) {
      return GlassCard(child: Text('Complete lessons to build your skills map.', style: Theme.of(context).textTheme.bodyLarge));
    }
    final colors = [AppColors.secondary, AppColors.primary, AppColors.accentTeal, AppColors.accentPink];
    return GlassCard(
      child: Column(
        children: [
          for (int i = 0; i < skills.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _SkillRow(skill: skills[i].subject, value: skills[i].mastery, color: colors[i % colors.length]),
          ],
        ],
      ),
    );
  }
}

class _SettingsSection extends ConsumerWidget {
  const _SettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(userPreferencesProvider).whenOrNull(data: (d) => d) ?? const UserPreferences();

    Future<void> update(UserPreferences next) async {
      await SupabaseService.instance.saveUserPreferences(next);
      ref.invalidate(userPreferencesProvider);
      ref.invalidate(catalogProvider);
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
            icon: Icons.leaderboard_rounded,
            label: 'Join class leaderboard',
            trailing: Switch(
              value: prefs.joinLeaderboard,
              activeThumbColor: AppColors.primary,
              onChanged: (v) => update(prefs.copyWith(joinLeaderboard: v)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String value, label;
  const _StatColumn({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(value, style: text.headlineSmall?.copyWith(color: Colors.white)),
        Text(label, style: text.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
      ],
    );
  }
}

class _SkillRow extends StatelessWidget {
  final String skill;
  final double value;
  final Color color;
  const _SkillRow({required this.skill, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ProgressRing(progress: value, size: 46, stroke: 6, color: color),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(skill, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 7,
                  backgroundColor: AppColors.line,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget trailing;
  const _SettingRow({required this.icon, required this.label, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SoftIcon(icon: icon, size: 38),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15))),
          trailing,
        ],
      ),
    );
  }
}


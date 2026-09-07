import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_state.dart';
import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/error_boundary.dart';

class StudentsScreen extends ConsumerWidget {
  const StudentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rosterAsync = ref.watch(rosterProvider);
    final roster =
        rosterAsync.whenOrNull(data: (d) => d) ?? const <StudentPerformance>[];
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
      children: [
        Text('My class', style: text.headlineSmall),
        Text(
          'Manage your class code and learner roster.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: 18),
        const _InviteCard(),
        const SizedBox(height: 22),
        const SectionHeader(title: 'Students'),
        if (rosterAsync.isLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (rosterAsync.hasError)
          ErrorDisplay(
            message: 'Your class could not be loaded.',
            onRetry: () => ref.invalidate(rosterProvider),
          )
        else if (roster.isEmpty)
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No students in your class yet.', style: text.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Share the class code above. When students enter it from their Profile → “Join your class”, '
                  'they’ll appear here automatically.',
                  style: text.bodyMedium?.copyWith(
                    fontSize: 13,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          )
        else
          for (final s in roster) ...[
            _StudentCard(student: s),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _InviteCard extends ConsumerWidget {
  const _InviteCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final infoAsync = ref.watch(teacherClassInfoProvider);
    final info = infoAsync.whenOrNull(data: (d) => d);
    final code = info?.code ?? '';

    Future<void> regenerate() async {
      if (info == null) return;
      final result = await SupabaseService.instance.regenerateClassCode(
        info.id,
      );
      if (!context.mounted) return;
      if (result.isSuccess) {
        ref.invalidate(teacherClassInfoProvider);
        context.showSuccessSnackbar('New class code generated.');
      } else {
        context.showErrorSnackbar(result.error ?? 'Could not regenerate code.');
      }
    }

    return GlassCard(
      gradient: AppColors.brandGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎟️', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Invite students',
                  style: text.titleLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Share this code — students tap “Join your class” in their Profile to enrol.',
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
                  child: infoAsync.isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          code.isEmpty ? '——————' : code,
                          style: text.headlineSmall?.copyWith(
                            color: Colors.white,
                            letterSpacing: 8,
                            fontSize: 28,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              _IconAction(
                icon: Icons.copy_rounded,
                tooltip: 'Copy code',
                onTap: code.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: code));
                        if (context.mounted) {
                          context.showSuccessSnackbar('Code copied!');
                        }
                      },
              ),
              const SizedBox(width: 8),
              _IconAction(
                icon: Icons.refresh_rounded,
                tooltip: 'New code',
                onTap: info == null ? null : regenerate,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  const _IconAction({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final StudentPerformance student;
  const _StudentCard({required this.student});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              student.avatarEmoji,
              style: const TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              student.name,
              style: text.titleMedium?.copyWith(fontSize: 16),
            ),
          ),
          const Icon(Icons.check_circle_outline_rounded, color: AppColors.jade),
        ],
      ),
    );
  }
}

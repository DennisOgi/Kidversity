import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../data/auth_state.dart';
import '../../data/mock_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/lesson_card.dart';
import '../../widgets/live_test_widgets.dart';
import '../../services/supabase_service.dart';

class TeacherHome extends ConsumerWidget {
  const TeacherHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacherLessons = ref.watch(teacherLessonsProvider);
    final metrics = ref.watch(teacherMetricsProvider);
    final roster = ref.watch(rosterProvider);
    final auth = ref.watch(authControllerProvider);
    final teacherName =
        auth.displayName.isNotEmpty ? auth.displayName : MockData.teacherName;
    final text = Theme.of(context).textTheme;

    final lessonList = teacherLessons.whenOrNull(data: (d) => d) ?? [];
    final m = metrics.whenOrNull(data: (d) => d);
    final students = roster.whenOrNull(data: (d) => d) ?? [];
    final insight = students.isNotEmpty
        ? '${students.first.name} is at ${(students.first.overallMastery * 100).round()}% mastery — keep the momentum going!'
        : 'Add students to your class to see insights here.';
    final weekly = students.isNotEmpty ? students.first.weeklyActivity : const [0.5, 0.7, 0.6, 0.9, 0.8, 0.4, 0.85];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
      children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome back,', style: text.bodyMedium),
                    Text(teacherName, style: text.headlineSmall),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: () async {
                    ref.read(roleProvider.notifier).state = null;
                    await ref.read(authControllerProvider).signOut();
                    if (context.mounted) context.go('/');
                  },
                  icon: const Icon(Icons.logout_rounded),
                  style: IconButton.styleFrom(backgroundColor: AppColors.surface),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _CreateCallout(),
            const SizedBox(height: 14),
            const _LiveQuizCallout(),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(child: _MetricTile(icon: Icons.groups_rounded, value: '${m?.studentCount ?? '—'}', label: 'Students', color: AppColors.primary)),
                const SizedBox(width: 12),
                Expanded(child: _MetricTile(icon: Icons.library_books_rounded, value: '${m?.lessonCount ?? '—'}', label: 'Lessons', color: AppColors.accentTeal)),
                const SizedBox(width: 12),
                Expanded(child: _MetricTile(icon: Icons.task_alt_rounded, value: m != null ? '${(m.avgMastery * 100).round()}%' : '—', label: 'Avg. score', color: AppColors.secondary)),
              ],
            ),
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Your lessons',
              subtitle: 'Uploaded & AI-generated',
              action: TextButton(onPressed: () => context.go('/teacher/create'), child: const Text('+ New')),
            ),
            if (lessonList.isEmpty)
              GlassCard(
                child: Text('No lessons yet — create your first one!', style: text.bodyLarge),
              )
            else
              for (final lesson in lessonList.take(5)) ...[
                _TeacherLessonRow(
                  lessonId: lesson.id,
                  title: lesson.title,
                  subject: lesson.subject,
                  emoji: lesson.emoji,
                  color: lesson.color,
                  source: sourceLabel(lesson.source),
                  sourceIcon: sourceIcon(lesson.source),
                  status: lesson.status.name,
                ),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 12),
            const SectionHeader(title: 'Class snapshot'),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 26)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(insight, style: text.titleMedium?.copyWith(fontSize: 15)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  MiniBarChart(values: weekly, color: AppColors.primary),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final d in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                        Text(d, style: text.bodyMedium?.copyWith(fontSize: 11, color: AppColors.muted)),
                    ],
                  ),
                ],
              ),
            ),
          ],
    );
  }
}

class _LiveQuizCallout extends StatelessWidget {
  const _LiveQuizCallout();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      gradient: LinearGradient(
        colors: [AppColors.danger.withValues(alpha: 0.92), AppColors.secondary],
      ),
      padding: const EdgeInsets.all(20),
      shadow: AppTheme.softShadow,
      onTap: () => GoRouter.of(context).go('/teacher/live'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const LivePulseBadge(),
                    const SizedBox(width: 10),
                    Text('Live Quiz', style: text.titleLarge?.copyWith(color: Colors.white, fontSize: 19)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Launch a timed test and watch student answers roll in live.',
                  style: text.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.92), fontSize: 13),
                ),
              ],
            ),
          ),
          const Icon(Icons.bolt_rounded, color: Colors.white, size: 36),
        ],
      ),
    );
  }
}

class _CreateCallout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      gradient: AppColors.brandGradient,
      padding: const EdgeInsets.all(20),
      shadow: AppTheme.softShadow,
      onTap: () => GoRouter.of(context).go('/teacher/create'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Create a lesson', style: text.titleLarge?.copyWith(color: Colors.white, fontSize: 19)),
                const SizedBox(height: 4),
                Text('Upload your PPT/PDF, or type a topic and let AI build slides + audio + a quiz.',
                    style: text.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.92), fontSize: 13)),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  children: const [
                    Pill(label: 'Upload', icon: Icons.upload_file_rounded, color: Colors.white, background: Color(0x33FFFFFF)),
                    Pill(label: 'AI Generate', icon: Icons.auto_awesome_rounded, color: Colors.white, background: Color(0x33FFFFFF)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.add_circle_rounded, color: Colors.white, size: 38),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  const _MetricTile({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      child: Column(
        children: [
          SoftIcon(icon: icon, color: color, size: 40),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}

class _TeacherLessonRow extends ConsumerWidget {
  final String lessonId;
  final String title, subject, emoji, source, status;
  final IconData sourceIcon;
  final Color color;
  const _TeacherLessonRow({
    required this.lessonId,
    required this.title,
    required this.subject,
    required this.emoji,
    required this.source,
    required this.status,
    required this.sourceIcon,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleMedium?.copyWith(fontSize: 15)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(sourceIcon, size: 13, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Text(source, style: text.bodyMedium?.copyWith(fontSize: 12, color: AppColors.muted)),
                    const SizedBox(width: 8),
                    _StatusDot(status: status),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded, color: AppColors.muted),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'assign', child: Text('Assign to class')),
              PopupMenuItem(value: 'edit', child: Text('Edit in Create')),
              PopupMenuItem(value: 'preview', child: Text('Preview as student')),
            ],
            onSelected: (action) async {
              switch (action) {
                case 'assign':
                  final result = await SupabaseService.instance.assignLessonToClass(lessonId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result.isSuccess ? 'Assigned to class!' : (result.error ?? 'Assign failed'))),
                    );
                  }
                  ref.invalidate(teacherLessonsProvider);
                case 'edit':
                  if (context.mounted) context.go('/teacher/create?lessonId=$lessonId');
                case 'preview':
                  if (context.mounted) context.go('/student/lesson/$lessonId');
              }
            },
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final String status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'assigned' => AppColors.success,
      'published' => AppColors.accentBlue,
      _ => AppColors.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
      child: Text(status,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

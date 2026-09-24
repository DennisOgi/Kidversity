import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../models/mandarin_content.dart';
import '../../router/navigation.dart';
import '../../services/foundation_progress_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/empty_panel.dart';
import '../../widgets/error_boundary.dart';

class FoundationProgressScreen extends ConsumerWidget {
  const FoundationProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = ref.watch(mandarinCourseProvider);
    final dashboard = ref.watch(foundationClassDashboardProvider);
    final text = Theme.of(context).textTheme;

    return ShellScrollView(
      children: [
        Text(
          'Learning movement',
          style: text.headlineSmall?.copyWith(fontSize: 26),
        ),
        const SizedBox(height: 6),
        Text(
          'Not just who opened the app — who moved, who struggled, and who needs you.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: 22),
        course.when(
          loading: () => const LoadingIndicator(),
          error: (error, _) => ErrorDisplay(
            message: 'The course could not be loaded.',
            error: error,
          ),
          data: (loadedCourse) => dashboard.when(
            loading: () => const LoadingIndicator(
              message: 'Reading class learning signals…',
            ),
            error: (error, _) => ErrorDisplay(
              message: 'Class progress could not be loaded.',
              error: error,
              onRetry: () {
                ref.invalidate(foundationClassProgressProvider);
                ref.invalidate(foundationClassDashboardProvider);
              },
            ),
            data: (board) => board.students.isEmpty
                ? const _NoStudents()
                : _DashboardBody(dashboard: board, course: loadedCourse),
          ),
        ),
      ],
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final FoundationClassDashboard dashboard;
  final MandarinCourse course;

  const _DashboardBody({required this.dashboard, required this.course});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeroPulse(dashboard: dashboard),
        const SizedBox(height: 18),
        if (dashboard.attentionQueue.isNotEmpty) ...[
          const SectionHeader(
            title: 'Needs your attention',
            subtitle: 'Start here before the next lesson',
          ),
          for (final student in dashboard.attentionQueue.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AttentionCard(student: student),
            ),
          const SizedBox(height: 8),
        ],
        if (dashboard.classHotspots.isNotEmpty) ...[
          const SectionHeader(
            title: 'Class struggle hotspots',
            subtitle: 'Words and skills missed across the class',
          ),
          _HotspotCard(items: dashboard.classHotspots),
          const SizedBox(height: 22),
        ],
        if (dashboard.moversThisWeek.isNotEmpty) ...[
          const SectionHeader(
            title: 'This week’s movers',
            subtitle: 'Learning movement in the last 7 days',
          ),
          _MoversStrip(students: dashboard.moversThisWeek),
          const SizedBox(height: 22),
        ],
        SectionHeader(
          title: 'Every learner',
          subtitle: '${dashboard.learnerCount} on the Foundation path',
        ),
        for (final student in dashboard.students) ...[
          _LearnerCard(student: student, course: course),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _HeroPulse extends StatelessWidget {
  final FoundationClassDashboard dashboard;

  const _HeroPulse({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      gradient: AppColors.brandGradient,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CLASS PULSE',
            style: text.labelLarge?.copyWith(
              color: AppColors.gold,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'What Kidversity knows that a register cannot',
            style: text.titleLarge?.copyWith(color: Colors.white, fontSize: 20),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, box) {
              final narrow = box.maxWidth < 520;
              final tiles = [
                _PulseTile(
                  label: 'Path complete',
                  value: '${(dashboard.averageCompletion * 100).round()}%',
                ),
                _PulseTile(
                  label: 'Avg score',
                  value: '${dashboard.averageScore.round()}%',
                ),
                _PulseTile(
                  label: 'Lessons this week',
                  value: '${dashboard.lessonsThisWeek}',
                ),
                _PulseTile(
                  label: 'Need attention',
                  value: '${dashboard.attentionQueue.length}',
                ),
              ];
              if (narrow) {
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tile in tiles)
                      SizedBox(
                        width: (box.maxWidth - 8) / 2,
                        child: tile,
                      ),
                  ],
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < tiles.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: tiles[i]),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PulseTile extends StatelessWidget {
  final String label;
  final String value;

  const _PulseTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttentionCard extends StatelessWidget {
  final FoundationStudentProgress student;

  const _AttentionCard({required this.student});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      color: AppColors.cinnabarSoft.withValues(alpha: 0.55),
      border: Border.all(color: AppColors.cinnabar.withValues(alpha: 0.28)),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(student.avatarEmoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(student.name, style: text.titleMedium),
                    ),
                    Pill(
                      label: student.movementLabel.toUpperCase(),
                      color: AppColors.cinnabar,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  student.lastActiveLabel,
                  style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                ),
                const SizedBox(height: 8),
                for (final reason in student.attentionReasons.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  ', style: TextStyle(color: AppColors.cinnabar)),
                        Expanded(
                          child: Text(
                            reason,
                            style: text.bodyMedium?.copyWith(fontSize: 13.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (student.struggles.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final item in student.struggles.take(3))
                        _Chip(
                          label: item.label,
                          tone: AppColors.cinnabar,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HotspotCard extends StatelessWidget {
  final List<StruggleItem> items;

  const _HotspotCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 18),
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.cinnabar.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: text.titleMedium?.copyWith(
                      color: AppColors.cinnabar,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(items[i].label, style: text.titleMedium),
                      Text(
                        items[i].detail,
                        style: text.bodySmall?.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${items[i].missCount}×',
                  style: text.titleMedium?.copyWith(color: AppColors.cinnabar),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MoversStrip extends StatelessWidget {
  final List<FoundationStudentProgress> students;

  const _MoversStrip({required this.students});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: students.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final student = students[index];
          return Container(
            width: 148,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.successSoft.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.jade.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.avatarEmoji, style: const TextStyle(fontSize: 22)),
                const Spacer(),
                Text(
                  student.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 14,
                  ),
                ),
                Text(
                  '+${student.lessonsThisWeek} lesson${student.lessonsThisWeek == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.jade,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LearnerCard extends StatelessWidget {
  final FoundationStudentProgress student;
  final MandarinCourse course;

  const _LearnerCard({required this.student, required this.course});

  Color get _movementColor => switch (student.movement) {
    LearningMovement.rising => AppColors.jade,
    LearningMovement.steady => AppColors.accentBlue,
    LearningMovement.quiet => AppColors.muted,
    LearningMovement.struggling => AppColors.cinnabar,
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final completed = student.completedCount;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  student.avatarEmoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.name, style: text.titleLarge?.copyWith(fontSize: 18)),
                    Text(
                      '$completed/30 lessons · ${student.averageScore.round()}% avg · ${student.lastActiveLabel}',
                      style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${student.pathPercent}%',
                    style: text.titleLarge?.copyWith(
                      color: AppColors.cinnabar,
                      fontSize: 20,
                    ),
                  ),
                  Pill(label: student.movementLabel, color: _movementColor),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: completed / 30,
              minHeight: 9,
              backgroundColor: AppColors.backgroundAlt,
              color: AppColors.jade,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final module in course.modules)
                _Chip(
                  label:
                      '${module.title.split(' ').first}: '
                      '${module.lessons.where((l) => student.completedLessonIds.contains(l.id)).length}'
                      '/${module.lessons.length}',
                  tone: AppColors.inkSoft,
                ),
              if (student.lessonsThisWeek > 0)
                _Chip(
                  label: '+${student.lessonsThisWeek} this week',
                  tone: AppColors.jade,
                ),
            ],
          ),
          if (student.strengths.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Doing well',
              style: text.labelLarge?.copyWith(
                color: AppColors.jade,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final strength in student.strengths)
                  _Chip(label: strength, tone: AppColors.jade),
              ],
            ),
          ],
          if (student.struggles.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Needs revisit',
              style: text.labelLarge?.copyWith(
                color: AppColors.cinnabar,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            for (final item in student.struggles.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.label}  ·  ${item.detail}',
                        style: text.bodyMedium?.copyWith(fontSize: 13),
                      ),
                    ),
                    Text(
                      '${item.missCount}×',
                      style: text.labelLarge?.copyWith(
                        color: AppColors.cinnabar,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final lesson in course.lessons)
                Tooltip(
                  message:
                      '${lesson.sequence}. ${lesson.title}'
                      '${student.scoresByLesson[lesson.id] == null ? '' : ' · ${student.scoresByLesson[lesson.id]}%'}',
                  child: _LessonCell(
                    sequence: lesson.sequence,
                    score: student.scoresByLesson[lesson.id],
                    done: student.completedLessonIds.contains(lesson.id),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LessonCell extends StatelessWidget {
  final int sequence;
  final int? score;
  final bool done;

  const _LessonCell({
    required this.sequence,
    required this.score,
    required this.done,
  });

  Color get _fill {
    if (!done) return AppColors.backgroundAlt;
    final value = score ?? 100;
    if (value >= 80) return AppColors.jade;
    if (value >= 60) return AppColors.gold;
    return AppColors.cinnabar;
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 400;
    return Container(
      width: narrow ? 26 : 30,
      height: narrow ? 26 : 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _fill,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(
        '$sequence',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: done ? Colors.white : AppColors.muted,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color tone;

  const _Chip({required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: tone,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _NoStudents extends StatelessWidget {
  const _NoStudents();

  @override
  Widget build(BuildContext context) {
    return EmptyPanel(
      icon: Icons.insights_rounded,
      color: AppColors.worldLanguage,
      title: 'No movement to read yet',
      body:
          'Share the class code, then this page shows who is moving through Mandarin, who is stuck, and who needs you.',
      actionLabel: 'Open Class',
      onAction: () => context.go(AppRoutes.teacherHome),
    );
  }
}

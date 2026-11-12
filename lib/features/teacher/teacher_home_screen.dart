import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/app_state.dart';
import '../../data/auth_state.dart';
import '../../data/records_providers.dart';
import '../../models/learning_records_models.dart';
import '../../router/navigation.dart';
import '../../services/foundation_progress_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/role_style.dart';
import '../../widgets/common.dart';
import '../../widgets/error_boundary.dart';
import '../../widgets/kv_ui.dart';

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// A teacher's day at a glance: who needs them, what work is open, and how
/// the class is moving.
class TeacherHomeScreen extends ConsumerWidget {
  const TeacherHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(teacherClassInfoProvider);
    final dashboard = ref.watch(foundationClassDashboardProvider).asData?.value;
    final assignments =
        ref.watch(classAssignmentsProvider).asData?.value ??
        const <AssignmentProgress>[];

    Future<void> refresh() async {
      ref.invalidate(teacherClassInfoProvider);
      ref.invalidate(foundationClassProgressProvider);
      ref.invalidate(classAssignmentsProvider);
      try {
        await ref.read(teacherClassInfoProvider.future);
      } catch (_) {}
    }

    final classInfo = info.asData?.value;
    if (info.isLoading && classInfo == null) {
      return const KvPage(
        children: [LoadingIndicator(message: 'Opening your class…')],
      );
    }

    return KvPage(
      onRefresh: refresh,
      children: [
        _TeacherHero(
          className: classInfo?.name,
          attention: dashboard?.attentionQueue.length ?? 0,
          openWork: assignments.where(_isOpen).length,
        ),
        if (classInfo == null)
          const _NoClassYet()
        else ...[
          _ClassStrip(name: classInfo.name, code: classInfo.code),
          _Metrics(dashboard: dashboard, assignments: assignments),
          AdaptiveRow(
            flex: const [13, 10],
            breakpoint: 940,
            children: [
              _NeedsAttention(dashboard: dashboard),
              _OpenAssignments(assignments: assignments),
            ],
          ),
          _ClassGlance(dashboard: dashboard),
          if (dashboard != null && dashboard.classHotspots.isNotEmpty)
            _Hotspots(dashboard: dashboard),
        ],
      ],
    );
  }
}

bool _isOpen(AssignmentProgress p) {
  final due = p.assignment.dueAt;
  final pastDue =
      due != null && DateTime.now().isAfter(due.add(const Duration(days: 1)));
  return !pastDue && p.doneCount < p.students.length;
}

class _TeacherHero extends ConsumerWidget {
  final String? className;
  final int attention;
  final int openWork;

  const _TeacherHero({
    required this.className,
    required this.attention,
    required this.openWork,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final name = ref.watch(authControllerProvider).displayName.trim();
    final date =
        '${_weekdays[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]}';
    final parts = <String>[
      if (attention > 0)
        '$attention learner${attention == 1 ? '' : 's'} need${attention == 1 ? 's' : ''} you',
      if (openWork > 0)
        '$openWork assignment${openWork == 1 ? ' is' : 's are'} open',
    ];
    final summary = className == null
        ? 'Create your class and share the code to get started.'
        : parts.isEmpty
        ? '$className is all caught up. Set something new when you are ready.'
        : '$className: ${parts.join(' and ')}.';

    return HeroBanner(
      colors: HeroColors.teacher,
      eyebrow: date,
      title: name.isEmpty
          ? timeGreeting()
          : '${timeGreeting()}, ${name.split(' ').first}',
      body: summary,
      actions: [
        SunButton(
          label: 'New assignment',
          icon: Icons.add_rounded,
          onPressed: () => context.go(AppRoutes.teacherAssign),
        ),
        HeroGhostButton(
          label: 'Start live quiz',
          icon: Icons.bolt_rounded,
          onPressed: () => context.go(AppRoutes.teacherLiveCompose),
        ),
      ],
    );
  }
}

class _NoClassYet extends StatelessWidget {
  const _NoClassYet();

  @override
  Widget build(BuildContext context) {
    return KvCard(
      tint: AppTint.mint,
      child: Row(
        children: [
          const TintIcon(tint: AppTint.mint, icon: Icons.groups_rounded),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'No class yet. Create one, then share its code so students can join from Me.',
              style: TextStyle(fontSize: 15, color: AppColors.ink),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () => context.go(AppRoutes.teacherHome),
            child: const Text('Set up class'),
          ),
        ],
      ),
    );
  }
}

class _ClassStrip extends StatelessWidget {
  final String name;
  final String code;

  const _ClassStrip({required this.name, required this.code});

  @override
  Widget build(BuildContext context) {
    return KvCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Wrap(
        spacing: 16,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusChip(label: name, tint: AppTint.mint),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () => context.go(AppRoutes.teacherHome),
                child: const Text('Manage class'),
              ),
            ],
          ),
          if (code.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Join code',
                  style: TextStyle(fontSize: 14, color: AppColors.inkSoft),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTint.sun.soft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SelectableText(
                    code,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Copy join code',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (context.mounted) {
                      context.showSuccessSnackbar('Join code copied.');
                    }
                  },
                  icon: const Icon(Icons.copy_rounded),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  final FoundationClassDashboard? dashboard;
  final List<AssignmentProgress> assignments;

  const _Metrics({required this.dashboard, required this.assignments});

  @override
  Widget build(BuildContext context) {
    final d = dashboard;
    final learners = d?.learnerCount ?? 0;
    final active = d?.students.where((s) => s.lessonsThisWeek > 0).length ?? 0;
    final attention = d?.attentionQueue.length ?? 0;
    final open = assignments.where(_isOpen).toList();
    final submitted = open.fold<int>(0, (s, p) => s + p.doneCount);
    final expected = open.fold<int>(0, (s, p) => s + p.students.length);

    return AdaptiveGrid(
      minTileWidth: 150,
      children: [
        MetricTile(
          tint: AppTint.mint,
          icon: Icons.groups_rounded,
          label: 'Learners',
          value: '$learners',
          caption: learners == 0 ? 'Share the join code' : 'In this class',
        ),
        MetricTile(
          tint: AppTint.sun,
          icon: Icons.trending_up_rounded,
          label: 'Learned this week',
          value: learners == 0 ? '–' : '$active / $learners',
          caption: 'Finished a Mandarin lesson',
        ),
        MetricTile(
          tint: AppTint.violet,
          icon: Icons.assignment_rounded,
          label: 'Open assignments',
          value: '${open.length}',
          caption: expected == 0
              ? 'Nothing open'
              : '$submitted of $expected handed in',
          onTap: () => context.go(AppRoutes.teacherAssign),
        ),
        MetricTile(
          tint: attention > 0 ? StatusChip.alert : AppTint.sky,
          icon: Icons.flag_rounded,
          label: 'Needs attention',
          value: '$attention',
          caption: attention == 0 ? 'Everyone is moving' : 'See who and why',
          onTap: () => context.go(AppRoutes.teacherProgress),
        ),
      ],
    );
  }
}

StatusChip _movementChip(FoundationStudentProgress s) => switch (s.movement) {
  LearningMovement.rising => const StatusChip(
    label: 'Rising',
    tint: AppTint.mint,
    icon: Icons.north_east_rounded,
  ),
  LearningMovement.steady => const StatusChip(
    label: 'Steady',
    tint: AppTint.sky,
  ),
  LearningMovement.quiet => const StatusChip(label: 'Quiet', tint: AppTint.sun),
  LearningMovement.struggling => const StatusChip(
    label: 'Needs support',
    tint: StatusChip.alert,
    icon: Icons.error_outline_rounded,
  ),
};

class _Avatar extends StatelessWidget {
  final String emoji;
  final AppTint tint;

  const _Avatar({required this.emoji, required this.tint});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tint.soft, shape: BoxShape.circle),
      child: EmojiText(emoji, size: 22),
    );
  }
}

class _NeedsAttention extends StatelessWidget {
  final FoundationClassDashboard? dashboard;

  const _NeedsAttention({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final queue = dashboard?.attentionQueue ?? const [];
    return KvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const KvSectionTitle(
            title: 'Needs attention',
            subtitle: 'Start here before the next lesson.',
          ),
          if (dashboard == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            )
          else if (queue.isEmpty)
            const KvListRow(
              divider: false,
              leading: TintIcon(tint: AppTint.mint, icon: Icons.check_rounded),
              title: 'Nobody is stuck right now',
              detail: 'Learners show up here when they go quiet or miss a lot.',
            )
          else
            for (var i = 0; i < queue.length && i < 5; i++)
              KvListRow(
                divider: i > 0,
                leading: _Avatar(
                  emoji: queue[i].avatarEmoji,
                  tint: queue[i].movement == LearningMovement.struggling
                      ? AppTint.coral
                      : AppTint.sun,
                ),
                title: queue[i].name,
                detail: [
                  if (queue[i].attentionReasons.isNotEmpty)
                    queue[i].attentionReasons.first,
                  queue[i].lastActiveLabel,
                ].join(' · '),
                trailing: [
                  _movementChip(queue[i]),
                  OutlinedButton(
                    onPressed: () =>
                        context.go(AppRoutes.teacherReport(queue[i].userId)),
                    child: const Text('Report'),
                  ),
                ],
              ),
        ],
      ),
    );
  }
}

class _OpenAssignments extends StatelessWidget {
  final List<AssignmentProgress> assignments;

  const _OpenAssignments({required this.assignments});

  @override
  Widget build(BuildContext context) {
    final sorted = [...assignments]
      ..sort((a, b) {
        final ao = _isOpen(a) ? 0 : 1;
        final bo = _isOpen(b) ? 0 : 1;
        if (ao != bo) return ao.compareTo(bo);
        return b.assignment.createdAt.compareTo(a.assignment.createdAt);
      });
    return KvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KvSectionTitle(
            title: 'Assignments',
            subtitle: 'Who has handed in.',
            action: TextButton(
              onPressed: () => context.go(AppRoutes.teacherAssign),
              child: const Text('All'),
            ),
          ),
          if (sorted.isEmpty)
            const KvListRow(
              divider: false,
              leading: TintIcon(
                tint: AppTint.violet,
                icon: Icons.assignment_outlined,
                solid: false,
              ),
              title: 'Nothing set yet',
              detail: 'Set a lesson, a maths level, or past questions.',
            )
          else
            for (var i = 0; i < sorted.length && i < 4; i++)
              _AssignmentProgressRow(progress: sorted[i], first: i == 0),
        ],
      ),
    );
  }
}

class _AssignmentProgressRow extends StatelessWidget {
  final AssignmentProgress progress;
  final bool first;

  const _AssignmentProgressRow({required this.progress, required this.first});

  @override
  Widget build(BuildContext context) {
    final a = progress.assignment;
    final total = progress.students.length;
    final done = progress.doneCount;
    final tint = switch (a.kind) {
      AssignmentKind.exam => AppTint.exams,
      AssignmentKind.lesson => AppTint.mandarin,
      AssignmentKind.maths => AppTint.maths,
    };
    final open = _isOpen(progress);
    final chip = !open
        ? const StatusChip(label: 'Closed', tint: AppTint.mint)
        : dueChip(a.dueAt);
    return Container(
      padding: EdgeInsets.only(top: first ? 4 : 14, bottom: 4),
      decoration: BoxDecoration(
        border: first
            ? null
            : const Border(top: BorderSide(color: Color(0xFFEEEDF5))),
      ),
      margin: EdgeInsets.only(top: first ? 0 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  a.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              if (chip != null) ...[const SizedBox(width: 8), chip],
            ],
          ),
          const SizedBox(height: 8),
          KvBar(value: total == 0 ? 0 : done / total, tint: tint),
          const SizedBox(height: 4),
          Text(
            '$done of $total done · ${a.kind.label}',
            style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _ClassGlance extends StatelessWidget {
  final FoundationClassDashboard? dashboard;

  const _ClassGlance({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final students = [...?dashboard?.students];
    final attentionIds = {
      for (final s
          in dashboard?.attentionQueue ?? const <FoundationStudentProgress>[])
        s.userId,
    };
    students.sort((a, b) {
      final aa = attentionIds.contains(a.userId) ? 0 : 1;
      final bb = attentionIds.contains(b.userId) ? 0 : 1;
      if (aa != bb) return aa.compareTo(bb);
      return a.name.compareTo(b.name);
    });
    final shown = students.take(8).toList();

    return KvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KvSectionTitle(
            title: 'Class at a glance',
            subtitle:
                'Who needs you comes first. Open a learner for their report.',
            action: TextButton(
              onPressed: () => context.go(AppRoutes.teacherProgress),
              child: const Text('Full progress'),
            ),
          ),
          if (dashboard == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            )
          else if (shown.isEmpty)
            const KvListRow(
              divider: false,
              leading: TintIcon(
                tint: AppTint.mint,
                icon: Icons.person_add_alt_1_rounded,
                solid: false,
              ),
              title: 'No learners yet',
              detail: 'Share the join code. Students type it on Me.',
            )
          else
            for (var i = 0; i < shown.length; i++)
              InkWell(
                onTap: () =>
                    context.go(AppRoutes.teacherReport(shown[i].userId)),
                borderRadius: BorderRadius.circular(12),
                child: KvListRow(
                  divider: i > 0,
                  leading: _Avatar(
                    emoji: shown[i].avatarEmoji,
                    tint: AppTint.cycle[i % AppTint.cycle.length],
                  ),
                  title: shown[i].name,
                  detail:
                      'Lesson ${shown[i].completedCount} of 30 · '
                      '${shown[i].averageScore.round()}% average · '
                      '${shown[i].lastActiveLabel}',
                  trailing: [_movementChip(shown[i])],
                ),
              ),
          if (students.length > shown.length)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => context.go(AppRoutes.teacherProgress),
                  child: Text('Show all ${students.length} learners'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Hotspots extends StatelessWidget {
  final FoundationClassDashboard dashboard;

  const _Hotspots({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final items = dashboard.classHotspots.take(4).toList();
    final most = items.fold<int>(
      1,
      (m, i) => i.missCount > m ? i.missCount : m,
    );
    return KvCard(
      tint: AppTint.sun,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const KvSectionTitle(
            title: 'Class struggle spots',
            subtitle: 'Words and skills many learners missed.',
          ),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Text(
                        '${item.missCount} miss${item.missCount == 1 ? '' : 'es'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTint.sun.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (item.detail.isNotEmpty)
                    Text(
                      item.detail,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  const SizedBox(height: 6),
                  KvBar(
                    value: item.missCount / most,
                    tint: AppTint.coral,
                    track: AppColors.surface,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

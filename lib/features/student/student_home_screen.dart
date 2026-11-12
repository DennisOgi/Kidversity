import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/features.dart';
import '../../data/app_state.dart';
import '../../data/auth_state.dart';
import '../../data/records_providers.dart';
import '../../models/learning_records_models.dart';
import '../../models/mandarin_content.dart';
import '../../router/navigation.dart';
import '../../theme/app_colors.dart';
import '../../theme/role_style.dart';
import '../../widgets/dashboard_guide.dart';
import '../../widgets/kv_ui.dart';
import '../../widgets/live_test_widgets.dart';

/// Mental maths has this many levels.
const _mathsLevels = 20;

class StudentHomeScreen extends ConsumerStatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  ConsumerState<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends ConsumerState<StudentHomeScreen> {
  @override
  void initState() {
    super.initState();
    // Maths, exams and Rope Pull award XP without touching the auth
    // controller, so refresh once when home opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(authControllerProvider).reloadProfile());
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(myAssignmentsProvider);
    ref.invalidate(myMistakeGroupsProvider);
    ref.invalidate(myMathsResultsProvider);
    ref.invalidate(myExamAttemptsProvider);
    ref.invalidate(foundationCompletedLessonIdsProvider);
    await ref.read(authControllerProvider).reloadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return KvPage(
      onRefresh: _refresh,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StudentLiveQuizBanner(),
            AdaptiveRow(
              flex: [17, 10],
              breakpoint: 900,
              children: [_NextStepHero(), _ProgressCard()],
            ),
          ],
        ),
        DashboardGuide.student(),
        const _TodayList(),
        const _LearningAreas(),
        const AdaptiveRow(children: [_SchoolCard(), _RopePullCard()]),
      ],
    );
  }
}

/// The next Mandarin lesson, with one clear button.
class _NextStepHero extends ConsumerWidget {
  const _NextStepHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = firstName(ref.watch(authControllerProvider).displayName);
    final greeting = name.isEmpty ? timeGreeting() : '${timeGreeting()}, $name';
    final course = ref.watch(mandarinCourseProvider).asData?.value;
    final completed =
        ref.watch(foundationCompletedLessonIdsProvider).asData?.value ??
        const <String>{};

    final access = ref.watch(paymentAccessProvider).asData?.value;
    // Same rule as the Mandarin path: with payments off every lesson is open.
    bool entitled(int sequence) =>
        !Features.payments ||
        (access?.hasAccess(
              'mandarin',
              sequence,
              completedLessonIds: completed,
            ) ??
            sequence <= 2);

    final lessons = [...?course?.lessons]
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    MandarinCourseLesson? next;
    var lockedByPack = false;
    for (final lesson in lessons) {
      if (completed.contains(lesson.id) || !lesson.isPlayable) continue;
      if (!entitled(lesson.sequence)) {
        lockedByPack = true;
        break;
      }
      if (isFoundationLessonUnlocked(
            lesson,
            completed,
            lessons,
            hasPackAccess: entitled,
          ) &&
          !completed.contains(lesson.id)) {
        next = lesson;
        break;
      }
    }
    final done = lessons.where((l) => completed.contains(l.id)).length;
    final finished =
        lessons.isNotEmpty && next == null && !lockedByPack && done > 0;

    final title = course == null
        ? 'Ready when you are.'
        : lockedByPack
        ? 'Your next lessons are waiting.'
        : finished
        ? 'You finished the Mandarin path!'
        : done == 0
        ? 'Start your first Mandarin lesson.'
        : 'Your next step is ready.';
    final route = next == null
        ? AppRoutes.studentMandarin
        : AppRoutes.mandarinLesson(next.id);

    return HeroBanner(
      colors: HeroColors.student,
      eyebrow: greeting,
      title: title,
      body: lockedByPack
          ? 'Ask a parent to unlock the next pack. Practice and Rope Pull stay open.'
          : finished
          ? 'Keep your words fresh with practice, past questions and Rope Pull.'
          : null,
      actions: [
        SunButton(
          label: next == null
              ? 'Open the Mandarin path'
              : 'Start lesson ${next.sequence}',
          onPressed: () => context.go(route),
        ),
        HeroGhostButton(
          label: 'See the whole path',
          onPressed: () => context.go(AppRoutes.studentMandarin),
        ),
      ],
      child: next == null
          ? null
          : _LessonCard(lesson: next, done: done, total: lessons.length),
    );
  }
}

class _LessonCard extends StatelessWidget {
  final MandarinCourseLesson lesson;
  final int done;
  final int total;

  const _LessonCard({
    required this.lesson,
    required this.done,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    const tint = AppTint.mandarin;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E106E).withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          const TintIcon(tint: tint, glyph: '中', size: 62),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MANDARIN · LESSON ${lesson.sequence} OF $total',
                  style: TextStyle(
                    color: tint.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  lesson.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Semantics(
                  label: '$done of $total lessons done',
                  child: KvBar(
                    value: total == 0 ? 0 : done / total,
                    tint: tint,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$done of $total lessons done',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Level, XP to the next level, streak, lessons and minutes.
/// Level = floor(xp / 500) + 1 on the server.
class _ProgressCard extends ConsumerWidget {
  const _ProgressCard();

  static const xpPerLevel = 500;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final into = auth.xp % xpPerLevel;
    final streak = auth.streakDays;
    const tint = AppTint.sun;

    Widget stat(String label, String value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: tint.ink)),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );

    return KvCard(
      tint: tint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'LEVEL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      '${auth.level}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${auth.xp} XP',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    KvBar(value: into / xpPerLevel, tint: tint),
                    const SizedBox(height: 4),
                    Text(
                      '${xpPerLevel - into} XP to level ${auth.level + 1}',
                      style: TextStyle(fontSize: 13, color: tint.ink),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTint.coral.soft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                TintIcon(
                  tint: streak > 0 ? AppTint.coral : AppTint.slate,
                  icon: Icons.local_fire_department_rounded,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        streak == 0 ? 'No streak yet' : '$streak-day streak',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        streak == 0
                            ? 'Learn today to start one.'
                            : 'Learn today to keep it going.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTint.coral.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              stat('Lessons done', '${auth.lessonsCompleted}'),
              stat('Minutes learned', '${auth.minutesLearned}'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Open teacher work first, then words and questions to review.
class _TodayList extends ConsumerWidget {
  const _TodayList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(myAssignmentsProvider).asData?.value;
    final lessonsDone =
        ref.watch(foundationCompletedLessonIdsProvider).asData?.value ??
        const <String>{};
    final mistakes = ref.watch(myMistakeGroupsProvider).asData?.value;
    final openMistakes = mistakes?.fold<int>(
      0,
      (sum, group) => sum + group.items.length,
    );

    bool done(ClassAssignment a) => a.kind == AssignmentKind.lesson
        ? lessonsDone.contains(a.lessonId)
        : data!.submissions.containsKey(a.id);

    final open =
        [
          for (final a in data?.assignments ?? const <ClassAssignment>[])
            if (!done(a)) a,
        ]..sort(
          (a, b) =>
              (a.dueAt ?? DateTime(9999)).compareTo(b.dueAt ?? DateTime(9999)),
        );

    final rows = <Widget>[
      for (final assignment in open.take(4))
        _AssignmentRow(assignment: assignment),
      if (lessonsDone.isNotEmpty)
        _ActionRow(
          tint: AppTint.violet,
          icon: Icons.replay_rounded,
          title: 'Review your Mandarin words',
          detail: 'Words you missed come back until they stick · about 5 min',
          chip: const StatusChip(label: 'Ready', tint: AppTint.violet),
          action: 'Review',
          onPressed: () => context.go(AppRoutes.studentPractice),
        ),
      if ((openMistakes ?? 0) > 0)
        _ActionRow(
          tint: AppTint.exams,
          icon: Icons.menu_book_rounded,
          title: 'Past questions to try again',
          detail:
              '$openMistakes question${openMistakes == 1 ? '' : 's'} you got wrong',
          chip: null,
          action: 'Try again',
          onPressed: () => context.push(AppRoutes.studentExams),
        ),
    ];

    if (rows.isEmpty) {
      rows.add(
        _ActionRow(
          tint: AppTint.mint,
          icon: Icons.check_rounded,
          title: 'Nothing waiting',
          detail: 'Work from your teacher shows up here. Try a maths level?',
          chip: null,
          action: 'Mental maths',
          onPressed: () => context.go(AppRoutes.studentMaths),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KvSectionTitle(
          title: 'Today',
          subtitle: open.isEmpty
              ? 'A few small things that help most.'
              : '${open.length} from your teacher, then a quick review.',
        ),
        KvCard(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++)
                i == 0 ? _NoDivider(child: rows[i]) : rows[i],
            ],
          ),
        ),
      ],
    );
  }
}

/// Lets the first row in a card skip its top divider.
class _NoDivider extends InheritedWidget {
  const _NoDivider({required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_NoDivider>() != null;

  @override
  bool updateShouldNotify(_NoDivider oldWidget) => false;
}

class _ActionRow extends StatelessWidget {
  final AppTint tint;
  final IconData icon;
  final String title;
  final String detail;
  final Widget? chip;
  final String action;
  final VoidCallback onPressed;
  final bool primary;

  const _ActionRow({
    required this.tint,
    required this.icon,
    required this.title,
    required this.detail,
    required this.chip,
    required this.action,
    required this.onPressed,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return KvListRow(
      divider: !_NoDivider.of(context),
      leading: TintIcon(tint: tint, icon: icon, solid: false),
      title: title,
      detail: detail,
      trailing: [
        ?chip,
        primary
            ? FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
                child: Text(action),
              )
            : OutlinedButton(
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
                child: Text(action),
              ),
      ],
    );
  }
}

class _AssignmentRow extends StatelessWidget {
  final ClassAssignment assignment;

  const _AssignmentRow({required this.assignment});

  void _open(BuildContext context) {
    switch (assignment.kind) {
      case AssignmentKind.exam:
        final config = assignment.examConfig;
        if (config != null) {
          context.push(AppRoutes.studentExamSession, extra: config);
        }
      case AssignmentKind.lesson:
        final id = assignment.lessonId;
        if (id != null) context.go(AppRoutes.mandarinLesson(id));
      case AssignmentKind.maths:
        context.go(
          '${AppRoutes.studentMaths}?level=${assignment.mathsLevel ?? 1}'
          '&assignment=${assignment.id}',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final (tint, icon) = switch (assignment.kind) {
      AssignmentKind.exam => (AppTint.exams, Icons.assignment_outlined),
      AssignmentKind.lesson => (AppTint.mandarin, Icons.translate_rounded),
      AssignmentKind.maths => (AppTint.maths, Icons.calculate_outlined),
    };
    return _ActionRow(
      tint: tint,
      icon: icon,
      title: assignment.title,
      detail: '${assignment.kind.label} · from your teacher',
      chip: dueChip(assignment.dueAt, overdue: assignment.isOverdue),
      action: 'Start',
      primary: true,
      onPressed: () => _open(context),
    );
  }
}

/// One colored card per learning area. Colors match everywhere in the app.
class _LearningAreas extends ConsumerWidget {
  const _LearningAreas();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = ref.watch(mandarinCourseProvider).asData?.value;
    final completed =
        ref.watch(foundationCompletedLessonIdsProvider).asData?.value ??
        const <String>{};
    final total = course?.lessons.length ?? 0;
    final done = course == null
        ? completed.length
        : course.lessons.where((l) => completed.contains(l.id)).length;

    final maths = ref.watch(myMathsResultsProvider).asData?.value ?? const [];
    final bestLevel = maths.fold<int>(
      0,
      (best, r) => r.level > best ? r.level : best,
    );

    final attempts =
        ref.watch(myExamAttemptsProvider).asData?.value ?? const [];
    final answered = attempts.fold<int>(0, (s, a) => s + a.total);
    final correct = attempts.fold<int>(0, (s, a) => s + a.correct);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const KvSectionTitle(
          title: 'Your learning',
          subtitle: 'Every area in one place. Open one to see its full path.',
        ),
        AdaptiveGrid(
          minTileWidth: 150,
          children: [
            _AreaCard(
              tint: AppTint.mandarin,
              glyph: '中',
              title: 'Mandarin',
              detail: total == 0
                  ? 'Foundation path'
                  : '$done of $total lessons',
              progress: total == 0 ? 0 : done / total,
              onTap: () => context.go(AppRoutes.studentMandarin),
            ),
            _AreaCard(
              tint: AppTint.maths,
              glyph: '÷',
              title: 'Mental maths',
              detail: bestLevel == 0
                  ? '$_mathsLevels levels to climb'
                  : 'Up to level $bestLevel of $_mathsLevels',
              progress: bestLevel / _mathsLevels,
              onTap: () => context.go(AppRoutes.studentMaths),
            ),
            _AreaCard(
              tint: AppTint.exams,
              icon: Icons.menu_book_rounded,
              title: 'Past questions',
              detail: answered == 0
                  ? 'BECE, WAEC, NECO, UTME'
                  : '$answered answered · ${percentOf(correct, answered)}% right',
              progress: answered == 0 ? 0 : correct / answered,
              onTap: () => context.push(AppRoutes.studentExams),
            ),
            _AreaCard(
              tint: AppTint.labs,
              icon: Icons.science_rounded,
              title: 'Science labs',
              detail: 'Hands-on experiments',
              onTap: () => context.go(AppRoutes.studentLabs),
            ),
          ],
        ),
      ],
    );
  }
}

class _AreaCard extends StatelessWidget {
  final AppTint tint;
  final String? glyph;
  final IconData? icon;
  final String title;
  final String detail;
  final double? progress;
  final VoidCallback onTap;

  const _AreaCard({
    required this.tint,
    required this.title,
    required this.detail,
    required this.onTap,
    this.glyph,
    this.icon,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return KvCard(
      tint: tint,
      onTap: onTap,
      semanticLabel: 'Open $title. $detail',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TintIcon(tint: tint, glyph: glyph, icon: icon),
              const Spacer(),
              Icon(Icons.arrow_forward_rounded, color: tint.ink, size: 20),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          if (progress != null) ...[
            KvBar(value: progress!, tint: tint),
            const SizedBox(height: 8),
          ],
          Text(
            detail,
            style: const TextStyle(fontSize: 14, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _SchoolCard extends ConsumerWidget {
  const _SchoolCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final school = ref.watch(schoolOverviewProvider).asData?.value;
    final myClass = school?.classes.firstOrNull;
    final hasClass = myClass != null;
    return KvCard(
      tint: AppTint.mint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const TintIcon(tint: AppTint.mint, icon: Icons.school_rounded),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasClass ? myClass.name : 'Join your class',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      hasClass
                          ? (school?.schoolName ?? 'Your class')
                          : 'Your teacher gives you a class code.',
                      style: TextStyle(fontSize: 14, color: AppTint.mint.ink),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            hasClass
                ? 'Work your teacher sets shows up under Today.'
                : 'Type the code on Me to see work from your teacher and play with classmates.',
            style: const TextStyle(fontSize: 14, color: AppColors.inkSoft),
          ),
          if (!hasClass) ...[
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => context.go(AppRoutes.studentProfile),
              style: FilledButton.styleFrom(backgroundColor: AppTint.mint.ink),
              child: const Text('Enter a class code'),
            ),
          ],
        ],
      ),
    );
  }
}

class _RopePullCard extends StatelessWidget {
  const _RopePullCard();

  @override
  Widget build(BuildContext context) {
    const tint = AppTint.pink;
    return KvCard(
      tint: tint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const TintIcon(tint: tint, icon: Icons.sports_esports_rounded),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rope Pull',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      'Answer fast, pull the rope, win for your team.',
                      style: TextStyle(fontSize: 14, color: tint.ink),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton(
                onPressed: () => context.go(AppRoutes.studentPlay),
                style: FilledButton.styleFrom(backgroundColor: tint.ink),
                child: const Text('Play now'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_state.dart';
import '../../data/records_providers.dart';
import '../../models/learning_records_models.dart';
import '../../router/navigation.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/error_boundary.dart';
import '../student/maths_bank.dart';
import 'report_content.dart';
import 'report_open_stub.dart'
    if (dart.library.js_interop) 'report_open_web.dart';

class ProgressReportScreen extends ConsumerWidget {
  /// Null shows the signed-in student's own report.
  final String? studentId;
  final String backRoute;

  const ProgressReportScreen({
    super.key,
    this.studentId,
    required this.backRoute,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(progressReportProvider(studentId));
    final lessonTitles =
        ref.watch(mandarinCourseProvider).whenOrNull(
          data: (course) => {
            for (final lesson in course.lessons)
              lesson.id: 'Lesson ${lesson.sequence}: ${lesson.title}',
          },
        ) ??
        const <String, String>{};

    void print(ProgressReport value) {
      final html = reportHtml(value, lessonTitles: lessonTitles);
      if (kIsWeb && openHtmlDocument(html)) return;
      context.showErrorSnackbar('Printing is available in the web app.');
    }

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => popOrGo(context, backRoute),
        ),
        title: const Text('Progress report'),
        actions: [
          if (report.hasValue)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: () => print(report.requireValue),
                icon: const Icon(Icons.print_outlined, size: 18),
                label: const Text('Print or PDF'),
              ),
            ),
        ],
      ),
      body: report.when(
        loading: () => const Center(
          child: LoadingIndicator(message: 'Gathering lessons and scores…'),
        ),
        error: (error, _) => Center(
          child: ErrorDisplay(
            message: 'The report could not be built.',
            error: error,
            onRetry: () => ref.invalidate(progressReportProvider(studentId)),
          ),
        ),
        data: (value) => _ReportBody(report: value, lessonTitles: lessonTitles),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  final ProgressReport report;
  final Map<String, String> lessonTitles;

  const _ReportBody({required this.report, required this.lessonTitles});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final stats = [
      _Stat(
        'Mandarin',
        '${report.lessonsDone}/$foundationLessonCount',
        report.lessons.isEmpty
            ? 'Not started'
            : 'lessons · avg ${report.lessonAverage}%',
        AppColors.worldLanguage,
      ),
      _Stat(
        'Exam practice',
        report.attempts.isEmpty ? '—' : '${report.examAverage}%',
        '${report.examQuestions} questions · ${report.examMinutes} min',
        AppColors.worldExams,
      ),
      _Stat(
        'Maths',
        '${report.mathsLevelsPassed.length}/${mathsLevels.length}',
        report.maths.isEmpty
            ? 'Not started'
            : 'levels cleared · avg ${report.mathsAverage}%',
        AppColors.primary,
      ),
      _Stat(
        'This week',
        '${report.activeDaysThisWeek()}',
        'active days',
        AppColors.success,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    EmojiText(report.avatar, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(report.name, style: text.headlineSmall),
                          Text(
                            'Generated ${dateLabel(report.generatedAt)}',
                            style: text.bodyMedium?.copyWith(
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth < 620 ? 2 : 4;
                    final width =
                        (constraints.maxWidth - (columns - 1) * 12) / columns;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final stat in stats)
                          SizedBox(width: width, child: stat),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                _Section(
                  title: 'Suggested next steps',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final step in reportNextSteps(report))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 3),
                                child: Icon(
                                  Icons.arrow_right_alt_rounded,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(step, style: text.bodyLarge),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (report.subjects.isNotEmpty)
                  _Section(
                    title: 'Exam subjects',
                    child: Column(
                      children: [
                        for (final s in report.subjects)
                          _SubjectRow(summary: s),
                      ],
                    ),
                  ),
                if (report.attempts.isNotEmpty)
                  _Section(
                    title: 'Recent exam sessions',
                    child: Column(
                      children: [
                        for (final a in report.attempts.take(10))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(a.headline),
                            subtitle: Text(
                              '${a.modeLabel} · ${dateLabel(a.createdAt)}',
                            ),
                            trailing: Text(
                              '${a.correct}/${a.total} · ${a.percent}%',
                              style: text.titleSmall,
                            ),
                          ),
                      ],
                    ),
                  ),
                if (report.lessons.isNotEmpty)
                  _Section(
                    title: 'Mandarin lessons',
                    child: Column(
                      children: [
                        for (final l in ([...report.lessons]
                              ..sort(
                                (a, b) => b.completedAt.compareTo(a.completedAt),
                              ))
                            .take(10))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(lessonTitles[l.lessonId] ?? l.lessonId),
                            subtitle: Text(dateLabel(l.completedAt)),
                            trailing: Text(
                              '${l.score}%',
                              style: text.titleSmall,
                            ),
                          ),
                      ],
                    ),
                  ),
                _Section(
                  title: 'Maths levels',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final level in mathsLevels)
                        Chip(
                          avatar: Icon(
                            report.mathsLevelsPassed.contains(level.sequence)
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 18,
                            color:
                                report.mathsLevelsPassed.contains(
                                  level.sequence,
                                )
                                ? AppColors.success
                                : AppColors.muted,
                          ),
                          label: Text('${level.sequence}. ${level.title}'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final String detail;
  final Color color;

  const _Stat(this.label, this.value, this.detail, this.color);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: text.labelSmall?.copyWith(
                color: color,
                letterSpacing: 0.7,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(value, style: text.headlineSmall),
            Text(
              detail,
              style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  final SubjectSummary summary;

  const _SubjectRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = summary.averagePercent >= 70
        ? AppColors.success
        : summary.averagePercent >= 50
        ? AppColors.gold
        : AppColors.danger;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(summary.label, style: text.titleSmall)),
              Text(
                'avg ${summary.averagePercent}% · best ${summary.bestPercent}%',
                style: text.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: summary.averagePercent / 100,
              minHeight: 7,
              backgroundColor: AppColors.line,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${summary.attempts} sessions · ${summary.questions} questions',
            style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

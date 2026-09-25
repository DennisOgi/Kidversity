import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/records_providers.dart';
import '../../models/past_questions_models.dart';
import '../../router/navigation.dart';
import '../../services/sdash_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/error_boundary.dart';
import '../../widgets/surfaces.dart';
import 'exam_topics.dart';

final pastQuestionsCatalogProvider =
    FutureProvider.autoDispose<PastQuestionsCatalog>((ref) async {
      final result = await SdashApiService.instance.fetchCatalog();
      if (result.isFailure) {
        throw StateError(result.error ?? 'Could not load exam catalog');
      }
      return result.data!;
    });

class PastQuestionsHubScreen extends ConsumerStatefulWidget {
  const PastQuestionsHubScreen({super.key});

  @override
  ConsumerState<PastQuestionsHubScreen> createState() =>
      _PastQuestionsHubScreenState();
}

class _PastQuestionsHubScreenState
    extends ConsumerState<PastQuestionsHubScreen> {
  PastExamType? _exam;
  PastSubject? _subject;
  int? _year;
  PastPracticeMode _mode = PastPracticeMode.standard;
  final _universityCtrl = TextEditingController();
  String _university = '';
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _universityCtrl.addListener(() {
      final next = _universityCtrl.text.trim();
      if (next == _university || !mounted) return;
      setState(() => _university = next);
    });
  }

  @override
  void dispose() {
    _universityCtrl.dispose();
    super.dispose();
  }

  PastSubject? _pickDefaultSubject(List<PastSubject> subjects) {
    if (subjects.isEmpty) return null;
    for (final slug in const [
      'biology',
      'chemistry',
      'physics',
      'government',
    ]) {
      for (final subject in subjects) {
        if (subject.slug == slug) return subject;
      }
    }
    return subjects.first;
  }

  void _selectExam(PastExamType exam, List<PastSubject> catalogSubjects) {
    final scoped = exam.subjectsFor(catalogSubjects);
    setState(() {
      _exam = exam;
      if (_subject == null || !scoped.any((s) => s.slug == _subject!.slug)) {
        _subject = _pickDefaultSubject(scoped);
      }
    });
  }

  void _ensureDefaults(PastQuestionsCatalog data) {
    PastExamType? exam = _exam;
    if (exam == null && data.exams.isNotEmpty) {
      exam = data.exams.cast<PastExamType?>().firstWhere(
        (item) => item?.slug == 'utme',
        orElse: () => data.exams.first,
      );
    }
    final scoped = exam?.subjectsFor(data.subjects) ?? data.subjects;
    final subject = _subject ?? _pickDefaultSubject(scoped);
    final year = _year ?? (data.years.isEmpty ? null : data.years.first);
    if (exam == _exam && subject == _subject && year == _year) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _exam ??= exam;
        _subject ??= subject;
        _year ??= year;
      });
    });
  }

  Future<void> _start() async {
    final exam = _exam;
    final subject = _subject;
    if (exam == null || subject == null) {
      context.showErrorSnackbar('Pick an exam type and a subject to begin.');
      return;
    }
    setState(() => _starting = true);
    final config = PastQuestionsSessionConfig(
      exam: exam,
      subject: subject,
      year: _year,
      mode: _mode,
      university: _universityCtrl.text.trim().isEmpty
          ? null
          : _universityCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _starting = false);
    unawaited(context.push(AppRoutes.studentExamSession, extra: config));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final catalog = ref.watch(pastQuestionsCatalogProvider);
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Home',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => popOrGo(context, AppRoutes.studentPath),
        ),
        title: const Text('Exam practice'),
      ),
      body: catalog.when(
        loading: () => const Center(
          child: LoadingIndicator(message: 'Opening exam bank…'),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorDisplay(
              message: error.toString().replaceFirst('Bad state: ', ''),
              onRetry: () => ref.invalidate(pastQuestionsCatalogProvider),
            ),
          ),
        ),
        data: (data) {
          _ensureDefaults(data);
          final exam = _exam;
          final showUniversity = exam?.isUniversityFamily ?? false;
          final subjects = exam?.subjectsFor(data.subjects) ?? data.subjects;
          final families = <String, List<PastSubject>>{};
          for (final subject in subjects) {
            families.putIfAbsent(subject.family, () => []).add(subject);
          }
          final recentYears = data.years.take(10).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              const PageIntro(
                eyebrow: 'Exam studio',
                title: 'Pick a paper',
                body:
                    'Choose an exam, a subject, and a year. The session stays on that paper. English and Mathematics are included.',
              ),
              const SizedBox(height: 18),
              Text('Exam', style: text.titleMedium),
              const SizedBox(height: 10),
              _ExamPicker(
                exams: data.exams,
                selected: _exam,
                onSelect: (item) => _selectExam(item, data.subjects),
              ),
              const SizedBox(height: 22),
              LayoutBuilder(
                builder: (context, constraints) {
                  final paper = _PaperBuilder(
                    families: families,
                    selected: _subject,
                    onSelect: (subject) => setState(() => _subject = subject),
                    years: data.years,
                    recentYears: recentYears,
                    year: _year,
                    onYear: (year) => setState(() => _year = year),
                    showUniversity: showUniversity,
                    university: _universityCtrl,
                    mode: _mode,
                    onMode: (mode) => setState(() => _mode = mode),
                  );
                  final summary = _SessionSummary(
                    exam: exam,
                    subject: _subject,
                    year: _year,
                    mode: _mode,
                    starting: _starting,
                    onStart: _starting ? null : _start,
                  );
                  if (constraints.maxWidth < 920) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [paper, const SizedBox(height: 16), summary],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: paper),
                      const SizedBox(width: 18),
                      SizedBox(width: 320, child: summary),
                    ],
                  );
                },
              ),
              if (exam != null &&
                  _subject != null &&
                  topicsForSubject(_subject!.slug).isNotEmpty) ...[
                const SizedBox(height: 32),
                _TopicLadder(
                  exam: exam,
                  subject: _subject!,
                  year: _year,
                  university: _university.isEmpty ? null : _university,
                ),
              ],
              const SizedBox(height: 28),
              const _MistakesSection(),
              const SizedBox(height: 24),
              const _RecentAttempts(),
            ],
          );
        },
      ),
    );
  }
}

class _ExamPicker extends StatelessWidget {
  final List<PastExamType> exams;
  final PastExamType? selected;
  final ValueChanged<PastExamType> onSelect;

  const _ExamPicker({
    required this.exams,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final exam in exams)
              SizedBox(
                width: wide
                    ? (constraints.maxWidth - 40) / 5
                    : (constraints.maxWidth - 10) / 2,
                child: _ExamCard(
                  exam: exam,
                  selected: selected?.slug == exam.slug,
                  onTap: () => onSelect(exam),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ExamCard extends StatelessWidget {
  final PastExamType exam;
  final bool selected;
  final VoidCallback onTap;

  const _ExamCard({
    required this.exam,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return LiftCard(
      onTap: onTap,
      color: selected ? AppColors.primary : AppColors.surface,
      hoverBorder: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exam.shortLabel,
            style: text.titleMedium?.copyWith(
              color: selected ? Colors.white : AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            exam.blurb,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(
              color: selected ? Colors.white70 : AppColors.inkSoft,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaperBuilder extends StatelessWidget {
  final Map<String, List<PastSubject>> families;
  final PastSubject? selected;
  final ValueChanged<PastSubject> onSelect;
  final List<int> years;
  final List<int> recentYears;
  final int? year;
  final ValueChanged<int?> onYear;
  final bool showUniversity;
  final TextEditingController university;
  final PastPracticeMode mode;
  final ValueChanged<PastPracticeMode> onMode;

  const _PaperBuilder({
    required this.families,
    required this.selected,
    required this.onSelect,
    required this.years,
    required this.recentYears,
    required this.year,
    required this.onYear,
    required this.showUniversity,
    required this.university,
    required this.mode,
    required this.onMode,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return LiftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Subject', style: text.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Every subject on the paper is available.',
            style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 14),
          for (final family in families.entries) ...[
            Text(
              family.key,
              style: text.labelLarge?.copyWith(color: AppColors.worldExams),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final subject in family.value)
                  ChoiceChip(
                    label: Text(subject.name),
                    selected: selected?.slug == subject.slug,
                    onSelected: (_) => onSelect(subject),
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected?.slug == subject.slug
                          ? Colors.white
                          : AppColors.ink,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Text('Year', style: text.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Pick any year. The session stays on that year only.',
            style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in recentYears)
                ChoiceChip(
                  label: Text('$item'),
                  selected: year == item,
                  onSelected: (_) => onYear(item),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: year == item ? Colors.white : AppColors.ink,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            // ignore: deprecated_member_use
            value: year != null && years.contains(year) ? year : years.first,
            decoration: const InputDecoration(
              labelText: 'All years',
              filled: true,
              fillColor: AppColors.paper,
            ),
            items: [
              for (final item in years)
                DropdownMenuItem(value: item, child: Text('$item')),
            ],
            onChanged: onYear,
          ),
          if (showUniversity) ...[
            const SizedBox(height: 16),
            Text('University', style: text.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: university,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'e.g. unilag, oau, ui',
                filled: true,
                fillColor: AppColors.paper,
              ),
            ),
          ],
          const SizedBox(height: 22),
          Text('How long', style: text.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final item in PastPracticeMode.values)
                SizedBox(
                  width: 168,
                  child: _ModeCard(
                    mode: item,
                    selected: mode == item,
                    onTap: () => onMode(item),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionSummary extends StatelessWidget {
  final PastExamType? exam;
  final PastSubject? subject;
  final int? year;
  final PastPracticeMode mode;
  final bool starting;
  final VoidCallback? onStart;

  const _SessionSummary({
    required this.exam,
    required this.subject,
    required this.year,
    required this.mode,
    required this.starting,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final paper = [
      exam?.shortLabel,
      subject?.name,
      if (year != null) '$year',
    ].whereType<String>().join(' · ');
    return LiftCard(
      padding: const EdgeInsets.all(22),
      hoverBorder: AppColors.worldExams,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Your paper', color: AppColors.worldExams),
          const SizedBox(height: 8),
          Text(
            paper.isEmpty ? 'Choose an exam and a subject' : paper,
            style: text.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            exam?.blurb ?? 'The session will stay on the paper you pick.',
            style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 16),
          _SummaryRow(label: 'Questions', value: '${mode.limit}'),
          _SummaryRow(label: 'Style', value: mode.title),
          if (mode.timeLimit != null)
            _SummaryRow(
              label: 'Time',
              value: '${mode.timeLimit!.inMinutes} minutes',
            ),
          const SizedBox(height: 18),
          GradientButton(
            label: starting ? 'Loading…' : 'Start practice',
            icon: Icons.play_arrow_rounded,
            expand: true,
            onTap: onStart,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
            ),
          ),
          Expanded(child: Text(value, style: text.titleSmall)),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final PastPracticeMode mode;
  final bool selected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return LiftCard(
      onTap: onTap,
      color: selected ? AppColors.primarySoft : AppColors.paper,
      hoverBorder: AppColors.primary,
      borderColor: selected ? AppColors.primary : AppColors.line,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mode.title,
            style: text.titleSmall?.copyWith(
              color: selected ? AppColors.primary : AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            mode.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _TopicLadder extends ConsumerStatefulWidget {
  final PastExamType exam;
  final PastSubject subject;
  final int? year;
  final String? university;

  const _TopicLadder({
    required this.exam,
    required this.subject,
    required this.year,
    required this.university,
  });

  @override
  ConsumerState<_TopicLadder> createState() => _TopicLadderState();
}

class _TopicLadderState extends ConsumerState<_TopicLadder> {
  List<PastQuestion>? _questions;
  Set<String> _cleared = const {};
  String? _error;
  bool _loading = true;

  String get _signature =>
      '${widget.exam.slug}|${widget.subject.slug}|${widget.year}|${widget.university}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _TopicLadder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ('${oldWidget.exam.slug}|${oldWidget.subject.slug}|${oldWidget.year}|${oldWidget.university}' !=
        _signature) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await SdashApiService.instance.fetchQuestions(
      examSlug: widget.exam.slug,
      subjectSlug: widget.subject.slug,
      limit: 50,
      year: widget.year,
      university: widget.university,
    );
    final cleared = await ExamTopicProgress.load();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _cleared = cleared;
      if (result.isFailure) {
        _questions = null;
        _error = result.error ?? 'Could not load questions for these topics.';
      } else {
        _questions = result.data;
      }
    });
  }

  void _start(ExamTopic topic, List<PastQuestion> questions) {
    unawaited(
      context.push(
        AppRoutes.studentExamSession,
        extra: PastQuestionsSessionConfig(
          exam: widget.exam,
          subject: widget.subject,
          year: widget.year,
          university: widget.university,
          mode: PastPracticeMode.quick,
          preset: questions,
          topicId: topic.id,
          topicTitle: topic.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final topics = topicsForSubject(widget.subject.slug);
    final questions = _questions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageIntro(
          eyebrow: 'Topic ladder',
          title: '${widget.subject.name} topics',
          body:
              'Eight checked questions each, with the worked solution first. A topic clears at 75%.',
        ),
        const SizedBox(height: 12),
        if (_loading)
          const LinearProgressIndicator(minHeight: 3)
        else if (_error != null)
          ErrorDisplay(message: _error!, onRetry: _load)
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final topic in topics)
                _TopicCard(
                  topic: topic,
                  count: questions == null
                      ? 0
                      : questionsForTopic(
                          widget.subject.slug,
                          topic,
                          questions,
                        ).length,
                  cleared: _cleared.contains(
                    ExamTopicProgress.idFor(
                      examSlug: widget.exam.slug,
                      subjectSlug: widget.subject.slug,
                      topicId: topic.id,
                    ),
                  ),
                  onStart: questions == null
                      ? null
                      : () {
                          final picked = questionsForTopic(
                            widget.subject.slug,
                            topic,
                            questions,
                          );
                          if (picked.length < examTopicMinimum) return;
                          _start(topic, picked);
                        },
                ),
            ],
          ),
        if (!_loading && _error == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Topics with fewer than $examTopicMinimum questions in this paper stay closed.',
              style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
            ),
          ),
      ],
    );
  }
}

class _TopicCard extends StatelessWidget {
  final ExamTopic topic;
  final int count;
  final bool cleared;
  final VoidCallback? onStart;

  const _TopicCard({
    required this.topic,
    required this.count,
    required this.cleared,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ready = count >= examTopicMinimum;
    return SizedBox(
      width: 280,
      child: LiftCard(
        padding: const EdgeInsets.all(16),
        hoverBorder: ready ? AppColors.worldExams : AppColors.line,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(topic.title, style: text.titleMedium)),
                if (cleared)
                  Text(
                    'Cleared',
                    style: text.labelLarge?.copyWith(
                      color: AppColors.success,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              topic.detail,
              style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 10),
            Text(
              ready
                  ? '$count questions ready in this paper'
                  : 'Not enough questions in this paper yet',
              style: text.bodySmall?.copyWith(
                color: ready ? AppColors.worldExams : AppColors.muted,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: ready ? onStart : null,
              child: const Text('Revise topic'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MistakesSection extends ConsumerWidget {
  const _MistakesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final groups = ref
        .watch(myMistakeGroupsProvider)
        .whenOrNull(data: (value) => value);
    if (groups == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageIntro(
          eyebrow: 'Review',
          title: 'Your mistakes',
          body: 'Missed questions wait here until you get them right.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final group in groups)
              SizedBox(
                width: 260,
                child: Material(
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.line),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${group.examLabel} · ${group.subjectName}',
                          style: text.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${group.items.length} to fix',
                          style: text.bodyMedium?.copyWith(
                            color: AppColors.danger,
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: () => context.push(
                            AppRoutes.studentExamSession,
                            extra: group.retryConfig(),
                          ),
                          icon: const Icon(Icons.replay_rounded, size: 18),
                          label: Text(
                            'Retry ${group.items.length > 20 ? 20 : group.items.length}',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _RecentAttempts extends ConsumerWidget {
  const _RecentAttempts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final attempts = ref
        .watch(myExamAttemptsProvider)
        .whenOrNull(data: (value) => value);
    if (attempts == null || attempts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent sessions', style: text.titleLarge),
        const SizedBox(height: 10),
        Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.line),
          ),
          child: Column(
            children: [
              for (final attempt in attempts.take(8)) ...[
                ListTile(
                  title: Text(attempt.headline),
                  subtitle: Text(
                    '${attempt.modeLabel} · ${attempt.correct}/${attempt.total}'
                    ' · ${_dayLabel(attempt.createdAt)}',
                  ),
                  trailing: Text(
                    '${attempt.percent}%',
                    style: text.titleMedium?.copyWith(
                      color: attempt.percent >= 70
                          ? AppColors.success
                          : attempt.percent >= 50
                          ? AppColors.ink
                          : AppColors.danger,
                    ),
                  ),
                ),
                if (attempt != attempts.take(8).last)
                  const Divider(height: 1, indent: 16, endIndent: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

String _dayLabel(DateTime date) {
  final days = DateTime.now().difference(date).inDays;
  if (days == 0) return 'today';
  if (days == 1) return 'yesterday';
  if (days < 7) return '$days days ago';
  return '${date.day}/${date.month}/${date.year}';
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/env.dart';
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
        if (subject.slug == slug && !subject.isSandboxLocked) return subject;
      }
    }
    for (final subject in subjects) {
      if (!subject.isSandboxLocked) return subject;
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
    if (_exam != null && _subject != null) return;
    PastExamType? exam = _exam;
    if (exam == null && data.exams.isNotEmpty) {
      exam = data.exams.cast<PastExamType?>().firstWhere(
        (item) => item?.slug == 'utme',
        orElse: () => data.exams.first,
      );
    }
    final scoped = exam?.subjectsFor(data.subjects) ?? data.subjects;
    final subject = _subject ?? _pickDefaultSubject(scoped);
    if (exam == _exam && subject == _subject) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _exam ??= exam;
        _subject ??= subject;
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
    if (subject.isSandboxLocked) {
      context.showErrorSnackbar(
        '${subject.name} is unavailable on the current content plan.',
      );
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
    if (!Env.hasSdashApi) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Past questions'),
          leading: IconButton(
            tooltip: 'Home',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => popOrGo(context, AppRoutes.studentPath),
          ),
        ),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: ErrorDisplay(
            message:
                'Add SDASH_ACCESS_TOKEN to your .env file, then hot-restart the app.',
          ),
        ),
      );
    }

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
          final setup = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose exam', style: text.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in data.exams)
                    _ExamChip(
                      exam: item,
                      selected: _exam?.slug == item.slug,
                      onTap: () => _selectExam(item, data.subjects),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              Text('Choose subject', style: text.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final subject in subjects)
                    ChoiceChip(
                      label: Text(
                        subject.isSandboxLocked
                            ? '${subject.name} · unavailable'
                            : subject.name,
                      ),
                      selected: _subject?.slug == subject.slug,
                      onSelected: subject.isSandboxLocked
                          ? (_) => context.showErrorSnackbar(
                              '${subject.name} is unavailable on the current content plan.',
                            )
                          : (_) => setState(() => _subject = subject),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: subject.isSandboxLocked
                            ? AppColors.muted
                            : _subject?.slug == subject.slug
                            ? Colors.white
                            : AppColors.ink,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              Text('Year', style: text.titleMedium),
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(
                // ignore: deprecated_member_use
                value: _year,
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: AppColors.surface,
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Any year'),
                  ),
                  for (final year in data.years)
                    DropdownMenuItem(value: year, child: Text('$year')),
                ],
                onChanged: (value) => setState(() => _year = value),
              ),
              if (showUniversity) ...[
                const SizedBox(height: 16),
                Text('University', style: text.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _universityCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'e.g. unilag, oau, ui',
                    filled: true,
                    fillColor: AppColors.surface,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Text('Session length', style: text.titleMedium),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.6,
                children: [
                  for (final mode in PastPracticeMode.values)
                    _ModeCard(
                      mode: mode,
                      selected: _mode == mode,
                      onTap: () => setState(() => _mode = mode),
                    ),
                ],
              ),
            ],
          );
          final summary = _SessionSummary(
            exam: exam,
            subject: _subject,
            year: _year,
            mode: _mode,
            starting: _starting,
            onStart: _starting ? null : _start,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              const PageIntro(
                eyebrow: 'Exam studio',
                title: 'Pick a paper. Start when you are ready.',
                body:
                    'Answers and worked solutions appear after each question. Timed mock waits until you submit. Biology, Chemistry, Physics, and Government also have topic ladders.',
              ),
              const SizedBox(height: 16),
              LiftCard(
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: const SizedBox(
                    height: 132,
                    width: double.infinity,
                    child: WarmAssetImage(
                      'assets/illustrations/world-exams.png',
                      alignment: Alignment.center,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 860) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [setup, const SizedBox(height: 20), summary],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: setup),
                      const SizedBox(width: 20),
                      Expanded(flex: 2, child: summary),
                    ],
                  );
                },
              ),
              if (exam != null &&
                  _subject != null &&
                  topicsForSubject(_subject!.slug).isNotEmpty) ...[
                const SizedBox(height: 28),
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

class _ExamChip extends StatelessWidget {
  final PastExamType exam;
  final bool selected;
  final VoidCallback onTap;

  const _ExamChip({
    required this.exam,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.controlBorder,
            ),
          ),
          child: Text(
            exam.shortLabel,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
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
    String line(String label, String value) => '$label  $value';
    return LiftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This session', style: text.titleLarge),
          const SizedBox(height: 12),
          Text(
            line('Exam', exam?.shortLabel ?? 'Choose an exam'),
            style: text.bodyLarge,
          ),
          const SizedBox(height: 6),
          Text(
            line('Subject', subject?.name ?? 'Choose a subject'),
            style: text.bodyLarge,
          ),
          const SizedBox(height: 6),
          Text(
            line('Year', year?.toString() ?? 'Any year'),
            style: text.bodyLarge,
          ),
          const SizedBox(height: 6),
          Text(line('Questions', '${mode.limit}'), style: text.bodyLarge),
          if (mode.timeLimit != null) ...[
            const SizedBox(height: 6),
            Text(
              line('Time', '${mode.timeLimit!.inMinutes} minutes'),
              style: text.bodyLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'No answers shown until you submit, like the real paper.',
              style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
            ),
          ],
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
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.line,
              width: selected ? 0 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mode.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 14,
                  color: selected ? Colors.white : AppColors.ink,
                ),
              ),
              Text(
                mode.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: selected ? Colors.white70 : AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
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
              const SizedBox(height: 4),
              Text(topic.detail, style: text.bodyMedium),
              const SizedBox(height: 8),
              Text(
                ready
                    ? '$count questions ready'
                    : 'Not enough questions in this paper yet',
                style: text.bodySmall?.copyWith(
                  color: ready ? AppColors.inkSoft : AppColors.muted,
                ),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: ready ? onStart : null,
                child: const Text('Revise topic'),
              ),
            ],
          ),
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

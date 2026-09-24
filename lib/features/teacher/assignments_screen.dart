import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../data/records_providers.dart';
import '../../models/learning_records_models.dart';
import '../../models/past_questions_models.dart';
import '../../router/navigation.dart';
import '../../services/learning_records_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/empty_panel.dart';
import '../../widgets/error_boundary.dart';
import '../../widgets/surfaces.dart';
import '../student/exam_topics.dart';
import '../student/maths_bank.dart';
import '../student/past_questions_hub_screen.dart';

class AssignmentsScreen extends ConsumerWidget {
  const AssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final info = ref.watch(teacherClassInfoProvider);
    return ShellScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: info.when(
              loading: () =>
                  const LoadingIndicator(message: 'Opening your class…'),
              error: (error, _) => ErrorDisplay(
                message: 'Your class could not be loaded.',
                error: error,
                onRetry: () => ref.invalidate(teacherClassInfoProvider),
              ),
              data: (classInfo) {
                if (classInfo == null) {
                  return const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PageIntro(
                        eyebrow: 'Assign',
                        title: 'Set the work',
                        body:
                            'A past paper, a Mandarin lesson, or a maths level shows up first on each learner’s home.',
                      ),
                      SizedBox(height: 18),
                      _NeedsClass(),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Assignments', style: text.headlineSmall),
                              const SizedBox(height: 4),
                              Text(
                                'Set a past paper, a Mandarin lesson, or a maths level for ${classInfo.name}. '
                                'It appears first on each student\'s home screen.',
                                style: text.bodyLarge?.copyWith(
                                  color: AppColors.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (_) =>
                                _NewAssignmentDialog(classId: classInfo.id),
                          ),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('New assignment'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const _AssignmentList(),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _NeedsClass extends StatelessWidget {
  const _NeedsClass();

  @override
  Widget build(BuildContext context) {
    return EmptyPanel(
      icon: Icons.groups_rounded,
      title: 'Open your class first',
      body:
          'Assignments go to everyone who joins with your class code. Set that up on the Class tab, then come back here.',
      actionLabel: 'Go to Class',
      onAction: () => context.go(AppRoutes.teacherHome),
    );
  }
}

class _AssignmentList extends ConsumerWidget {
  const _AssignmentList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(classAssignmentsProvider).when(
          loading: () => const LinearProgressIndicator(minHeight: 3),
          error: (error, _) => ErrorDisplay(
            message: 'Assignments could not be loaded.',
            error: error,
            onRetry: () => ref.invalidate(classAssignmentsProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const EmptyPanel(
                icon: Icons.assignment_outlined,
                title: 'Nothing set yet',
                body:
                    'Try an exam topic due Friday, the next Mandarin lesson, or a mental-maths level. Learners see it on their home screen.',
              );
            }
            return Column(
              children: [
                for (final item in items) ...[
                  _AssignmentCard(progress: item),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        );
  }
}

class _AssignmentCard extends ConsumerWidget {
  final AssignmentProgress progress;

  const _AssignmentCard({required this.progress});

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this assignment?'),
        content: const Text(
          'Students stop seeing it. Saved scores stay in their reports.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final result = await LearningRecordsService.instance.deleteAssignment(
      progress.assignment.id,
    );
    if (!context.mounted) return;
    if (result.isFailure) {
      context.showErrorSnackbar(result.error ?? 'Could not remove it.');
      return;
    }
    ref.invalidate(classAssignmentsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final a = progress.assignment;
    final total = progress.students.length;
    final done = progress.doneCount;
    final due = a.dueAt;
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.line),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
        title: Text(a.title, style: text.titleMedium),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  a.kind.label,
                  if (due != null) 'due ${due.day}/${due.month}/${due.year}',
                  '$done of $total done',
                ].join(' · '),
                style: text.bodySmall?.copyWith(
                  color: a.isOverdue && done < total
                      ? AppColors.danger
                      : AppColors.inkSoft,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : done / total,
                  minHeight: 6,
                  backgroundColor: AppColors.line,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ),
        trailing: IconButton(
          tooltip: 'Remove',
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: () => _delete(context, ref),
        ),
        children: [
          if (progress.students.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, 16),
              child: Text('No students have joined the class yet.'),
            ),
          for (final student in progress.students)
            ListTile(
              dense: true,
              leading: EmojiText(student.avatar, size: 22),
              title: Text(student.name),
              subtitle: Text(progress.statusFor(student.userId)),
              trailing: TextButton(
                onPressed: () =>
                    context.push(AppRoutes.teacherReport(student.userId)),
                child: const Text('Report'),
              ),
              iconColor: progress.isDone(student.userId)
                  ? AppColors.success
                  : AppColors.muted,
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _NewAssignmentDialog extends ConsumerStatefulWidget {
  final String classId;

  const _NewAssignmentDialog({required this.classId});

  @override
  ConsumerState<_NewAssignmentDialog> createState() =>
      _NewAssignmentDialogState();
}

class _NewAssignmentDialogState extends ConsumerState<_NewAssignmentDialog> {
  AssignmentKind _kind = AssignmentKind.exam;
  PastExamType? _exam;
  PastSubject? _subject;
  int? _year;
  String? _topicId;
  int _count = 20;
  String? _lessonId;
  String? _lessonTitle;
  int _mathsLevel = 1;
  DateTime? _due;
  final _title = TextEditingController();
  bool _titleEdited = false;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  String _suggestedTitle() => switch (_kind) {
    AssignmentKind.exam =>
      _exam == null || _subject == null
          ? ''
          : _topicId == null
          ? '$_count ${_exam!.shortLabel} ${_subject!.name} questions'
                '${_year == null ? '' : ' ($_year)'}'
          : '${_exam!.shortLabel} ${_subject!.name}: ${examTopicById(_subject!.slug, _topicId)?.title ?? 'topic'}',
    AssignmentKind.lesson =>
      _lessonTitle == null ? '' : 'Mandarin: $_lessonTitle',
    AssignmentKind.maths =>
      'Maths level $_mathsLevel: ${mathsLevels.firstWhere((l) => l.sequence == _mathsLevel).title}',
  };

  void _refreshTitle() {
    if (_titleEdited) return;
    _title.text = _suggestedTitle();
  }

  Map<String, dynamic>? _config() {
    switch (_kind) {
      case AssignmentKind.exam:
        if (_exam == null || _subject == null) return null;
        final topic = examTopicById(_subject!.slug, _topicId);
        return {
          'exam_slug': _exam!.slug,
          'exam_name': _exam!.name,
          'subject_slug': _subject!.slug,
          'subject_name': _subject!.name,
          'year': _year,
          'count': topic == null ? _count : examTopicSize,
          if (topic != null) 'topic_id': topic.id,
          if (topic != null) 'topic_title': topic.title,
        };
      case AssignmentKind.lesson:
        if (_lessonId == null) return null;
        return {'lesson_id': _lessonId, 'lesson_title': _lessonTitle};
      case AssignmentKind.maths:
        return {'level': _mathsLevel};
    }
  }

  Future<void> _save() async {
    final config = _config();
    final title = _title.text.trim().isEmpty
        ? _suggestedTitle()
        : _title.text.trim();
    if (config == null || title.isEmpty) {
      context.showErrorSnackbar('Finish choosing what to set.');
      return;
    }
    setState(() => _saving = true);
    final result = await LearningRecordsService.instance.createAssignment(
      classId: widget.classId,
      kind: _kind,
      title: title.length > 120 ? title.substring(0, 120) : title,
      config: config,
      dueAt: _due,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isFailure) {
      context.showErrorSnackbar(result.error ?? 'Could not set it.');
      return;
    }
    ref.invalidate(classAssignmentsProvider);
    Navigator.pop(context);
    context.showSuccessSnackbar('Assignment set.');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('New assignment'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<AssignmentKind>(
                segments: const [
                  ButtonSegment(
                    value: AssignmentKind.exam,
                    label: Text('Past paper'),
                  ),
                  ButtonSegment(
                    value: AssignmentKind.lesson,
                    label: Text('Mandarin'),
                  ),
                  ButtonSegment(
                    value: AssignmentKind.maths,
                    label: Text('Maths'),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (value) {
                  setState(() => _kind = value.first);
                  _refreshTitle();
                },
              ),
              const SizedBox(height: 18),
              switch (_kind) {
                AssignmentKind.exam => _examFields(text),
                AssignmentKind.lesson => _lessonFields(),
                AssignmentKind.maths => _mathsFields(),
              },
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _due == null
                          ? 'No due date'
                          : 'Due ${_due!.day}/${_due!.month}/${_due!.year}',
                      style: text.bodyLarge,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: now,
                        lastDate: now.add(const Duration(days: 180)),
                        initialDate: _due ?? now.add(const Duration(days: 3)),
                      );
                      if (picked != null) setState(() => _due = picked);
                    },
                    icon: const Icon(Icons.event_outlined),
                    label: Text(_due == null ? 'Set due date' : 'Change'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                maxLength: 120,
                onChanged: (_) => _titleEdited = true,
                decoration: const InputDecoration(
                  labelText: 'Title students see',
                  filled: true,
                  fillColor: AppColors.surface,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Setting…' : 'Set assignment'),
        ),
      ],
    );
  }

  Widget _examFields(TextTheme text) {
    return ref
        .watch(pastQuestionsCatalogProvider)
        .when(
          loading: () => const LinearProgressIndicator(minHeight: 3),
          error: (_, _) => const Text(
            'The exam catalogue is unavailable. Check the Sdash key in .env.',
          ),
          data: (catalog) {
            final subjects =
                (_exam?.subjectsFor(catalog.subjects) ?? catalog.subjects)
                    .where((s) => !s.isSandboxLocked)
                    .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final exam in catalog.exams)
                      ChoiceChip(
                        label: Text(exam.shortLabel),
                        selected: _exam?.slug == exam.slug,
                        onSelected: (_) {
                          setState(() {
                            _exam = exam;
                            final scoped = exam.subjectsFor(catalog.subjects);
                            if (_subject != null &&
                                !scoped.any((s) => s.slug == _subject!.slug)) {
                              _subject = null;
                              _topicId = null;
                            }
                          });
                          _refreshTitle();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: _subject?.slug,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    filled: true,
                    fillColor: AppColors.surface,
                  ),
                  items: [
                    for (final subject in subjects)
                      DropdownMenuItem(
                        value: subject.slug,
                        child: Text(subject.name),
                      ),
                  ],
                  onChanged: (slug) {
                    setState(() {
                      _subject = subjects.firstWhere((s) => s.slug == slug);
                      if (examTopicById(_subject?.slug, _topicId) == null) {
                        _topicId = null;
                      }
                    });
                    _refreshTitle();
                  },
                ),
                if (topicsForSubject(_subject?.slug).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    // ignore: deprecated_member_use
                    value: _topicId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Topic',
                      filled: true,
                      fillColor: AppColors.surface,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Whole paper'),
                      ),
                      for (final topic in topicsForSubject(_subject?.slug))
                        DropdownMenuItem(
                          value: topic.id,
                          child: Text(topic.title),
                        ),
                    ],
                    onChanged: (id) {
                      setState(() => _topicId = id);
                      _refreshTitle();
                    },
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        // ignore: deprecated_member_use
                        value: _year,
                        decoration: const InputDecoration(
                          labelText: 'Year',
                          filled: true,
                          fillColor: AppColors.surface,
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Any year'),
                          ),
                          for (final year in catalog.years)
                            DropdownMenuItem(value: year, child: Text('$year')),
                        ],
                        onChanged: (value) {
                          setState(() => _year = value);
                          _refreshTitle();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (_topicId != null)
                      const Text('8 questions')
                    else
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 10, label: Text('10')),
                          ButtonSegment(value: 20, label: Text('20')),
                          ButtonSegment(value: 40, label: Text('40')),
                        ],
                        selected: {_count},
                        onSelectionChanged: (value) {
                          setState(() => _count = value.first);
                          _refreshTitle();
                        },
                      ),
                  ],
                ),
              ],
            );
          },
        );
  }

  Widget _lessonFields() {
    return ref
        .watch(mandarinCourseProvider)
        .when(
          loading: () => const LinearProgressIndicator(minHeight: 3),
          error: (_, _) => const Text('Mandarin lessons could not be loaded.'),
          data: (course) {
            final lessons = course.lessons.where((l) => l.isPlayable).toList()
              ..sort((a, b) => a.sequence.compareTo(b.sequence));
            return DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _lessonId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Lesson',
                filled: true,
                fillColor: AppColors.surface,
              ),
              items: [
                for (final lesson in lessons)
                  DropdownMenuItem(
                    value: lesson.id,
                    child: Text(
                      'Lesson ${lesson.sequence}: ${lesson.title}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (id) {
                final lesson = lessons.firstWhere((l) => l.id == id);
                setState(() {
                  _lessonId = lesson.id;
                  _lessonTitle = 'Lesson ${lesson.sequence}, ${lesson.title}';
                });
                _refreshTitle();
              },
            );
          },
        );
  }

  Widget _mathsFields() {
    return DropdownButtonFormField<int>(
      // ignore: deprecated_member_use
      value: _mathsLevel,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Maths level',
        filled: true,
        fillColor: AppColors.surface,
      ),
      items: [
        for (final level in mathsLevels)
          DropdownMenuItem(
            value: level.sequence,
            child: Text('Level ${level.sequence}: ${level.title}'),
          ),
      ],
      onChanged: (value) {
        setState(() => _mathsLevel = value ?? 1);
        _refreshTitle();
      },
    );
  }
}

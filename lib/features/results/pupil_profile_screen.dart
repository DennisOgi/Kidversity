import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/app_state.dart';
import '../../models/results_models.dart';
import '../comm/compose_dialog.dart';
import 'support_section.dart';
import '../../services/results_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/role_style.dart';
import '../../widgets/error_boundary.dart';
import '../../widgets/kv_ui.dart';

/// One pupil's targets and official school results for this term, plus their
/// learning on Kidversity. Teachers and school admins can edit; the pupil and
/// their parents read the same page.
class PupilProfileScreen extends ConsumerWidget {
  final String studentId;
  final List<Color> heroColors;

  /// The pupil reading their own profile ("My school goals").
  final bool self;

  const PupilProfileScreen({
    super.key,
    required this.studentId,
    required this.heroColors,
    this.self = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(pupilProfileProvider(studentId));
    Future<void> refresh() async =>
        ref.refresh(pupilProfileProvider(studentId).future);

    return profile.when(
      loading: () => const KvPage(
        children: [LoadingIndicator(message: 'Opening the profile…')],
      ),
      error: (error, _) => KvPage(
        children: [
          ErrorDisplay(
            message: '$error'.contains('NOT_AUTHORIZED')
                ? 'You can only open profiles of pupils you teach or your own children.'
                : 'This profile could not be loaded.',
            error: error,
            onRetry: () => ref.invalidate(pupilProfileProvider(studentId)),
          ),
        ],
      ),
      data: (p) => KvPage(
        onRefresh: refresh,
        children: [
          _Header(profile: p, colors: heroColors, self: self),
          _Summary(profile: p),
          _Subjects(profile: p, self: self),
          SupportSection(profile: p),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  final PupilProfile profile;
  final List<Color> colors;
  final bool self;

  const _Header({
    required this.profile,
    required this.colors,
    required this.self,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final where = [?profile.className, ?profile.schoolName].join(' · ');
    return HeroBanner(
      colors: colors,
      eyebrow: [
        self ? 'My school goals' : 'Pupil profile',
        ?profile.termLabel,
      ].join(' · '),
      title: self
          ? 'Hi ${firstName(profile.displayName)}, keep growing.'
          : profile.displayName,
      body: where.isEmpty ? null : where,
      actions: [
        if (profile.canEdit) ...[
          SunButton(
            label: 'Add a score',
            onPressed: () => showScoreDialog(context, ref, profile),
          ),
          HeroGhostButton(
            label: 'Add a subject',
            onPressed: () =>
                showAddSubjectDialog(context, ref, profile.studentId),
          ),
          // Teachers can write privately to this pupil's family.
          if (ref.watch(teacherClassInfoProvider).value case final cls?)
            HeroGhostButton(
              label: 'Message guardian',
              onPressed: () => showComposeDialog(
                context,
                ref,
                classId: cls.id,
                pupils: [(id: profile.studentId, name: profile.displayName)],
                pupilId: profile.studentId,
              ),
            ),
        ],
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  final PupilProfile profile;

  const _Summary({required this.profile});

  @override
  Widget build(BuildContext context) {
    final withTarget = profile.subjects.where((s) => s.target != null).length;
    final support = profile.needsSupport;
    return AdaptiveGrid(
      minTileWidth: 160,
      children: [
        MetricTile(
          tint: AppTint.violet,
          icon: Icons.flag_rounded,
          label: 'Subjects with a target',
          value: '$withTarget',
          caption: profile.termLabel ?? 'This term',
        ),
        MetricTile(
          tint: support == 0 ? AppTint.mint : AppTint.coral,
          icon: support == 0
              ? Icons.check_circle_rounded
              : Icons.support_rounded,
          label: 'Below target',
          value: '$support',
          caption: support == 0 ? 'All on track' : 'Needs some support',
        ),
        MetricTile(
          tint: AppTint.sky,
          icon: Icons.menu_book_rounded,
          label: 'Kidversity lessons',
          value: '${profile.lessonsCompleted}',
          caption: 'Level ${profile.level} · ${profile.xp} XP',
        ),
        MetricTile(
          tint: AppTint.sun,
          icon: Icons.local_fire_department_rounded,
          label: 'Streak',
          value: profile.streakDays == 0 ? '–' : '${profile.streakDays} days',
          caption: 'Days in a row of learning',
        ),
      ],
    );
  }
}

class _Subjects extends ConsumerWidget {
  final PupilProfile profile;
  final bool self;

  const _Subjects({required this.profile, required this.self});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = profile.subjects;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KvSectionTitle(
          title: 'Goals and school results',
          subtitle: profile.canEdit
              ? 'Set a target for each subject, then add scores as tests come in.'
              : 'Targets from ${self ? 'your' : 'the'} teacher and official school scores.',
        ),
        if (subjects.isEmpty)
          KvCard(
            tint: AppTint.violet,
            child: Row(
              children: [
                const TintIcon(tint: AppTint.violet, icon: Icons.flag_rounded),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    profile.canEdit
                        ? 'No subjects yet. Add the subjects your school reports on, like English or Mathematics.'
                        : 'No school results yet. They appear here when the teacher adds them.',
                    style: const TextStyle(
                      color: AppColors.inkSoft,
                      height: 1.4,
                    ),
                  ),
                ),
                if (profile.canEdit) ...[
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () =>
                        showAddSubjectDialog(context, ref, profile.studentId),
                    child: const Text('Add a subject'),
                  ),
                ],
              ],
            ),
          )
        else
          AdaptiveGrid(
            minTileWidth: 320,
            maxColumns: 2,
            children: [
              for (final (i, s) in subjects.indexed)
                _SubjectCard(
                  profile: profile,
                  subject: s,
                  tint: AppTint.cycle[i % AppTint.cycle.length],
                ),
            ],
          ),
      ],
    );
  }
}

class _SubjectCard extends ConsumerWidget {
  final PupilProfile profile;
  final SubjectProgress subject;
  final AppTint tint;

  const _SubjectCard({
    required this.profile,
    required this.subject,
    required this.tint,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = subject;
    final gap = s.gap;
    final growth = s.growth;
    final chipTint = switch (s.status) {
      TargetStatus.below => StatusChip.alert,
      TargetStatus.onTarget || TargetStatus.above => AppTint.mint,
      TargetStatus.noData => AppTint.slate,
    };

    Widget big(String value, String label) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            height: 1.1,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 13, color: tint.ink)),
      ],
    );

    Widget small(String label, String value) => Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: const TextStyle(color: AppColors.inkSoft),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
      style: const TextStyle(fontSize: 13.5),
    );

    return KvCard(
      tint: tint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: tint.strong,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              if (profile.canEdit)
                TextButton(
                  onPressed: () => showTargetDialog(context, ref, profile, s),
                  child: Text(s.target == null ? 'Set target' : 'Edit target'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              big(s.target == null ? '–' : '${fmtScore(s.target!)}%', 'Target'),
              const SizedBox(width: 28),
              big(
                s.latest == null ? '–' : '${fmtScore(s.latest!)}%',
                'Latest score',
              ),
            ],
          ),
          const SizedBox(height: 14),
          _TargetBar(latest: s.latest, target: s.target, tint: tint),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(
                tint: chipTint,
                label: gap != null
                    ? gapLabel(gap)
                    : s.target == null
                    ? 'No target yet'
                    : 'No score yet',
              ),
              if (s.baseline != null)
                small('Baseline', '${fmtScore(s.baseline!)}%'),
              if (growth != null)
                small(
                  'Growth',
                  '${growth >= 0 ? '+' : '−'}${fmtScore(growth.abs())} points',
                ),
            ],
          ),
          if (s.results.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 6),
            for (final r in s.results.reversed.take(5))
              _ResultRow(entry: r, profile: profile),
          ],
        ],
      ),
    );
  }
}

/// Latest score as a bar, with a tick where the target is.
class _TargetBar extends StatelessWidget {
  final double? latest;
  final double? target;
  final AppTint tint;

  const _TargetBar({
    required this.latest,
    required this.target,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              KvBar(value: (latest ?? 0) / 100, tint: tint, height: 10),
              if (target != null)
                Positioned(
                  left: (w * target! / 100 - 1.5).clamp(0, w - 3),
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ResultRow extends ConsumerWidget {
  final ResultEntry entry;
  final PupilProfile profile;

  const _ResultRow({required this.entry, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = entry.assessedOn;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              [
                entry.label,
                if (entry.title.isNotEmpty && entry.kind != ResultKind.test)
                  entry.kind.label,
                if (date != null) '${date.day}/${date.month}',
              ].join(' · '),
              style: const TextStyle(fontSize: 13.5, color: AppColors.inkSoft),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${fmtScore(entry.score)}%',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          if (profile.canEdit)
            IconButton(
              tooltip: 'Remove this score',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Remove this score?'),
                    content: Text(
                      '${entry.label}: ${fmtScore(entry.score)}%. This cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Keep'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );
                if (ok != true || !context.mounted) return;
                await _run(context, ref, profile.studentId, () {
                  return ResultsService.instance.deleteResult(entry.id);
                });
              },
            ),
        ],
      ),
    );
  }
}

// Dialogs -------------------------------------------------------------------

Future<void> _run(
  BuildContext context,
  WidgetRef ref,
  String studentId,
  Future<void> Function() action,
) async {
  try {
    await action();
    ref.invalidate(pupilProfileProvider(studentId));
    ref.invalidate(classResultsProvider);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ResultsService.message(e))));
    }
  }
}

double? _parseScore(String text) {
  final v = double.tryParse(text.trim().replaceAll('%', ''));
  if (v == null || v < 0 || v > 100) return null;
  return v;
}

final _scoreFormat = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
  LengthLimitingTextInputFormatter(5),
];

Future<void> showTargetDialog(
  BuildContext context,
  WidgetRef ref,
  PupilProfile profile,
  SubjectProgress subject,
) async {
  final ctrl = TextEditingController(
    text: subject.target == null ? '' : fmtScore(subject.target!),
  );
  final result = await showDialog<({bool clear, double? value})>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('${subject.name} target'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: _scoreFormat,
        decoration: const InputDecoration(
          labelText: 'Target score',
          suffixText: '%',
          helperText: 'For this term, from 0 to 100.',
        ),
      ),
      actions: [
        if (subject.target != null)
          TextButton(
            onPressed: () => Navigator.pop(c, (clear: true, value: null)),
            child: const Text('Clear target'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final v = _parseScore(ctrl.text);
            if (v == null) return;
            Navigator.pop(c, (clear: false, value: v));
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (result == null || !context.mounted) return;
  await _run(
    context,
    ref,
    profile.studentId,
    () => ResultsService.instance.setTarget(
      profile.studentId,
      subject.subjectId,
      result.clear ? null : result.value,
    ),
  );
}

Future<void> showAddSubjectDialog(
  BuildContext context,
  WidgetRef ref,
  String studentId,
) async {
  final ctrl = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Add a subject'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        maxLength: 60,
        decoration: const InputDecoration(
          labelText: 'Subject name',
          hintText: 'English, Mathematics, Basic Science…',
          helperText: 'Added for your whole school.',
        ),
        onSubmitted: (v) => Navigator.pop(c, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, ctrl.text),
          child: const Text('Add'),
        ),
      ],
    ),
  );
  if (name == null || name.trim().isEmpty || !context.mounted) return;
  await _run(
    context,
    ref,
    studentId,
    () => ResultsService.instance.addSubject(name.trim()),
  );
}

Future<void> showScoreDialog(
  BuildContext context,
  WidgetRef ref,
  PupilProfile profile, {
  SubjectProgress? subject,
}) async {
  if (profile.subjects.isEmpty) {
    await showAddSubjectDialog(context, ref, profile.studentId);
    return;
  }
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _ScoreDialog(
      profile: profile,
      initial: subject ?? profile.subjects.first,
    ),
  );
  if (saved == true) {
    ref.invalidate(pupilProfileProvider(profile.studentId));
    ref.invalidate(classResultsProvider);
  }
}

class _ScoreDialog extends StatefulWidget {
  final PupilProfile profile;
  final SubjectProgress initial;

  const _ScoreDialog({required this.profile, required this.initial});

  @override
  State<_ScoreDialog> createState() => _ScoreDialogState();
}

class _ScoreDialogState extends State<_ScoreDialog> {
  late String _subjectId = widget.initial.subjectId;
  ResultKind _kind = ResultKind.test;
  final _score = TextEditingController();
  final _title = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial.results.isEmpty) _kind = ResultKind.baseline;
  }

  Future<void> _save() async {
    final score = _parseScore(_score.text);
    if (score == null) {
      setState(() => _error = 'Type a score from 0 to 100.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ResultsService.instance.recordResult(
        studentId: widget.profile.studentId,
        subjectId: _subjectId,
        kind: _kind,
        score: score,
        title: _title.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = ResultsService.message(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add a score for ${firstName(widget.profile.displayName)}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _subjectId,
              decoration: const InputDecoration(labelText: 'Subject'),
              items: [
                for (final s in widget.profile.subjects)
                  DropdownMenuItem(value: s.subjectId, child: Text(s.name)),
              ],
              onChanged: (v) => setState(() => _subjectId = v ?? _subjectId),
            ),
            const SizedBox(height: 14),
            SegmentedButton<ResultKind>(
              segments: [
                for (final k in ResultKind.values)
                  ButtonSegment(value: k, label: Text(k.label)),
              ],
              selected: {_kind},
              onSelectionChanged: (v) => setState(() => _kind = v.first),
            ),
            const SizedBox(height: 6),
            Text(
              _kind == ResultKind.baseline
                  ? 'Where the pupil started this term. Growth is measured from here.'
                  : 'A test or exam score this term.',
              style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _score,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: _scoreFormat,
              decoration: const InputDecoration(
                labelText: 'Score',
                suffixText: '%',
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _title,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Name (optional)',
                hintText: 'Fractions test, mid-term exam…',
              ),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Color(0xFFA61F2D))),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save score'),
        ),
      ],
    );
  }
}

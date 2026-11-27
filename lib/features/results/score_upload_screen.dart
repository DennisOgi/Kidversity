import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/file_download.dart';
import '../../core/sheet_reader.dart';
import '../../data/app_state.dart';
import '../../models/results_models.dart';
import '../../models/score_import.dart';
import '../../services/results_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/role_style.dart';
import '../../widgets/error_boundary.dart';
import '../../widgets/kv_ui.dart';

/// Bulk score upload for the teacher's class: download a template, fill it in
/// Excel, upload it, review every row, then save. Each upload can be undone.
class ScoreUploadScreen extends ConsumerWidget {
  const ScoreUploadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(teacherClassInfoProvider);
    return info.when(
      loading: () => const KvPage(
        children: [LoadingIndicator(message: 'Opening your class…')],
      ),
      error: (e, _) => KvPage(
        children: [
          ErrorDisplay(
            message: 'Your class could not be loaded.',
            error: e,
            onRetry: () => ref.invalidate(teacherClassInfoProvider),
          ),
        ],
      ),
      data: (cls) => cls == null
          ? const KvPage(
              children: [KvCard(child: Text('Create your class first.'))],
            )
          : _Upload(classId: cls.id, className: cls.name),
    );
  }
}

class _Upload extends ConsumerStatefulWidget {
  final String classId;
  final String className;

  const _Upload({required this.classId, required this.className});

  @override
  ConsumerState<_Upload> createState() => _UploadState();
}

class _UploadState extends ConsumerState<_Upload> {
  ResultKind _kind = ResultKind.test;
  final _title = TextEditingController();
  DateTime _date = DateTime.now();
  String? _fileName;
  ScoreImport? _preview;
  String? _fileError;
  bool _saving = false;
  String? _savedMessage;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _downloadTemplate(ClassResults cls) {
    final ok = downloadTextFile(
      '${widget.className.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}_scores.csv',
      toCsv(scoreTemplate(cls)),
    );
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloads work in the web app.')),
      );
    }
  }

  Future<void> _pick(ClassResults cls) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'csv'],
      withData: true,
    );
    final file = res?.files.singleOrNull;
    if (file == null) return;
    setState(() {
      _fileName = file.name;
      _savedMessage = null;
    });
    try {
      final bytes = file.bytes;
      if (bytes == null) {
        throw const FormatException('The file could not be read.');
      }
      if (bytes.length > 5 * 1024 * 1024) {
        throw const FormatException('That file is larger than 5 MB.');
      }
      final sheet = readSheet(bytes, file.name);
      setState(() {
        _preview = ScoreImport.build(sheet, cls);
        _fileError = _preview!.headerProblem;
      });
    } on FormatException catch (e) {
      setState(() {
        _preview = null;
        _fileError = e.message;
      });
    }
  }

  Future<void> _save() async {
    final p = _preview;
    if (p == null || !p.canSave) return;
    setState(() => _saving = true);
    try {
      final r = await ResultsService.instance.importClassScores(
        classId: widget.classId,
        kind: _kind,
        rows: p.toPayload(),
        title: _title.text.trim(),
        assessedOn: _date,
        fileName: _fileName,
      );
      ref.invalidate(scoreBatchesProvider(widget.classId));
      ref.invalidate(classResultsProvider(widget.classId));
      ref.invalidate(pupilProfileProvider);
      setState(() {
        _saving = false;
        _savedMessage = 'Saved ${r.saved} scores from $_fileName.';
        _preview = null;
        _fileName = null;
      });
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ResultsService.message(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cls = ref.watch(classResultsProvider(widget.classId));
    return cls.when(
      loading: () => const KvPage(
        children: [LoadingIndicator(message: 'Loading your class…')],
      ),
      error: (e, _) => KvPage(
        children: [
          ErrorDisplay(
            message: 'Your class could not be loaded.',
            error: e,
            onRetry: () => ref.invalidate(classResultsProvider(widget.classId)),
          ),
        ],
      ),
      data: (c) => KvPage(
        children: [
          HeroBanner(
            colors: HeroColors.teacher,
            eyebrow: [
              'Upload scores',
              widget.className,
              ?c.termLabel,
            ].join(' · '),
            title: 'Add a whole class of scores at once.',
            body:
                'Fill in the template in Excel or Google Sheets, upload it, check the preview, then save.',
            actions: [
              HeroGhostButton(
                label: 'Back to results',
                onPressed: () => context.go('/teacher/results'),
              ),
            ],
          ),
          if (c.subjects.isEmpty)
            const KvCard(
              tint: AppTint.coral,
              child: Text(
                'Add your school\'s subjects on the Results page before uploading scores.',
              ),
            )
          else ...[
            _Step(
              number: 1,
              title: 'Download the template',
              body:
                  'It lists your ${c.pupils.length} pupils with a column for each subject. Leave cells blank for pupils who did not sit the test.',
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _downloadTemplate(c),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Download template (.csv)'),
                ),
              ),
            ),
            _Step(
              number: 2,
              title: 'Describe the assessment and upload',
              body:
                  'Scores are percentages from 0 to 100. A baseline replaces the pupil\'s earlier baseline this term.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SegmentedButton<ResultKind>(
                        showSelectedIcon: false,
                        segments: [
                          for (final k in ResultKind.values)
                            ButtonSegment(value: k, label: Text(k.label)),
                        ],
                        selected: {_kind},
                        onSelectionChanged: (v) =>
                            setState(() => _kind = v.first),
                      ),
                      SizedBox(
                        width: 260,
                        child: TextField(
                          controller: _title,
                          maxLength: 80,
                          decoration: const InputDecoration(
                            labelText: 'Name (optional)',
                            hintText: 'Mid-term test',
                            counterText: '',
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 365),
                            ),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) setState(() => _date = picked);
                        },
                        icon: const Icon(Icons.event_rounded, size: 18),
                        label: Text(
                          '${_date.day}/${_date.month}/${_date.year}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _DropZone(fileName: _fileName, onPick: () => _pick(c)),
                  if (_fileError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _fileError!,
                      style: const TextStyle(
                        color: Color(0xFFA61F2D),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_savedMessage != null)
              KvCard(
                tint: AppTint.mint,
                child: Row(
                  children: [
                    const TintIcon(
                      tint: AppTint.mint,
                      icon: Icons.check_circle_rounded,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _savedMessage!,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/teacher/results'),
                      child: const Text('See results'),
                    ),
                  ],
                ),
              ),
            if (_preview != null && _preview!.headerProblem == null)
              _Review(
                preview: _preview!,
                saving: _saving,
                onSave: _save,
                onPickAgain: () => _pick(c),
              ),
            _History(classId: widget.classId),
          ],
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String title;
  final String body;
  final Widget child;

  const _Step({
    required this.number,
    required this.title,
    required this.body,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return KvCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTint.mint.ink,
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DropZone extends StatelessWidget {
  final String? fileName;
  final VoidCallback onPick;

  const _DropZone({required this.fileName, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
        decoration: BoxDecoration(
          color: AppTint.mint.soft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTint.mint.strong.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(Icons.upload_file_rounded, size: 40, color: AppTint.mint.ink),
            const SizedBox(height: 8),
            Text(
              fileName ?? 'Choose an Excel (.xlsx) or CSV file',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppTint.mint.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              fileName == null
                  ? 'Up to 5 MB'
                  : 'Tap to choose a different file',
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _Review extends StatelessWidget {
  final ScoreImport preview;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onPickAgain;

  const _Review({
    required this.preview,
    required this.saving,
    required this.onSave,
    required this.onPickAgain,
  });

  @override
  Widget build(BuildContext context) {
    final subjects = preview.subjectColumns.values.toList();
    final bad = preview.problemCount;
    return KvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTint.mint.ink,
                child: const Text(
                  '3',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Check and save',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusChip(
                label: '${preview.rows.length} pupils',
                tint: AppTint.sky,
              ),
              StatusChip(
                label: '${preview.scoreCount} scores',
                tint: AppTint.mint,
              ),
              StatusChip(
                label: bad == 0
                    ? 'No problems'
                    : '$bad row${bad == 1 ? '' : 's'} to fix',
                tint: bad == 0 ? AppTint.mint : StatusChip.alert,
              ),
              if (preview.unknownColumns.isNotEmpty)
                StatusChip(
                  label:
                      'Ignored columns: ${preview.unknownColumns.join(', ')}',
                  tint: AppTint.sun,
                ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingTextStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.inkSoft,
                fontSize: 13,
              ),
              dataRowMinHeight: 46,
              columns: [
                const DataColumn(label: Text('Row')),
                const DataColumn(label: Text('Pupil')),
                for (final s in subjects) DataColumn(label: Text(s.name)),
                const DataColumn(label: Text('Check')),
              ],
              rows: [
                for (final r in preview.rows)
                  DataRow(
                    color: WidgetStatePropertyAll(
                      r.problems.isEmpty ? null : const Color(0xFFFDECEE),
                    ),
                    cells: [
                      DataCell(
                        Text(
                          '${r.line}',
                          style: const TextStyle(color: AppColors.inkSoft),
                        ),
                      ),
                      DataCell(
                        Text(
                          r.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      for (final s in subjects)
                        DataCell(
                          r.cellProblems.containsKey(s.id)
                              ? const Icon(
                                  Icons.error_rounded,
                                  color: Color(0xFFA61F2D),
                                  size: 20,
                                )
                              : Text(
                                  r.validScores[s.id] == null
                                      ? '–'
                                      : fmtScore(r.validScores[s.id]!),
                                ),
                        ),
                      DataCell(
                        r.problems.isEmpty
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF1C8C4E),
                                size: 20,
                              )
                            : SizedBox(
                                width: 320,
                                child: Text(
                                  r.problems.join(' · '),
                                  style: const TextStyle(
                                    color: Color(0xFFA61F2D),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  bad > 0
                      ? 'Fix the highlighted rows in your file and upload it again. Nothing has been saved.'
                      : preview.scoreCount == 0
                      ? 'There are no scores in this file yet.'
                      : 'Ready to save ${preview.scoreCount} scores.',
                  style: TextStyle(
                    color: bad > 0
                        ? const Color(0xFFA61F2D)
                        : AppColors.inkSoft,
                  ),
                ),
              ),
              if (bad > 0)
                OutlinedButton(
                  onPressed: onPickAgain,
                  child: const Text('Upload fixed file'),
                )
              else
                FilledButton.icon(
                  onPressed: saving || !preview.canSave ? null : onSave,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTint.mint.ink,
                  ),
                  icon: const Icon(Icons.check_rounded),
                  label: Text(
                    saving ? 'Saving…' : 'Save ${preview.scoreCount} scores',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _History extends ConsumerWidget {
  final String classId;

  const _History({required this.classId});

  Future<void> _undo(BuildContext context, WidgetRef ref, ScoreBatch b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Undo this upload?'),
        content: Text(
          'This removes the ${b.rows} scores saved from ${b.fileName ?? 'this upload'}. '
          'Scores added another way are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Undo upload'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final removed = await ResultsService.instance.undoScoreBatch(b.id);
      ref.invalidate(scoreBatchesProvider(classId));
      ref.invalidate(classResultsProvider(classId));
      ref.invalidate(pupilProfileProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Removed $removed scores.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ResultsService.message(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batches =
        ref.watch(scoreBatchesProvider(classId)).value ?? const <ScoreBatch>[];
    if (batches.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const KvSectionTitle(
          title: 'Recent uploads',
          subtitle: 'Undo an upload if it went into the wrong place.',
        ),
        KvCard(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
          child: Column(
            children: [
              for (final b in batches)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: TintIcon(
                    tint: b.undoneAt == null ? AppTint.mint : AppTint.slate,
                    icon: b.undoneAt == null
                        ? Icons.table_chart_rounded
                        : Icons.undo_rounded,
                  ),
                  title: Text(
                    [b.kind.label, if (b.title.isNotEmpty) b.title].join(' · '),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      decoration: b.undoneAt == null
                          ? null
                          : TextDecoration.lineThrough,
                    ),
                  ),
                  subtitle: Text(
                    [
                      '${b.rows} scores',
                      ?b.fileName,
                      if (b.by != null) 'by ${b.by}',
                      if (b.undoneAt != null) 'undone',
                    ].join(' · '),
                  ),
                  trailing: b.undoneAt == null
                      ? TextButton(
                          onPressed: () => _undo(context, ref, b),
                          child: const Text('Undo'),
                        )
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

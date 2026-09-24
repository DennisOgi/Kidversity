import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/records_providers.dart';
import '../../services/learning_records_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import 'maths_bank.dart';

const _prefsKey = 'kidversity_maths_levels';

class MathsPathScreen extends ConsumerStatefulWidget {
  /// Opens straight into a level, for teacher-assigned work.
  final int? startLevel;
  final String? assignmentId;

  const MathsPathScreen({super.key, this.startLevel, this.assignmentId});

  @override
  ConsumerState<MathsPathScreen> createState() => _MathsPathScreenState();
}

class _MathsPathScreenState extends ConsumerState<MathsPathScreen> {
  Set<int> _done = {};
  bool _ready = false;
  MathsLevel? _level;
  String? _assignmentId;

  @override
  void initState() {
    super.initState();
    _assignmentId = widget.assignmentId;
    final start = widget.startLevel;
    if (start != null) {
      for (final level in mathsLevels) {
        if (level.sequence == start) _level = level;
      }
    }
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? const [];
    final local = raw.map(int.tryParse).whereType<int>().toSet();
    var remote = <int>{};
    try {
      final results = await LearningRecordsService.instance.fetchMaths();
      remote = {
        for (final result in results)
          if (result.passed) result.level,
      };
    } catch (error) {
      debugPrint('[Kidversity] maths results unavailable: $error');
    }
    if (!mounted) return;
    setState(() {
      _done = {...local, ...remote};
      _ready = true;
    });
  }

  Future<void> _record(MathsLevel level, int correct, int total) async {
    final assignment = _assignmentId;
    _assignmentId = null;
    await LearningRecordsService.instance.recordMaths(
      level: level.sequence,
      correct: correct,
      total: total,
      assignmentId: assignment,
    );
    ref
      ..invalidate(myMathsResultsProvider)
      ..invalidate(myAssignmentsProvider);
    if (correct * 10 < total * 7) return;
    final next = {..._done, level.sequence};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      next.map((value) => '$value').toList(),
    );
    if (!mounted) return;
    setState(() => _done = next);
  }

  bool _open(MathsLevel level) =>
      level.sequence == 1 ||
      _done.contains(level.sequence - 1) ||
      level.sequence == widget.startLevel;

  List<({String? header, MathsLevel? level})> _strandSections() {
    const order = ['Number', 'Fractions', 'Data', 'Measure', 'Algebra'];
    final rows = <({String? header, MathsLevel? level})>[];
    for (final strand in order) {
      final levels = [
        for (final level in mathsLevels)
          if (level.strand == strand) level,
      ];
      if (levels.isEmpty) continue;
      rows.add((header: strand.toUpperCase(), level: null));
      for (final level in levels) {
        rows.add((header: null, level: level));
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    if (_level != null) {
      return _MathsDrill(
        level: _level!,
        onExit: () => setState(() => _level = null),
        onResult: (correct, total) => _record(_level!, correct, total),
      );
    }
    final text = Theme.of(context).textTheme;
    return ShellScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        Text(
          'NUMBER TO MEASURE',
          style: text.labelLarge?.copyWith(
            color: AppColors.worldExams,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text('Mental maths', style: text.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'Twenty levels in five strands: number, fractions, data, measure, and a first step into algebra. ${mathsSumsPerLevel} sums each; ${mathsClearScore(mathsSumsPerLevel)} right clears a level. The same kinds of sums can run a Rope Pull for the class.',
          style: text.bodyLarge?.copyWith(color: AppColors.inkSoft),
        ),
        const SizedBox(height: 18),
        if (!_ready)
          const LinearProgressIndicator(minHeight: 3)
        else
          for (final entry in _strandSections()) ...[
            if (entry.header != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                child: Text(
                  entry.header!,
                  style: text.labelLarge?.copyWith(
                    color: AppColors.inkSoft,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
            if (entry.level != null) ...[
              _LevelCard(
                level: entry.level!,
                done: _done.contains(entry.level!.sequence),
                open: _open(entry.level!),
                onTap: _open(entry.level!)
                    ? () => setState(() => _level = entry.level)
                    : null,
              ),
              const SizedBox(height: 10),
            ],
          ],
      ],
    );
  }
}

class _LevelCard extends StatelessWidget {
  final MathsLevel level;
  final bool done;
  final bool open;
  final VoidCallback? onTap;

  const _LevelCard({
    required this.level,
    required this.done,
    required this.open,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: done ? AppColors.success : AppColors.line),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: open ? AppColors.worldExams : AppColors.line,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${level.sequence}',
                  style: text.titleMedium?.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(level.title, style: text.titleMedium),
                    Text(
                      open
                          ? level.detail
                          : 'Finish level ${level.sequence - 1} to unlock',
                      style: text.bodyMedium?.copyWith(
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                done
                    ? Icons.check_rounded
                    : open
                    ? Icons.play_arrow_rounded
                    : Icons.lock_outline_rounded,
                color: done ? AppColors.success : AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MathsDrill extends StatefulWidget {
  final MathsLevel level;
  final VoidCallback onExit;
  final Future<void> Function(int correct, int total) onResult;

  const _MathsDrill({
    required this.level,
    required this.onExit,
    required this.onResult,
  });

  @override
  State<_MathsDrill> createState() => _MathsDrillState();
}

class _MathsDrillState extends State<_MathsDrill> {
  static const _total = mathsSumsPerLevel;
  final _random = Random();
  late MathsSum _sum = makeMathsSum(widget.level.sequence, _random);
  int _index = 0;
  int _correct = 0;
  String? _picked;
  bool _finished = false;

  void _choose(String value) {
    if (_picked != null) return;
    setState(() {
      _picked = value;
      if (value == _sum.answer) _correct++;
    });
  }

  void _next() {
    if (_index + 1 >= _total) {
      setState(() => _finished = true);
      widget.onResult(_correct, _total);
      return;
    }
    setState(() {
      _index++;
      _picked = null;
      _sum = makeMathsSum(widget.level.sequence, _random);
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (_finished) {
      return Scaffold(
        backgroundColor: AppColors.paper,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$_correct of $_total', style: text.displaySmall),
                  const SizedBox(height: 8),
                  Text(widget.level.title, style: text.titleLarge),
                  const SizedBox(height: 18),
                  Text(
                    _correct >= mathsClearScore(_total)
                        ? 'Level cleared and saved.'
                        : '${mathsClearScore(_total)} right clears the level. Saved, so your teacher sees the practice.',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: widget.onExit,
                    child: const Text('Back to the path'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: widget.onExit,
        ),
        title: Text('${widget.level.title} · ${_index + 1}/$_total'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              children: [
                Text(
                  _sum.prompt,
                  textAlign: TextAlign.center,
                  style: _sum.prompt.length > 32
                      ? text.titleLarge
                      : text.headlineMedium,
                ),
                const SizedBox(height: 22),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.2,
                    children: [
                      for (final option in _sum.options)
                        _SumButton(
                          label: option,
                          selected: _picked == option,
                          correct: _picked != null && option == _sum.answer,
                          onTap: _picked == null ? () => _choose(option) : null,
                        ),
                    ],
                  ),
                ),
                if (_picked != null)
                  FilledButton(
                    onPressed: _next,
                    child: Text(
                      _index + 1 == _total ? 'See score' : 'Next sum',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SumButton extends StatelessWidget {
  final String label;
  final bool selected;
  final bool correct;
  final VoidCallback? onTap;

  const _SumButton({
    required this.label,
    required this.selected,
    required this.correct,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = correct
        ? AppColors.success
        : selected
        ? AppColors.danger
        : AppColors.worldExams;
    return Material(
      color: correct ? AppColors.successSoft : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color, width: 2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: Text(label, style: Theme.of(context).textTheme.headlineSmall),
        ),
      ),
    );
  }
}

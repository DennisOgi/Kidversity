import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_state.dart';
import '../../services/foundation_review_service.dart';
import '../../services/mandarin_audio_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/error_boundary.dart';

class ReviewQueueScreen extends ConsumerStatefulWidget {
  const ReviewQueueScreen({super.key});

  @override
  ConsumerState<ReviewQueueScreen> createState() => _ReviewQueueScreenState();
}

class _ReviewQueueScreenState extends ConsumerState<ReviewQueueScreen> {
  String _type = 'all';
  String? _lessonId;

  Future<void> _review(
    BuildContext context,
    FoundationReviewItem item,
    String verdict, {
    String notes = '',
    Map<String, dynamic> corrections = const {},
  }) async {
    final result = await FoundationReviewService.instance.review(
      item: item,
      verdict: verdict,
      notes: notes,
      corrections: corrections,
    );
    if (!context.mounted) return;
    if (result.isFailure) {
      context.showErrorSnackbar(result.error ?? 'Review could not be saved.');
      return;
    }
    ref.invalidate(foundationReviewQueueProvider);
    ref.invalidate(mandarinCourseProvider);
    context.showSuccessSnackbar(
      'Item ${verdict == 'rejected' ? 'rejected' : 'reviewed'}.',
    );
  }

  Future<void> _lessonAction(BuildContext context, String action) async {
    final lessonId = _lessonId;
    if (lessonId == null) {
      context.showErrorSnackbar('Choose a lesson first.');
      return;
    }
    final result = action == 'submit'
        ? await FoundationReviewService.instance.submitLesson(lessonId)
        : await FoundationReviewService.instance.publishLesson(lessonId);
    if (!context.mounted) return;
    if (result.isFailure) {
      context.showErrorSnackbar(
        action == 'submit'
            ? 'This lesson could not be submitted.'
            : 'Complete every review before publishing.',
      );
      return;
    }
    ref.invalidate(foundationReviewQueueProvider);
    ref.invalidate(mandarinCourseProvider);
    context.showSuccessSnackbar(
      action == 'submit' ? 'Lesson submitted for review.' : 'Lesson published.',
    );
  }

  Future<void> _generateAudio(
    BuildContext context,
    FoundationReviewItem item,
  ) async {
    final result = await FoundationReviewService.instance.generateAudio(
      item.id,
    );
    if (!context.mounted) return;
    if (result.isFailure) {
      context.showErrorSnackbar(
        result.error ?? 'Could not generate this audio.',
      );
      return;
    }
    ref.invalidate(foundationReviewQueueProvider);
    context.showSuccessSnackbar('Google Mandarin audio generated.');
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(foundationReviewQueueProvider);
    return ShellScrollView(
      children: [
        Text(
          'Mandarin review',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          'Check each lesson for accurate Chinese, Pinyin, meaning, and audio.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 22),
        queue.when(
          loading: () =>
              const LoadingIndicator(message: 'Loading review queue…'),
          error: (error, _) => ErrorDisplay(
            message: 'The review queue could not be loaded.',
            error: error,
            onRetry: () => ref.invalidate(foundationReviewQueueProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const _EmptyQueue();
            }
            final lessonIds =
                items.map((item) => item.lessonId).toSet().toList()..sort();
            final types = items.map((item) => item.type).toSet().toList()
              ..sort();
            final filtered = items
                .where(
                  (item) =>
                      (_type == 'all' || item.type == _type) &&
                      (_lessonId == null || item.lessonId == _lessonId),
                )
                .toList(growable: false);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownButton<String>(
                      value: _type,
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('All content'),
                        ),
                        for (final type in types)
                          DropdownMenuItem(
                            value: type,
                            child: Text(type.toUpperCase()),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _type = value ?? 'all'),
                    ),
                    DropdownButton<String?>(
                      value: _lessonId,
                      hint: const Text('All lessons'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All lessons'),
                        ),
                        for (final lessonId in lessonIds)
                          DropdownMenuItem<String?>(
                            value: lessonId,
                            child: Text(_lessonLabel(lessonId)),
                          ),
                      ],
                      onChanged: (value) => setState(() => _lessonId = value),
                    ),
                    OutlinedButton(
                      onPressed: _lessonId == null
                          ? null
                          : () => _lessonAction(context, 'submit'),
                      child: const Text('Submit lesson'),
                    ),
                    FilledButton(
                      onPressed: _lessonId == null
                          ? null
                          : () => _lessonAction(context, 'publish'),
                      child: const Text('Publish lesson'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                for (final item in filtered) ...[
                  _ReviewCard(
                    item: item,
                    onGenerateAudio: item.type == 'audio'
                        ? () => _generateAudio(context, item)
                        : null,
                    onApprove: item.type == 'audio' && !item.audioGenerated
                        ? null
                        : () => _review(context, item, 'approved'),
                    onReject: () => _review(context, item, 'rejected'),
                    onCorrect: () async {
                      final correction = await showDialog<_Correction>(
                        context: context,
                        builder: (_) => _CorrectionDialog(item: item),
                      );
                      if (correction == null || !context.mounted) return;
                      await _review(
                        context,
                        item,
                        'corrected',
                        notes: correction.notes,
                        corrections: correction.values,
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final FoundationReviewItem item;
  final VoidCallback? onApprove;
  final VoidCallback onCorrect;
  final VoidCallback onReject;
  final VoidCallback? onGenerateAudio;

  const _ReviewCard({
    required this.item,
    required this.onApprove,
    required this.onCorrect,
    required this.onReject,
    this.onGenerateAudio,
  });

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _StatusChip(label: item.type.toUpperCase()),
            const SizedBox(width: 8),
            Text(
              _lessonLabel(item.lessonId),
              style: const TextStyle(color: AppColors.muted),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Play Mandarin',
              onPressed:
                  item.chinese.isEmpty ||
                      item.type == 'audio' && item.audioUrl == null
                  ? null
                  : () => MandarinAudioService.instance.play(
                      text: item.chinese,
                      audioUrl: item.audioUrl,
                      rate: 0.8,
                    ),
              icon: const Icon(Icons.volume_up_rounded, color: AppColors.jade),
            ),
          ],
        ),
        if (item.prompt.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(item.prompt, style: Theme.of(context).textTheme.titleMedium),
        ],
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final cells = [
              _LanguageCell(label: 'CHINESE / ANSWER', value: item.chinese),
              _LanguageCell(label: 'PINYIN', value: item.pinyin),
              _LanguageCell(label: 'ENGLISH / NOTE', value: item.english),
            ];
            if (constraints.maxWidth < 620) {
              return Column(
                children: [
                  for (var index = 0; index < cells.length; index++) ...[
                    cells[index],
                    if (index < cells.length - 1) const SizedBox(height: 10),
                  ],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < cells.length; index++) ...[
                  Expanded(child: cells[index]),
                  if (index < cells.length - 1) const SizedBox(width: 10),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 10,
          runSpacing: 10,
          children: [
            if (onGenerateAudio != null)
              OutlinedButton.icon(
                onPressed: onGenerateAudio,
                icon: const Icon(Icons.graphic_eq_rounded),
                label: Text(
                  item.audioGenerated ? 'Regenerate audio' : 'Generate audio',
                ),
              ),
            OutlinedButton.icon(
              onPressed: onReject,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Reject'),
            ),
            OutlinedButton.icon(
              onPressed: onCorrect,
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Correct'),
            ),
            FilledButton.icon(
              onPressed: onApprove,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Approve'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _LanguageCell extends StatelessWidget {
  final String label;
  final String value;

  const _LanguageCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 88),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: AppColors.backgroundAlt,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.muted,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          value.isEmpty ? '—' : value,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _StatusChip extends StatelessWidget {
  final String label;

  const _StatusChip({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.cinnabarSoft,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        color: AppColors.cinnabar,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue();

  @override
  Widget build(BuildContext context) => const GlassCard(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(Icons.verified_rounded, size: 52, color: AppColors.jade),
          SizedBox(height: 14),
          Text(
            'Review queue is clear',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 5),
          Text('New lessons and corrections will appear here.'),
        ],
      ),
    ),
  );
}

String _lessonLabel(String id) {
  final match = RegExp(r'l(\d+)$').firstMatch(id);
  final sequence = int.tryParse(match?.group(1) ?? '');
  return sequence == null ? 'Lesson' : 'Lesson $sequence';
}

class _Correction {
  final Map<String, dynamic> values;
  final String notes;

  const _Correction(this.values, this.notes);
}

class _CorrectionDialog extends StatefulWidget {
  final FoundationReviewItem item;

  const _CorrectionDialog({required this.item});

  @override
  State<_CorrectionDialog> createState() => _CorrectionDialogState();
}

class _CorrectionDialogState extends State<_CorrectionDialog> {
  late final TextEditingController _chinese;
  late final TextEditingController _pinyin;
  late final TextEditingController _english;
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    _chinese = TextEditingController(text: widget.item.chinese);
    _pinyin = TextEditingController(text: widget.item.pinyin);
    _english = TextEditingController(text: widget.item.english);
  }

  @override
  void dispose() {
    _chinese.dispose();
    _pinyin.dispose();
    _english.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Correct before approval'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _chinese,
            decoration: const InputDecoration(labelText: 'Chinese / answer'),
          ),
          TextField(
            controller: _pinyin,
            decoration: const InputDecoration(labelText: 'Pinyin'),
          ),
          TextField(
            controller: _english,
            decoration: const InputDecoration(
              labelText: 'English / explanation',
            ),
          ),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(labelText: 'Review note'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          _Correction({
            'chinese': _chinese.text.trim(),
            'pinyin': _pinyin.text.trim(),
            'english': _english.text.trim(),
            'title': _chinese.text.trim(),
            'pattern': widget.item.prompt,
            'audio_text': _chinese.text.trim(),
            'answer': _chinese.text.trim(),
            'explanation': _english.text.trim(),
          }, _notes.text.trim()),
        ),
        child: const Text('Save correction'),
      ),
    ],
  );
}

import 'package:flutter/material.dart';

import '../../services/exam_bank_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/surfaces.dart';

/// Lets a teacher copy Sdash questions into Supabase so later practice
/// does not spend API credits.
class ExamBankCard extends StatefulWidget {
  const ExamBankCard({super.key});

  @override
  State<ExamBankCard> createState() => _ExamBankCardState();
}

class _ExamBankCardState extends State<ExamBankCard> {
  ExamBankStatus? _status;
  bool _loading = true;
  bool _filling = false;
  String? _note;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final status = await ExamBankService.instance.status();
    if (!mounted) return;
    setState(() {
      _status = status;
      _loading = false;
    });
  }

  Future<void> _fill() async {
    setState(() {
      _filling = true;
      _note = 'Copying papers into Kidversity…';
    });
    var added = 0;
    var rounds = 0;
    while (mounted && rounds < 40) {
      final result = await ExamBankService.instance.harvest(rounds: 8);
      added += result.added;
      rounds += 1;
      if (!mounted) return;
      setState(() {
        _status = ExamBankStatus(
          questions: result.questions,
          exams: _status?.exams ?? 0,
          subjects: _status?.subjects ?? 0,
          papers: _status?.papers ?? 0,
          harvested: _status?.harvested ?? 0,
          exhausted: _status?.exhausted ?? 0,
        );
        _note = result.message ??
            (result.done
                ? 'Saved ${result.questions} questions.'
                : 'Saved ${result.questions} so far…');
      });
      if (result.done || result.message != null && result.added == 0) {
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _filling = false;
      _note ??= added == 0
          ? 'No new questions were copied this time.'
          : 'Copied $added more questions.';
    });
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final questions = _status?.questions ?? 0;
    final papers = _status?.papers ?? 0;
    return LiftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Exam bank', style: text.titleMedium),
          const SizedBox(height: 6),
          Text(
            _loading
                ? 'Checking the saved papers…'
                : questions == 0
                ? 'Copy each Sdash paper (exam, subject, and year) into Kidversity. Students then practise from one paper at a time, which keeps the monthly API bill down.'
                : '$papers papers and $questions questions are saved. Keep filling until every exam, subject, and year is copied.',
            style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
          ),
          if (_note != null) ...[
            const SizedBox(height: 8),
            Text(_note!, style: text.bodySmall),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _filling ? null : _fill,
            icon: _filling
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_download_outlined),
            label: Text(_filling ? 'Copying…' : 'Save papers to Kidversity'),
          ),
        ],
      ),
    );
  }
}

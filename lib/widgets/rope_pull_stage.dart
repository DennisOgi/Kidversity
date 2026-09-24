import 'package:flutter/material.dart';

import '../models/rope_pull_models.dart';
import '../theme/app_colors.dart';
import 'rope_arena.dart';
import 'rope_pull_arena.dart';

/// Wide-screen class view: a question on each side, the rope in the middle.
class RopePullStage extends StatelessWidget {
  final RopePullSnapshot snap;
  final RopeArenaController controller;
  final double remaining;
  final double seconds;
  final bool reveal;
  final RopePullQuestion? blueQuestion;
  final RopePullQuestion? redQuestion;

  const RopePullStage({
    super.key,
    required this.snap,
    required this.controller,
    required this.remaining,
    required this.seconds,
    required this.reveal,
    required this.blueQuestion,
    required this.redQuestion,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final title = 'TUG OF WAR · ${snap.room.roundLabel.toUpperCase()}';
    final center = _CenterStage(
      snap: snap,
      controller: controller,
      remaining: remaining,
      seconds: seconds,
    );
    final blue = _TeamBoard(
      name: 'Indigo',
      color: kRopeIndigo,
      count: snap.blue.length,
      question: blueQuestion,
      reveal: reveal,
    );
    final red = _TeamBoard(
      name: 'Teal',
      color: kRopeTeal,
      count: snap.red.length,
      question: redQuestion,
      reveal: reveal,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: ropePullText(
                    size: wide ? 22 : 16,
                    weight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: AppColors.worldExams,
                  ),
                ),
              ),
              Text(
                'Round ${snap.room.currentRound + 1}/${snap.room.roundCount}',
                style: ropePullText(size: 14, weight: FontWeight.w800),
              ),
              const SizedBox(width: 12),
              Text(
                snap.room.joinCode,
                style: ropePullText(
                  size: 16,
                  weight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: wide
                ? Row(
                    children: [
                      Expanded(flex: 5, child: blue),
                      const SizedBox(width: 12),
                      Expanded(flex: 4, child: center),
                      const SizedBox(width: 12),
                      Expanded(flex: 5, child: red),
                    ],
                  )
                : Column(
                    children: [
                      SizedBox(height: 180, child: center),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(child: blue),
                            const SizedBox(width: 8),
                            Expanded(child: red),
                          ],
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

class _CenterStage extends StatelessWidget {
  final RopePullSnapshot snap;
  final RopeArenaController controller;
  final double remaining;
  final double seconds;

  const _CenterStage({
    required this.snap,
    required this.controller,
    required this.remaining,
    required this.seconds,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.line),
          ),
          child: Text(
            _clock(remaining),
            style: ropePullText(size: 22, weight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: RopePullKitScene(controller: controller)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ScoreDot(label: '${snap.blue.length}', color: kRopeIndigo),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                '${snap.blueTugs}  –  ${snap.redTugs}',
                style: ropePullText(size: 20, weight: FontWeight.w800),
              ),
            ),
            _ScoreDot(label: '${snap.red.length}', color: kRopeTeal),
          ],
        ),
      ],
    );
  }
}

class _TeamBoard extends StatelessWidget {
  final String name;
  final Color color;
  final int count;
  final RopePullQuestion? question;
  final bool reveal;

  const _TeamBoard({
    required this.name,
    required this.color,
    required this.count,
    required this.question,
    required this.reveal,
  });

  @override
  Widget build(BuildContext context) {
    final prompt = question?.isExamPrompt == true
        ? question!.prompt!
        : (question?.simplified ?? '');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  name,
                  style: ropePullText(
                    size: 16,
                    weight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const Spacer(),
                _ScoreDot(label: '$count', color: color),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              prompt,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: ropePullText(
                size: 22,
                weight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: question == null
                  ? const SizedBox.shrink()
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final options = question!.options;
                        return GridView.count(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: constraints.maxWidth > 280
                              ? 2.4
                              : 1.8,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            for (final option in options)
                              _ChoiceFace(
                                label: option,
                                color: color,
                                correct: reveal && option == question!.answer,
                                dim: reveal && option != question!.answer,
                              ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceFace extends StatelessWidget {
  final String label;
  final Color color;
  final bool correct;
  final bool dim;

  const _ChoiceFace({
    required this.label,
    required this.color,
    required this.correct,
    required this.dim,
  });

  @override
  Widget build(BuildContext context) {
    final border = correct ? AppColors.success : color.withValues(alpha: 0.45);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: correct ? AppColors.successSoft : AppColors.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: correct ? 2 : 1),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: ropePullText(
              size: 16,
              weight: FontWeight.w800,
              color: dim ? AppColors.muted : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreDot extends StatelessWidget {
  final String label;
  final Color color;

  const _ScoreDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        label,
        style: ropePullText(
          size: 13,
          weight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

String _clock(double remaining) {
  final total = remaining.ceil().clamp(0, 99);
  final minutes = total ~/ 60;
  final secs = total % 60;
  return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/navigation.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/common.dart';
import '../../../widgets/surfaces.dart';
import 'lab_catalog.dart';
import 'lab_frame.dart';

class LabsHubScreen extends StatelessWidget {
  const LabsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ShellScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  tooltip: 'Home',
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => popOrGo(context, AppRoutes.studentPath),
                ),
                const PageIntro(
                  eyebrow: 'Labs',
                  title: 'Experiments you can run',
                  body:
                      'Each bench explains the idea, then lets you change one thing and watch what happens. These are teaching models for class. They are separate from past questions, and nothing here is scored.',
                ),
                const SizedBox(height: 22),
                for (final subject in labSubjects) ...[
                  Row(
                    children: [
                      Text(
                        subject,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      Text(
                        '${labCatalog.where((lab) => lab.subject == subject).length} benches',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _LabGrid(
                    labs: [
                      for (final lab in labCatalog)
                        if (lab.subject == subject) lab,
                    ],
                  ),
                  const SizedBox(height: 22),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LabGrid extends StatelessWidget {
  final List<LabSpec> labs;
  const _LabGrid({required this.labs});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980
            ? 3
            : constraints.maxWidth >= 680
            ? 2
            : 1;
        final width = (constraints.maxWidth - 14 * (columns - 1)) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final lab in labs)
              SizedBox(
                width: width,
                child: _LabCard(lab: lab),
              ),
          ],
        );
      },
    );
  }
}

class _LabCard extends StatelessWidget {
  final LabSpec lab;
  const _LabCard({required this.lab});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return LiftCard(
      onTap: () => context.push(AppRoutes.studentLab(lab.id)),
      padding: EdgeInsets.zero,
      hoverBorder: lab.color.withValues(alpha: 0.5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 92,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    lab.color.withValues(alpha: 0.22),
                    lab.color.withValues(alpha: 0.06),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -18,
                    top: -22,
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: lab.color.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(lab.icon, color: lab.color),
                        ),
                        const Spacer(),
                        Eyebrow(lab.subject, color: lab.color),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lab.title, style: text.titleMedium),
                  const SizedBox(height: 4),
                  Text(lab.blurb, style: text.bodyMedium, maxLines: 3),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

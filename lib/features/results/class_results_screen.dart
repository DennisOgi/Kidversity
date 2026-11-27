import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/app_state.dart';
import '../../models/results_models.dart';
import '../../services/results_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/role_style.dart';
import '../../widgets/error_boundary.dart';
import '../../widgets/kv_ui.dart';

/// The teacher's whole class: each pupil's latest official score against
/// their target in every subject, with a way into each pupil's profile.
class ClassResultsScreen extends ConsumerWidget {
  /// Where a pupil's profile opens, e.g. `/teacher/pupil/<id>`.
  final String Function(String studentId) profileRoute;

  const ClassResultsScreen({super.key, required this.profileRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classInfo = ref.watch(teacherClassInfoProvider);
    return classInfo.when(
      loading: () => const KvPage(
        children: [LoadingIndicator(message: 'Opening your class…')],
      ),
      error: (error, _) => KvPage(
        children: [
          ErrorDisplay(
            message: 'Your class could not be loaded.',
            error: error,
            onRetry: () => ref.invalidate(teacherClassInfoProvider),
          ),
        ],
      ),
      data: (info) {
        if (info == null) {
          return const KvPage(
            children: [
              KvCard(
                child: Text(
                  'Create your class first, then results for every pupil show here.',
                ),
              ),
            ],
          );
        }
        return _ClassResultsBody(
          classId: info.id,
          className: info.name,
          profileRoute: profileRoute,
        );
      },
    );
  }
}

class _ClassResultsBody extends ConsumerWidget {
  final String classId;
  final String className;
  final String Function(String studentId) profileRoute;

  const _ClassResultsBody({
    required this.classId,
    required this.className,
    required this.profileRoute,
  });

  Future<void> _addSubject(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Add a subject'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 60,
          textCapitalization: TextCapitalization.words,
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
    if (name == null || name.trim().isEmpty) return;
    try {
      await ResultsService.instance.addSubject(name.trim());
      ref.invalidate(classResultsProvider(classId));
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
    final results = ref.watch(classResultsProvider(classId));
    return results.when(
      loading: () => const KvPage(
        children: [LoadingIndicator(message: 'Loading class results…')],
      ),
      error: (error, _) => KvPage(
        children: [
          ErrorDisplay(
            message: 'Class results could not be loaded.',
            error: error,
            onRetry: () => ref.invalidate(classResultsProvider(classId)),
          ),
        ],
      ),
      data: (data) => KvPage(
        onRefresh: () async =>
            ref.refresh(classResultsProvider(classId).future),
        children: [
          HeroBanner(
            colors: HeroColors.teacher,
            eyebrow: ['Whole class', ?data.termLabel].join(' · '),
            title: 'Your class, growing together.',
            body:
                '$className · Targets and official scores for every pupil. Open a profile to set targets and add scores.',
            actions: [
              SunButton(
                label: 'Upload scores',
                onPressed: () => context.go('/teacher/results/upload'),
              ),
              HeroGhostButton(
                label: 'Add a subject',
                onPressed: () => _addSubject(context, ref),
              ),
            ],
          ),
          AdaptiveGrid(
            minTileWidth: 170,
            maxColumns: 3,
            children: [
              MetricTile(
                tint: AppTint.mint,
                icon: Icons.groups_rounded,
                label: 'Pupils',
                value: '${data.pupils.length}',
                caption: className,
              ),
              MetricTile(
                tint: data.needSupport == 0 ? AppTint.sky : AppTint.coral,
                icon: Icons.support_rounded,
                label: 'Need support',
                value: '${data.needSupport}',
                caption: 'Below target in a subject',
              ),
              MetricTile(
                tint: AppTint.violet,
                icon: Icons.menu_book_rounded,
                label: 'Subjects',
                value: '${data.subjects.length}',
                caption: 'Your school reports on',
              ),
            ],
          ),
          _Glance(data: data, profileRoute: profileRoute),
        ],
      ),
    );
  }
}

class _Glance extends StatelessWidget {
  final ClassResults data;
  final String Function(String studentId) profileRoute;

  const _Glance({required this.data, required this.profileRoute});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const KvSectionTitle(
          title: 'Your class at a glance',
          subtitle: 'Latest official score / teacher target, this term.',
        ),
        if (data.pupils.isEmpty)
          const KvCard(
            child: Text(
              'No pupils yet. Share your class code so pupils can join.',
              style: TextStyle(color: AppColors.inkSoft),
            ),
          )
        else if (data.subjects.isEmpty)
          const KvCard(
            child: Text(
              'Add the subjects your school reports on to start tracking results.',
              style: TextStyle(color: AppColors.inkSoft),
            ),
          )
        else if (compact)
          for (final pupil in data.pupils)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PupilCard(
                pupil: pupil,
                subjects: data.subjects,
                onOpen: () => context.push(profileRoute(pupil.studentId)),
              ),
            )
        else
          KvCard(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: box.maxWidth),
                  child: DataTable(
                    headingTextStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSoft,
                      fontSize: 13,
                    ),
                    columnSpacing: 28,
                    dataRowMinHeight: 56,
                    dataRowMaxHeight: 64,
                    columns: [
                      const DataColumn(label: Text('Pupil')),
                      for (final s in data.subjects)
                        DataColumn(label: Text(s.name)),
                      const DataColumn(label: Text('Review')),
                      const DataColumn(label: Text('')),
                    ],
                    rows: [
                      for (final pupil in data.pupils)
                        DataRow(
                          cells: [
                            DataCell(_PupilName(pupil: pupil)),
                            for (final s in data.subjects)
                              DataCell(_ScoreText(cell: pupil.scores[s.id])),
                            DataCell(_ReviewChip(pupil: pupil)),
                            DataCell(
                              OutlinedButton(
                                onPressed: () =>
                                    context.push(profileRoute(pupil.studentId)),
                                child: const Text(
                                  'Open profile',
                                  softWrap: false,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PupilName extends StatelessWidget {
  final ClassPupilResults pupil;

  const _PupilName({required this.pupil});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(pupil.avatarEmoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Text(
          pupil.displayName,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

class _ScoreText extends StatelessWidget {
  final ScoreCell? cell;

  const _ScoreText({required this.cell});

  @override
  Widget build(BuildContext context) {
    final c = cell;
    final latest = c?.latest;
    final target = c?.target;
    final color = switch (c?.status) {
      TargetStatus.below => const Color(0xFFA61F2D),
      TargetStatus.onTarget || TargetStatus.above => AppTint.mint.ink,
      _ => AppColors.inkSoft,
    };
    return Text.rich(
      softWrap: false,
      TextSpan(
        children: [
          TextSpan(
            text: latest == null ? '–' : '${fmtScore(latest)}%',
            style: TextStyle(fontWeight: FontWeight.w800, color: color),
          ),
          TextSpan(
            text: target == null ? ' / –' : ' / ${fmtScore(target)}%',
            style: const TextStyle(color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _ReviewChip extends StatelessWidget {
  final ClassPupilResults pupil;

  const _ReviewChip({required this.pupil});

  @override
  Widget build(BuildContext context) {
    final anyData = pupil.scores.values.any((c) => c.latest != null);
    final status = !anyData
        ? const StatusChip(label: 'No scores yet', tint: AppTint.slate)
        : pupil.needsSupport
        ? const StatusChip(label: 'Needs support', tint: StatusChip.alert)
        : const StatusChip(label: 'On track', tint: AppTint.mint);
    if (pupil.openSupport == 0) return status;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        status,
        const SizedBox(width: 6),
        Tooltip(
          message:
              '${pupil.openSupport} open support action${pupil.openSupport == 1 ? '' : 's'}',
          child: StatusChip(
            label:
                '${pupil.openSupport} plan${pupil.openSupport == 1 ? '' : 's'}',
            tint: AppTint.sky,
            icon: Icons.volunteer_activism_rounded,
          ),
        ),
      ],
    );
  }
}

class _PupilCard extends StatelessWidget {
  final ClassPupilResults pupil;
  final List<SchoolSubject> subjects;
  final VoidCallback onOpen;

  const _PupilCard({
    required this.pupil,
    required this.subjects,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return KvCard(
      onTap: onOpen,
      semanticLabel: 'Open ${pupil.displayName}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(pupil.avatarEmoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  pupil.displayName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              _ReviewChip(pupil: pupil),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              for (final s in subjects)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${s.name}  ',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.inkSoft,
                      ),
                    ),
                    _ScoreText(cell: pupil.scores[s.id]),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onOpen,
              child: const Text('Open profile'),
            ),
          ),
        ],
      ),
    );
  }
}

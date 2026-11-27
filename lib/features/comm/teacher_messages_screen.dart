import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../services/comm_service.dart';
import '../../services/results_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/role_style.dart';
import '../../widgets/error_boundary.dart';
import '../../widgets/kv_ui.dart';
import 'compose_dialog.dart';
import 'message_widgets.dart';

/// Communication Book for the teacher's class: announcements and private
/// guardian updates, with how many parents have viewed and acknowledged.
class TeacherMessagesScreen extends ConsumerWidget {
  const TeacherMessagesScreen({super.key});

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
              children: [
                KvCard(
                  child: Text(
                    'Create your class first, then you can message families.',
                  ),
                ),
              ],
            )
          : _Book(classId: cls.id, className: cls.name),
    );
  }
}

class _Book extends ConsumerStatefulWidget {
  final String classId;
  final String className;

  const _Book({required this.classId, required this.className});

  @override
  ConsumerState<_Book> createState() => _BookState();
}

class _BookState extends ConsumerState<_Book> {
  String _filter = 'all';

  Future<void> _compose() async {
    final cls = await ref.read(classResultsProvider(widget.classId).future);
    if (!mounted) return;
    final sent = await showComposeDialog(
      context,
      ref,
      classId: widget.classId,
      pupils: [
        for (final p in cls.pupils) (id: p.studentId, name: p.displayName),
      ],
    );
    if (sent && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message sent')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(classMessagesProvider(widget.classId));
    return KvPage(
      onRefresh: () async =>
          ref.refresh(classMessagesProvider(widget.classId).future),
      children: [
        HeroBanner(
          colors: HeroColors.teacher,
          eyebrow: 'Communication Book · ${widget.className}',
          title: 'Keep every family in the loop.',
          body:
              'Send class announcements or a private update to one pupil\'s family, and see who has read and acknowledged it.',
          actions: [SunButton(label: 'New message', onPressed: _compose)],
        ),
        data.when(
          loading: () => const LoadingIndicator(message: 'Loading messages…'),
          error: (e, _) => ErrorDisplay(
            message: 'Messages could not be loaded.',
            error: e,
            onRetry: () =>
                ref.invalidate(classMessagesProvider(widget.classId)),
          ),
          data: (book) {
            final shown = book.messages
                .where(
                  (m) => switch (_filter) {
                    'announcement' => !m.private,
                    'private' => m.private,
                    'ack' => m.needsAck && m.acknowledged < m.recipients,
                    _ => true,
                  },
                )
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Reach(guardians: book.guardiansLinked, pupils: book.pupils),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in const [
                      ('all', 'All'),
                      ('announcement', 'Announcements'),
                      ('private', 'Private updates'),
                      ('ack', 'Awaiting acknowledgement'),
                    ])
                      ChoiceChip(
                        label: Text(f.$2),
                        selected: _filter == f.$1,
                        showCheckmark: false,
                        selectedColor: AppTint.mint.ink,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _filter == f.$1 ? Colors.white : AppColors.ink,
                        ),
                        onSelected: (_) => setState(() => _filter = f.$1),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (shown.isEmpty)
                  KvCard(
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        const TintIcon(
                          tint: AppTint.mint,
                          icon: Icons.forum_rounded,
                          size: 56,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          book.messages.isEmpty
                              ? 'No messages yet'
                              : 'Nothing here',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          book.messages.isEmpty
                              ? 'Send your first announcement to the class\'s families.'
                              : 'Try another filter.',
                          style: const TextStyle(color: AppColors.inkSoft),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  )
                else
                  for (final m in shown)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TeacherMessageCard(
                        message: m,
                        onTap: () => context.push('/teacher/messages/${m.id}'),
                      ),
                    ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Reach extends StatelessWidget {
  final int guardians;
  final int pupils;

  const _Reach({required this.guardians, required this.pupils});

  @override
  Widget build(BuildContext context) {
    return KvCard(
      tint: guardians == 0 ? AppTint.sun : AppTint.mint,
      child: Row(
        children: [
          TintIcon(
            tint: guardians == 0 ? AppTint.sun : AppTint.mint,
            icon: Icons.family_restroom_rounded,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guardians == 0
                      ? 'No parents are linked yet'
                      : '$guardians parent${guardians == 1 ? '' : 's'} linked for $pupils pupil${pupils == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const Text(
                  'Messages reach parents who have linked to their child with the family code from the child\'s Me page.',
                  style: TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 13,
                    height: 1.4,
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

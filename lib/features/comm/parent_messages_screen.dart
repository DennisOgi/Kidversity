import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/comm_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/role_style.dart';
import '../../widgets/error_boundary.dart';
import '../../widgets/kv_ui.dart';
import 'message_widgets.dart';

/// Parent inbox: announcements and private updates from their children's
/// teachers, newest first, with unread and acknowledge markers.
class ParentMessagesScreen extends ConsumerWidget {
  const ParentMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(commInboxProvider);
    return KvPage(
      onRefresh: () async => ref.refresh(commInboxProvider.future),
      children: [
        inbox.when(
          loading: () => const LoadingIndicator(message: 'Loading messages…'),
          error: (e, _) => ErrorDisplay(
            message: 'Messages could not be loaded.',
            error: e,
            onRetry: () => ref.invalidate(commInboxProvider),
          ),
          data: (items) {
            final unread = items.where((m) => m.unread).length;
            final toAck = items.where((m) => m.awaitingMyAck).length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HeroBanner(
                  colors: HeroColors.parent,
                  eyebrow: 'Communication Book',
                  title: unread == 0
                      ? 'You are all caught up.'
                      : '$unread new message${unread == 1 ? '' : 's'}',
                  body: toAck == 0
                      ? 'Announcements and updates from your children\'s teachers.'
                      : '$toAck message${toAck == 1 ? ' needs' : 's need'} your acknowledgement.',
                ),
                const SizedBox(height: 20),
                if (items.isEmpty)
                  const KvCard(
                    child: Row(
                      children: [
                        TintIcon(
                          tint: AppTint.coral,
                          icon: Icons.mark_email_unread_rounded,
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'No messages yet. When your child\'s teacher sends an announcement or an update, it appears here.',
                            style: TextStyle(
                              color: AppColors.inkSoft,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (final m in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InboxCard(
                        message: m,
                        onTap: () => context.push('/parent/messages/${m.id}'),
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

/// Small card for the parent home: unread messages at a glance.
class ParentInboxCard extends ConsumerWidget {
  const ParentInboxCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(commInboxProvider).value ?? const <CommSummary>[];
    final unread = items.where((m) => m.unread).length;
    final toAck = items.where((m) => m.awaitingMyAck).length;
    final latest = items.isEmpty ? null : items.first;
    return KvCard(
      tint: unread > 0 || toAck > 0 ? AppTint.coral : AppTint.sky,
      onTap: () => context.go('/parent/messages'),
      semanticLabel: 'Open messages from school',
      child: Row(
        children: [
          Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: TintIcon(
              tint: unread > 0 ? AppTint.coral : AppTint.sky,
              icon: Icons.forum_rounded,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Messages from school',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  toAck > 0
                      ? '$toAck to acknowledge · ${latest?.subject ?? ''}'
                      : unread > 0
                      ? '$unread unread · ${latest?.subject ?? ''}'
                      : latest == null
                      ? 'Announcements and updates from teachers'
                      : 'Latest: ${latest.subject}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded, color: AppColors.inkSoft),
        ],
      ),
    );
  }
}

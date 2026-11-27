import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/comm_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/role_style.dart';
import '../../widgets/error_boundary.dart';
import '../../widgets/kv_ui.dart';
import 'message_widgets.dart';

/// One message. Teachers see every parent's viewed and acknowledged state;
/// parents mark it viewed by opening it, can acknowledge, and can reply.
class MessageDetailScreen extends ConsumerStatefulWidget {
  final String messageId;
  final List<Color> heroColors;

  const MessageDetailScreen({
    super.key,
    required this.messageId,
    required this.heroColors,
  });

  @override
  ConsumerState<MessageDetailScreen> createState() =>
      _MessageDetailScreenState();
}

class _MessageDetailScreenState extends ConsumerState<MessageDetailScreen> {
  bool _markedViewed = false;
  bool _busy = false;
  String _filter = 'all';
  final _reply = TextEditingController();

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  void _maybeMarkViewed(CommMessage m) {
    if (_markedViewed || m.canManage || m.myViewedAt != null) return;
    _markedViewed = true;
    CommService.instance
        .markViewed(m.id)
        .then((_) {
          ref.invalidate(commInboxProvider);
        })
        .catchError((_) {});
  }

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(commMessageProvider(widget.messageId));
      ref.invalidate(commInboxProvider);
      ref.invalidate(classMessagesProvider);
      if (done != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(done)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(CommService.errorText(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final msg = ref.watch(commMessageProvider(widget.messageId));
    return msg.when(
      loading: () => const KvPage(
        children: [LoadingIndicator(message: 'Opening the message…')],
      ),
      error: (e, _) => KvPage(
        children: [
          ErrorDisplay(
            message: CommService.errorText(e),
            error: e,
            onRetry: () =>
                ref.invalidate(commMessageProvider(widget.messageId)),
          ),
        ],
      ),
      data: (m) {
        _maybeMarkViewed(m);
        final awaitingAck =
            !m.canManage && m.needsAck && m.myAcknowledgedAt == null;
        return KvPage(
          maxWidth: 900,
          onRefresh: () async =>
              ref.refresh(commMessageProvider(widget.messageId).future),
          children: [
            HeroBanner(
              colors: widget.heroColors,
              eyebrow: [
                m.private ? 'Private update' : 'Class announcement',
                ?m.className,
                if (m.private && m.student != null) 'about ${m.student}',
              ].join(' · '),
              title: m.subject,
              body: [
                if (m.author != null) 'From ${m.author}',
                commWhen(m.createdAt),
              ].join(' · '),
            ),
            KvCard(
              child: SelectableText(
                m.body,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: AppColors.ink,
                ),
              ),
            ),
            if (awaitingAck)
              KvCard(
                tint: AppTint.coral,
                child: Row(
                  children: [
                    const TintIcon(
                      tint: AppTint.coral,
                      icon: Icons.task_alt_rounded,
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Your child\'s teacher has asked you to confirm you have read this.',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () => CommService.instance.acknowledge(m.id),
                              done: 'Acknowledged. Thank you.',
                            ),
                      child: const Text('Acknowledge'),
                    ),
                  ],
                ),
              )
            else if (!m.canManage && m.needsAck)
              KvCard(
                tint: AppTint.mint,
                child: Row(
                  children: [
                    const TintIcon(
                      tint: AppTint.mint,
                      icon: Icons.check_circle_rounded,
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'You acknowledged this ${commWhen(m.myAcknowledgedAt)}.',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            if (m.canManage)
              _Receipts(
                message: m,
                filter: _filter,
                onFilter: (f) => setState(() => _filter = f),
              ),
            _Thread(
              message: m,
              controller: _reply,
              busy: _busy,
              onSend: () {
                final text = _reply.text.trim();
                if (text.isEmpty) return;
                _run(() async {
                  await CommService.instance.reply(m.id, text);
                  _reply.clear();
                }, done: 'Reply sent');
              },
            ),
          ],
        );
      },
    );
  }
}

class _Receipts extends StatelessWidget {
  final CommMessage message;
  final String filter;
  final ValueChanged<String> onFilter;

  const _Receipts({
    required this.message,
    required this.filter,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    final all = message.recipients;
    final viewed = all.where((r) => r.viewedAt != null).length;
    final acked = all.where((r) => r.acknowledgedAt != null).length;
    final shown = all
        .where(
          (r) => switch (filter) {
            'unviewed' => r.viewedAt == null,
            'unacked' => r.acknowledgedAt == null,
            _ => true,
          },
        )
        .toList();
    return KvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Who has seen it',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (all.isEmpty)
            const Text(
              'No parents are linked to this pupil or class yet, so nobody has received it. Parents link with the family code from their child\'s Me page.',
              style: TextStyle(color: AppColors.inkSoft, height: 1.4),
            )
          else ...[
            ReceiptBar(
              label: 'Viewed',
              value: viewed,
              total: all.length,
              color: AppTint.sky.ink,
            ),
            if (message.needsAck) ...[
              const SizedBox(height: 6),
              ReceiptBar(
                label: 'Acknowledged',
                value: acked,
                total: all.length,
                color: AppTint.mint.ink,
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: [
                for (final f in [
                  ('all', 'Everyone ${all.length}'),
                  ('unviewed', 'Not viewed ${all.length - viewed}'),
                  if (message.needsAck)
                    ('unacked', 'Not acknowledged ${all.length - acked}'),
                ])
                  ChoiceChip(
                    label: Text(f.$2),
                    selected: filter == f.$1,
                    showCheckmark: false,
                    selectedColor: AppTint.mint.ink,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: filter == f.$1 ? Colors.white : AppColors.ink,
                    ),
                    onSelected: (_) => onFilter(f.$1),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (final r in shown)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFEDEFF5))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.guardian,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Parent of ${r.student}',
                            style: const TextStyle(
                              color: AppColors.inkSoft,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _Tick(label: 'Viewed', at: r.viewedAt),
                    if (message.needsAck) ...[
                      const SizedBox(width: 16),
                      _Tick(label: 'Acknowledged', at: r.acknowledgedAt),
                    ],
                  ],
                ),
              ),
            if (shown.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Everyone here is done. 🎉',
                  style: TextStyle(color: AppColors.inkSoft),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Tick extends StatelessWidget {
  final String label;
  final DateTime? at;

  const _Tick({required this.label, required this.at});

  @override
  Widget build(BuildContext context) {
    final done = at != null;
    return SizedBox(
      width: 120,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: done ? AppTint.mint.ink : AppColors.inkSoft,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: done ? AppColors.ink : AppColors.inkSoft,
                  ),
                ),
                if (done)
                  Text(
                    commWhen(at),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkSoft,
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

class _Thread extends StatelessWidget {
  final CommMessage message;
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;

  const _Thread({
    required this.message,
    required this.controller,
    required this.busy,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final replies = message.replies;
    return KvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message.canManage ? 'Replies' : 'Reply to the teacher',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (!message.canManage && !message.private)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Your reply goes to the teacher. Other parents do not see it.',
                style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
              ),
            ),
          const SizedBox(height: 12),
          if (replies.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'No replies yet.',
                style: TextStyle(color: AppColors.inkSoft),
              ),
            ),
          for (final r in replies)
            Align(
              alignment: r.mine ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 560),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: r.mine
                      ? AppTint.mint.soft
                      : (r.fromStaff
                            ? AppTint.sky.soft
                            : const Color(0xFFF3F4F8)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r.mine ? 'You' : r.author}${r.fromStaff && !r.mine ? ' · teacher' : ''} · ${commWhen(r.createdAt)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      r.body,
                      style: const TextStyle(
                        height: 1.45,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Write a reply',
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: busy ? null : onSend,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Send'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

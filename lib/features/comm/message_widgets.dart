import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/comm_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/role_style.dart';
import '../../widgets/kv_ui.dart';

/// Kind badge: whole-class announcement or private family update.
class KindBadge extends StatelessWidget {
  final bool private;

  const KindBadge({super.key, required this.private});

  @override
  Widget build(BuildContext context) => StatusChip(
    label: private ? 'Private update' : 'Announcement',
    tint: private ? AppTint.violet : AppTint.mint,
    icon: private ? Icons.lock_rounded : Icons.campaign_rounded,
  );
}

/// A labelled thin progress bar: "Viewed 12/20".
class ReceiptBar extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;

  const ReceiptBar({
    super.key,
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 104,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : value / total,
              minHeight: 8,
              backgroundColor: const Color(0xFFEDEFF5),
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 48,
          child: Text(
            '$value/$total',
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

/// Teacher list card for one message.
class TeacherMessageCard extends StatelessWidget {
  final CommSummary message;
  final VoidCallback onTap;

  const TeacherMessageCard({
    super.key,
    required this.message,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final m = message;
    return KvCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              KindBadge(private: m.private),
              if (m.private && m.student != null) ...[
                const SizedBox(width: 8),
                Text(
                  'About ${m.student}',
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const Spacer(),
              Text(
                commWhen(m.createdAt),
                style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            m.subject,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            m.preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.inkSoft, height: 1.4),
          ),
          const SizedBox(height: 14),
          if (m.recipients == 0)
            const Text(
              'No linked parents for this message yet.',
              style: TextStyle(color: Color(0xFFB45309), fontSize: 13),
            )
          else ...[
            ReceiptBar(
              label: 'Viewed',
              value: m.viewed,
              total: m.recipients,
              color: AppTint.sky.ink,
            ),
            if (m.needsAck) ...[
              const SizedBox(height: 6),
              ReceiptBar(
                label: 'Acknowledged',
                value: m.acknowledged,
                total: m.recipients,
                color: AppTint.mint.ink,
              ),
            ],
          ],
          if (m.replies > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 16,
                  color: AppColors.inkSoft,
                ),
                const SizedBox(width: 6),
                Text(
                  '${m.replies} repl${m.replies == 1 ? 'y' : 'ies'}',
                  style: const TextStyle(color: AppColors.inkSoft),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Parent inbox card.
class InboxCard extends StatelessWidget {
  final CommSummary message;
  final VoidCallback onTap;

  const InboxCard({super.key, required this.message, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final m = message;
    return KvCard(
      onTap: onTap,
      tint: m.unread ? AppTint.coral : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 12),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: m.unread ? AppTint.coral.strong : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        m.subject,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: m.unread
                              ? FontWeight.w800
                              : FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    Text(
                      commWhen(m.createdAt),
                      style: const TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    ?m.author,
                    ?m.className,
                    if (m.private && m.student != null) 'about ${m.student}',
                  ].join(' · '),
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  m.preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.ink, height: 1.4),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    KindBadge(private: m.private),
                    if (m.awaitingMyAck)
                      const StatusChip(
                        label: 'Please acknowledge',
                        tint: StatusChip.alert,
                        icon: Icons.task_alt_rounded,
                      ),
                    if (m.needsAck && !m.awaitingMyAck)
                      const StatusChip(
                        label: 'Acknowledged',
                        tint: AppTint.mint,
                        icon: Icons.check_rounded,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

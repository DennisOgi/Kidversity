import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/family_models.dart';
import '../../models/payment_models.dart';
import '../../services/family_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/error_boundary.dart';
import '../../widgets/surfaces.dart';

/// Purchases, pack completion, repeat purchases, and cross-subject buying,
/// per family and across the platform.
class AdminPaymentsScreen extends ConsumerWidget {
  const AdminPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(paymentAnalyticsProvider);
    return ShellScrollView(
      children: [
        const PageIntro(
          eyebrow: 'Platform',
          title: 'Payments',
          body:
              'Who buys, whether packs get finished, and which families come back for more.',
        ),
        const SizedBox(height: 18),
        analytics.when(
          loading: () => const LoadingIndicator(message: 'Loading payments…'),
          error: (error, _) => ErrorDisplay(
            message: 'Payment analytics could not be loaded.',
            error: error,
            onRetry: () => ref.invalidate(paymentAnalyticsProvider),
          ),
          data: (data) => _PaymentsBody(data: data),
        ),
      ],
    );
  }
}

class _PaymentsBody extends StatelessWidget {
  final PaymentAnalytics data;

  const _PaymentsBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final paying = data.total('families_paying');
    final prompts = data.total('renew_prompts');
    final repeat = data.total('repeat_families');
    String rate(int part, int whole) =>
        whole == 0 ? '—' : '${(part * 100 / whole).round()}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Kpi(
              label: 'Revenue',
              value: nairaLabel(data.total('revenue_kobo')),
              icon: Icons.payments_rounded,
            ),
            _Kpi(
              label: 'Paying families',
              value: '$paying',
              icon: Icons.family_restroom_rounded,
            ),
            _Kpi(
              label: 'Repeat families',
              value: '$repeat · ${rate(repeat, paying)}',
              icon: Icons.replay_rounded,
            ),
            _Kpi(
              label: 'Cross-subject',
              value: '${data.total('cross_subject_families')}',
              icon: Icons.call_split_rounded,
            ),
            _Kpi(
              label: 'Packs sold',
              value: '${data.total('packs_sold')}',
              icon: Icons.menu_book_rounded,
            ),
            _Kpi(
              label: 'Bundles sold',
              value: '${data.total('bundles_sold')}',
              icon: Icons.card_giftcard_rounded,
            ),
            _Kpi(
              label: 'Credits used',
              value: '${data.total('credits_redeemed')}',
              icon: Icons.confirmation_number_rounded,
            ),
            _Kpi(
              label: 'Packs finished',
              value: '${data.total('packs_completed')}',
              icon: Icons.flag_rounded,
            ),
            _Kpi(
              label: 'Lesson-8 prompts',
              value: '$prompts',
              icon: Icons.notifications_active_rounded,
            ),
            _Kpi(
              label: 'Abandoned checkouts',
              value: '${data.total('checkouts_abandoned')}',
              icon: Icons.remove_shopping_cart_rounded,
            ),
          ],
        ),
        const SizedBox(height: 22),
        const SectionHeader(
          title: 'By subject',
          subtitle: 'Packs owned and how many were finished.',
        ),
        for (final subject in data.bySubject)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(subject.title, style: text.titleSmall),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: subject.completionRate,
                            minHeight: 8,
                            backgroundColor: AppColors.backgroundAlt,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${subject.packsCompleted} of ${subject.packsOwned} packs finished',
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    nairaLabel(subject.revenueKobo),
                    style: text.titleMedium,
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 18),
        const SectionHeader(
          title: 'Families',
          subtitle: 'Most recent buyers first.',
        ),
        if (data.families.isEmpty)
          Text(
            'No purchases yet.',
            style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
          )
        else
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Family')),
                  DataColumn(label: Text('Paid'), numeric: true),
                  DataColumn(label: Text('Purchases'), numeric: true),
                  DataColumn(label: Text('Repeat'), numeric: true),
                  DataColumn(label: Text('Packs'), numeric: true),
                  DataColumn(label: Text('Finished'), numeric: true),
                  DataColumn(label: Text('Subjects')),
                  DataColumn(label: Text('Children'), numeric: true),
                  DataColumn(label: Text('Credits left'), numeric: true),
                ],
                rows: [
                  for (final family in data.families)
                    DataRow(
                      cells: [
                        DataCell(Text(family.label)),
                        DataCell(Text(family.stats.amountPaidLabel)),
                        DataCell(Text('${family.stats.paidPurchases}')),
                        DataCell(Text('${family.stats.repeatPurchases}')),
                        DataCell(Text('${family.stats.packsOwned}')),
                        DataCell(Text('${family.stats.packsCompleted}')),
                        DataCell(
                          Text(
                            family.subjects.isEmpty
                                ? '—'
                                : family.subjects.join(', '),
                          ),
                        ),
                        DataCell(Text('${family.stats.learners}')),
                        DataCell(Text('${family.stats.creditsRemaining}')),
                      ],
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _Kpi({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: 200,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SoftIcon(icon: icon, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: text.bodySmall),
                  Text(
                    value,
                    style: text.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../models/family_models.dart';
import '../../models/payment_models.dart';
import '../../router/navigation.dart';
import '../../services/family_service.dart';
import '../../services/payment_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/error_boundary.dart';
import '../../widgets/surfaces.dart';

/// Pathway, pack contents, and prices — shown before anyone pays.
///
/// Learners see their own pathway. Parents ([parentMode]) pick a child and
/// buy or redeem credits on that child's behalf.
class PaymentsScreen extends ConsumerStatefulWidget {
  final String? subjectId;
  final String? highlightPackId;
  final String? reference;
  final String? learnerUserId;
  final bool parentMode;

  const PaymentsScreen({
    super.key,
    this.subjectId,
    this.highlightPackId,
    this.reference,
    this.learnerUserId,
    this.parentMode = false,
  });

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  bool _busy = false;
  String? _learnerId;

  @override
  void initState() {
    super.initState();
    _learnerId = widget.learnerUserId;
    final reference = widget.reference;
    if (reference != null && reference.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _verify(reference));
    }
  }

  String get _returnRoute => widget.parentMode
      ? AppRoutes.parentPaymentsReturn
      : AppRoutes.studentPaymentsReturn;

  String get _closeRoute =>
      widget.parentMode ? AppRoutes.parentHome : AppRoutes.studentPath;

  void _refresh() {
    ref.invalidate(paymentAccessProvider);
    if (widget.parentMode) ref.invalidate(familyOverviewProvider);
  }

  Future<void> _verify(String reference) async {
    setState(() => _busy = true);
    final result = await PaymentService.instance.verifyReference(reference);
    if (!mounted) return;
    setState(() => _busy = false);
    _refresh();
    if (result.isFailure) {
      context.showErrorSnackbar(result.error ?? 'Payment not confirmed yet.');
      return;
    }
    context.showSuccessSnackbar(
      'Payment confirmed. Lessons stay yours forever.',
    );
  }

  Future<void> _checkout({required String productType, String? packId}) async {
    if (widget.parentMode &&
        productType == 'subject_pack' &&
        _learnerId == null) {
      context.showErrorSnackbar('Choose which child this pack is for.');
      return;
    }
    setState(() => _busy = true);
    final origin = Uri.base.origin;
    final result = await PaymentService.instance.startCheckout(
      productType: productType,
      packId: packId,
      learnerUserId: widget.parentMode ? _learnerId : null,
      callbackUrl: '$origin$_returnRoute',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.isFailure || result.data == null) {
      context.showErrorSnackbar(result.error ?? 'Checkout failed.');
      return;
    }
    // Paystack sends the payer back to [_returnRoute] with ?reference=.
    final opened = await PaymentService.instance.openCheckoutUrl(
      result.data!.authorizationUrl,
    );
    if (!opened && mounted) {
      context.showErrorSnackbar('Could not open Paystack checkout.');
    }
  }

  Future<void> _redeem(PaymentPack pack) async {
    if (widget.parentMode && _learnerId == null) {
      context.showErrorSnackbar('Choose which child gets this pack.');
      return;
    }
    setState(() => _busy = true);
    final result = await PaymentService.instance.redeemCredit(
      pack.id,
      learnerUserId: widget.parentMode ? _learnerId : null,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    _refresh();
    if (result.isFailure) {
      context.showErrorSnackbar(result.error ?? 'Could not use credit.');
      return;
    }
    context.showSuccessSnackbar(
      '${pack.title} unlocked with a credit · ${result.data} left.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(paymentCatalogProvider);
    final access = ref.watch(paymentAccessProvider);
    final family = widget.parentMode
        ? ref.watch(familyOverviewProvider).whenOrNull(data: (value) => value)
        : null;
    final subjectId = widget.subjectId ?? 'mandarin';
    final accessData = access.whenOrNull(data: (value) => value);

    final learners = family?.learners ?? const <FamilyLearner>[];
    if (widget.parentMode && _learnerId == null && learners.length == 1) {
      _learnerId = learners.first.userId;
    }
    final learner = family?.learnerById(_learnerId);

    List<LearnerSubjectStatus> statuses() {
      if (widget.parentMode) return learner?.subjects ?? const [];
      return accessData?.subjects ?? const [];
    }

    Set<String> owned() {
      if (widget.parentMode) {
        return {for (final status in statuses()) ...status.ownedPackIds};
      }
      return {
        for (final item
            in accessData?.entitlements ?? const <PaymentEntitlement>[])
          item.packId,
      };
    }

    final credits = widget.parentMode
        ? (family?.stats.creditsRemaining ?? accessData?.creditsRemaining ?? 0)
        : (accessData?.creditsRemaining ?? 0);

    return ShellScrollView(
      children: [
        PageIntro(
          eyebrow: widget.parentMode
              ? 'Packs for your children'
              : 'Learning packs',
          title: 'Pathway & prices',
          body:
              'Lessons 1–2 are free in every subject. Each pack opens the next 10 lessons, one at a time as your child finishes the one before. No subscription — packs never expire.',
          trailing: IconButton(
            tooltip: 'Close',
            onPressed: () => context.go(_closeRoute),
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        if (_busy) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(minHeight: 3),
        ],
        const SizedBox(height: 16),
        if (!widget.parentMode &&
            accessData != null &&
            accessData.hasGuardian) ...[
          const _GuardianNote(),
          const SizedBox(height: 16),
        ],
        if (widget.parentMode) ...[
          _LearnerPicker(
            learners: learners,
            selectedId: _learnerId,
            onSelect: (id) => setState(() => _learnerId = id),
          ),
          const SizedBox(height: 16),
        ],
        catalog.when(
          loading: () => const LoadingIndicator(message: 'Loading packs…'),
          error: (error, _) => ErrorDisplay(
            message: 'Packs could not be loaded.',
            error: error,
            onRetry: () => ref.invalidate(paymentCatalogProvider),
          ),
          data: (cat) {
            final ownedIds = owned();
            final statusList = statuses();
            LearnerSubjectStatus? statusFor(String id) {
              for (final status in statusList) {
                if (status.subjectId == id) return status;
              }
              return null;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PricingBanner(catalog: cat),
                const SizedBox(height: 18),
                if (accessData != null && !widget.parentMode) ...[
                  _FamilyStatsCard(
                    stats: accessData.stats,
                    credits: accessData.creditsRemaining,
                  ),
                  const SizedBox(height: 18),
                ],
                for (final subject in cat.subjects) ...[
                  _SubjectPathway(
                    subject: subject,
                    status: statusFor(subject.id),
                    ownedPackIds: ownedIds,
                    credits: credits,
                    canBuy: !widget.parentMode || learner != null,
                    highlighted:
                        subject.id == subjectId ||
                        subject.packs.any(
                          (p) => p.id == widget.highlightPackId,
                        ),
                    highlightPackId: widget.highlightPackId,
                    busy: _busy,
                    onBuyPack: (pack) =>
                        _checkout(productType: 'subject_pack', packId: pack.id),
                    onRedeem: _redeem,
                    onPreview: widget.parentMode
                        ? null
                        : subject.id == 'mandarin'
                        ? () => context.go(AppRoutes.studentMandarin)
                        : subject.id == 'maths'
                        ? () => context.go(AppRoutes.studentMaths)
                        : null,
                  ),
                  const SizedBox(height: 22),
                ],
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bundle · ${cat.bundleCredits} pack credits for ${cat.bundlePriceLabel}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Save ${nairaLabel(cat.packPriceKobo * cat.bundleCredits - cat.bundlePriceKobo)} against single packs. '
                        'Each credit opens 10 lessons — in the same subject or across subjects, for any child in your family.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _checkout(productType: 'bundle_3'),
                        icon: const Icon(Icons.card_giftcard_rounded),
                        label: Text('Buy bundle · ${cat.bundlePriceLabel}'),
                      ),
                    ],
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

class _GuardianNote extends StatelessWidget {
  const _GuardianNote();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      color: AppColors.successSoft,
      child: Row(
        children: [
          const Icon(Icons.family_restroom_rounded, color: AppColors.success),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your parent can unlock packs for you from their Kidversity account. '
              'They get a reminder when you reach lesson 8 of a pack.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _LearnerPicker extends StatelessWidget {
  final List<FamilyLearner> learners;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  const _LearnerPicker({
    required this.learners,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (learners.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.link_rounded, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Link your child first: they enter your family code under Me → Family. '
                'You can still browse the pathway and buy a bundle now.',
                style: text.bodyMedium,
              ),
            ),
            TextButton(
              onPressed: () => context.go(AppRoutes.parentHome),
              child: const Text('Get code'),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Buying for', style: text.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final learner in learners)
              ChoiceChip(
                avatar: Text(learner.avatarEmoji),
                label: Text(learner.displayName),
                selected: learner.userId == selectedId,
                onSelected: (_) => onSelect(learner.userId),
              ),
          ],
        ),
      ],
    );
  }
}

class _PricingBanner extends StatelessWidget {
  final PaymentCatalog catalog;

  const _PricingBanner({required this.catalog});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        children: [
          _PriceChip(
            label: 'Free in every subject',
            value: 'Lessons 1–${catalog.freeLessons}',
          ),
          _PriceChip(
            label: 'One pack · 10 lessons',
            value: catalog.packPriceLabel,
          ),
          _PriceChip(
            label: 'Bundle · ${catalog.bundleCredits} credits',
            value: catalog.bundlePriceLabel,
          ),
          const _PriceChip(label: 'Monthly fee', value: 'None'),
        ],
      ),
    );
  }
}

class _PriceChip extends StatelessWidget {
  final String label;
  final String value;

  const _PriceChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _FamilyStatsCard extends StatelessWidget {
  final PaymentFamilyStats stats;
  final int credits;

  const _FamilyStatsCard({required this.stats, required this.credits});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your packs', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '$credits credits left · '
            '${stats.packsOwned} packs owned · '
            '${stats.packsCompleted} finished',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _SubjectPathway extends StatelessWidget {
  final PaymentSubject subject;
  final LearnerSubjectStatus? status;
  final Set<String> ownedPackIds;
  final int credits;
  final bool canBuy;
  final bool highlighted;
  final String? highlightPackId;
  final bool busy;
  final Future<void> Function(PaymentPack pack) onBuyPack;
  final Future<void> Function(PaymentPack pack) onRedeem;
  final VoidCallback? onPreview;

  const _SubjectPathway({
    required this.subject,
    required this.status,
    required this.ownedPackIds,
    required this.credits,
    required this.canBuy,
    required this.highlighted,
    required this.highlightPackId,
    required this.busy,
    required this.onBuyPack,
    required this.onRedeem,
    this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final progress = status;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      border: highlighted
          ? Border.all(color: AppColors.cinnabar, width: 1.4)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(subject.title, style: text.titleLarge)),
              if (onPreview != null)
                TextButton(
                  onPressed: onPreview,
                  child: const Text('Free preview'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subject.description,
            style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
          ),
          if (progress != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.progress,
                minHeight: 8,
                backgroundColor: AppColors.backgroundAlt,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              progress.finished
                  ? 'All ${progress.lessonsTotal} lessons finished.'
                  : '${progress.lessonsCompleted} of ${progress.lessonsTotal} done · next is lesson ${progress.nextSequence ?? 1}',
              style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
            ),
          ],
          const SizedBox(height: 12),
          _FreeRow(highlight: (progress?.nextSequence ?? 1) <= 2),
          const SizedBox(height: 10),
          for (final pack in subject.packs) ...[
            _PackRow(
              pack: pack,
              owned: ownedPackIds.contains(pack.id),
              credits: credits,
              canBuy: canBuy,
              current: progress?.currentPackId == pack.id,
              completedInPack: progress?.currentPackId == pack.id
                  ? progress!.completedInCurrentPack
                  : null,
              highlight: pack.id == highlightPackId,
              busy: busy,
              onBuy: () => onBuyPack(pack),
              onRedeem: () => onRedeem(pack),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _FreeRow extends StatelessWidget {
  final bool highlight;

  const _FreeRow({required this.highlight});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight ? AppColors.success : AppColors.line,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lessons 1–2 · Free', style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  'Try the subject before anyone pays.',
                  style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          const Pill(label: 'Open', color: AppColors.jade),
        ],
      ),
    );
  }
}

class _PackRow extends StatelessWidget {
  final PaymentPack pack;
  final bool owned;
  final int credits;
  final bool canBuy;
  final bool current;
  final int? completedInPack;
  final bool highlight;
  final bool busy;
  final VoidCallback onBuy;
  final VoidCallback onRedeem;

  const _PackRow({
    required this.pack,
    required this.owned,
    required this.credits,
    required this.canBuy,
    required this.current,
    required this.completedInPack,
    required this.highlight,
    required this.busy,
    required this.onBuy,
    required this.onRedeem,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final done = completedInPack;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? AppColors.primarySoft : AppColors.backgroundAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight || current ? AppColors.cinnabar : AppColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(pack.title, style: text.titleSmall)),
              Text(pack.priceNairaLabel, style: text.titleSmall),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Milestone: ${pack.milestoneLabel}',
            style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
          ),
          Text(
            '${pack.lessonCount} lessons (${pack.startSequence}–${pack.endSequence}), opened one by one.',
            style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
          ),
          if (current && done != null && owned) ...[
            const SizedBox(height: 8),
            Text(
              '$done of ${pack.lessonCount} finished in this pack',
              style: text.labelLarge?.copyWith(color: AppColors.primary),
            ),
          ],
          const SizedBox(height: 10),
          if (owned)
            const Pill(label: 'Unlocked forever', color: AppColors.jade)
          else if (!canBuy)
            Text(
              'Choose a child above to unlock this pack.',
              style: text.bodySmall?.copyWith(color: AppColors.muted),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: busy ? null : onBuy,
                  child: Text('Buy · ${pack.priceNairaLabel}'),
                ),
                if (credits > 0)
                  OutlinedButton(
                    onPressed: busy ? null : onRedeem,
                    child: Text('Use 1 credit ($credits left)'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Shown after lesson 8 of a paid pack.
Future<void> showPackRenewPrompt(
  BuildContext context,
  WidgetRef ref, {
  required PaymentPack currentPack,
  PaymentPack? nextPack,
}) async {
  await PaymentService.instance.markPromptSeen(currentPack.id);
  if (!context.mounted) return;
  final access = ref.read(paymentAccessProvider).whenOrNull(data: (v) => v);
  final credits = access?.creditsRemaining ?? 0;
  final guardian = access?.hasGuardian ?? false;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Keep the path open'),
      content: Text(
        nextPack == null
            ? 'You are near the end of ${currentPack.title}. Great work!'
            : guardian
            ? 'You finished lesson 8 of ${currentPack.title}. We have let your parent know '
                  'that ${nextPack.title} (${nextPack.priceNairaLabel}) is next.'
            : 'You finished lesson 8 of ${currentPack.title}. Unlock ${nextPack.title} '
                  '(${nextPack.priceNairaLabel}) or use a credit${credits > 0 ? ' ($credits left)' : ''}.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Later'),
        ),
        if (nextPack != null)
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.go(
                '${AppRoutes.studentPayments}?subject=${nextPack.subjectHint}&pack=${nextPack.id}',
              );
            },
            child: const Text('See packs'),
          ),
      ],
    ),
  );
}

extension on PaymentPack {
  String get subjectHint {
    if (id.startsWith('mandarin')) return 'mandarin';
    if (id.startsWith('maths')) return 'maths';
    return 'mandarin';
  }
}

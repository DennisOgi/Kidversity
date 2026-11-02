import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/features.dart';
import '../../data/app_state.dart';
import '../../data/auth_state.dart';
import '../../models/family_models.dart';
import '../../models/payment_models.dart';
import '../../router/navigation.dart';
import '../../services/family_service.dart';
import '../../services/payment_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/error_boundary.dart';
import '../../widgets/stat_grid.dart';
import '../../widgets/surfaces.dart';

/// A parent's home: the family code, each child's pathway, and what is due.
class ParentHomeScreen extends ConsumerStatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  ConsumerState<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends ConsumerState<ParentHomeScreen> {
  bool _busy = false;

  Future<void> _refresh() async {
    ref.invalidate(familyOverviewProvider);
    ref.invalidate(familyCodeProvider);
    ref.invalidate(paymentCatalogProvider);
    try {
      await ref.read(familyOverviewProvider.future);
    } catch (_) {
      // The error state is shown by the page itself.
    }
  }

  Future<void> _useCredit(FamilyLearner learner, String packId) async {
    setState(() => _busy = true);
    final result = await PaymentService.instance.redeemCredit(
      packId,
      learnerUserId: learner.userId,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.isFailure) {
      context.showErrorSnackbar(result.error ?? 'Could not use a credit.');
      return;
    }
    ref.invalidate(familyOverviewProvider);
    context.showSuccessSnackbar(
      'Unlocked for ${learner.displayName} · ${result.data} credits left.',
    );
  }

  void _openPacks({String? learnerId, String? subjectId, String? packId}) {
    final query = <String, String>{
      'learner': ?learnerId,
      'subject': ?subjectId,
      'pack': ?packId,
    };
    context.go(
      Uri(path: AppRoutes.parentPacks, queryParameters: query).toString(),
    );
  }

  Future<void> _signOut() async {
    await ref.read(authControllerProvider).signOut();
    if (mounted) context.go(AppRoutes.home);
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete your parent account?'),
        content: const Text(
          'Your children keep their own accounts and every pack you bought for '
          'them. Your sign-in and purchase history are removed. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await SupabaseService.instance.client.functions.invoke(
        'delete-account',
        body: {'confirmation': 'DELETE'},
      );
    } catch (_) {
      if (mounted) {
        context.showErrorSnackbar('Your account could not be deleted.');
      }
      return;
    }
    await _signOut();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final overview = ref.watch(familyOverviewProvider);
    final name = auth.displayName.isNotEmpty ? auth.displayName : 'there';

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ShellScrollView(
        children: [
          PageIntro(
            eyebrow: 'Family',
            title: 'Hi $name',
            body: Features.payments
                ? 'See where each child is, what they finished this week, and when the next pack is due.'
                : 'See where each child is and what they finished this week.',
            trailing: PopupMenuButton<String>(
              tooltip: 'Account',
              icon: const Icon(Icons.more_horiz_rounded),
              onSelected: (value) {
                if (value == 'signout') _signOut();
                if (value == 'delete') _deleteAccount();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'signout', child: Text('Sign out')),
                PopupMenuItem(value: 'delete', child: Text('Delete account')),
              ],
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 3),
          ],
          const SizedBox(height: 18),
          overview.when(
            loading: () =>
                const LoadingIndicator(message: 'Loading your family…'),
            error: (error, _) => ErrorDisplay(
              message: 'Your family could not be loaded.',
              error: error,
              onRetry: _refresh,
            ),
            data: (family) => _FamilyBody(
              family: family,
              busy: _busy,
              onUseCredit: _useCredit,
              onOpenPacks: _openPacks,
            ),
          ),
        ],
      ),
    );
  }
}

class _FamilyBody extends ConsumerWidget {
  final FamilyOverview family;
  final bool busy;
  final Future<void> Function(FamilyLearner learner, String packId) onUseCredit;
  final void Function({String? learnerId, String? subjectId, String? packId})
  onOpenPacks;

  const _FamilyBody({
    required this.family,
    required this.busy,
    required this.onUseCredit,
    required this.onOpenPacks,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref
        .watch(paymentCatalogProvider)
        .whenOrNull(data: (value) => value);
    final subjectTitles = {
      for (final subject in catalog?.subjects ?? const <PaymentSubject>[])
        subject.id: subject.title,
    };
    final credits = family.stats.creditsRemaining;
    final due = [
      for (final learner in family.learners)
        for (final status in learner.actionsDue) (learner, status),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FamilyCodeCard(
          fallbackCode: family.linkCode,
          hasChildren: family.learners.isNotEmpty,
        ),
        const SizedBox(height: 18),
        if (family.learners.isNotEmpty) ...[
          _FamilySnapshot(learners: family.learners),
          const SizedBox(height: 22),
        ],
        if (Features.payments && due.isNotEmpty) ...[
          SectionHeader(
            title: 'Waiting on you',
            subtitle: credits > 0
                ? 'You have $credits pack credit${credits == 1 ? '' : 's'} to use.'
                : 'Unlock the next pack so lessons keep opening.',
          ),
          for (final (learner, status) in due) ...[
            _DueCard(
              learner: learner,
              status: status,
              subjectTitle: subjectTitles[status.subjectId] ?? status.subjectId,
              credits: credits,
              busy: busy,
              onUseCredit: () => onUseCredit(learner, status.packToOffer!),
              onBuy: () => onOpenPacks(
                learnerId: learner.userId,
                subjectId: status.subjectId,
                packId: status.packToOffer,
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
        ],
        if (family.learners.isEmpty)
          const _NoChildrenYet()
        else ...[
          const SectionHeader(
            title: 'Your children',
            subtitle: 'Lessons open one at a time as each one is finished.',
          ),
          for (final learner in family.learners) ...[
            _LearnerCard(
              learner: learner,
              subjectTitles: subjectTitles,
              onOpenPacks: () => onOpenPacks(learnerId: learner.userId),
            ),
            const SizedBox(height: 12),
          ],
        ],
        if (Features.payments) ...[
          const SizedBox(height: 12),
          _LedgerCard(family: family, onOpenPacks: () => onOpenPacks()),
        ],
      ],
    );
  }
}

class _FamilySnapshot extends StatelessWidget {
  final List<FamilyLearner> learners;

  const _FamilySnapshot({required this.learners});

  @override
  Widget build(BuildContext context) {
    final lessons = learners.fold<int>(0, (s, l) => s + l.lessonsCompleted);
    final minutes = learners.fold<int>(0, (s, l) => s + l.minutesLearned);
    final today = learners.where((l) => l.activeToday).length;
    final streak = learners.fold<int>(
      0,
      (best, l) => l.streakDays > best ? l.streakDays : best,
    );
    return StatGrid(
      tiles: [
        StatTile(
          label: 'learned today',
          value: '$today/${learners.length}',
          icon: Icons.today_rounded,
          color: today > 0 ? AppColors.success : AppColors.muted,
          caption: learners.length == 1 ? 'child' : 'children',
        ),
        StatTile.count(
          label: 'lessons done',
          count: lessons,
          icon: Icons.check_circle_rounded,
          color: AppColors.worldLanguage,
        ),
        StatTile(
          label: 'time learning',
          value: minutes >= 120
              ? '${(minutes / 60).floor()} h'
              : '$minutes min',
          icon: Icons.timer_rounded,
          color: AppColors.worldExams,
        ),
        StatTile(
          label: 'best streak',
          value: '$streak ${streak == 1 ? 'day' : 'days'}',
          icon: Icons.local_fire_department_rounded,
          color: streak > 0 ? const Color(0xFFD9480F) : AppColors.muted,
        ),
      ],
    );
  }
}

class _FamilyCodeCard extends ConsumerWidget {
  final String? fallbackCode;
  final bool hasChildren;

  const _FamilyCodeCard({
    required this.fallbackCode,
    required this.hasChildren,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final code = ref.watch(familyCodeProvider);
    final value = code.whenOrNull(data: (value) => value) ?? fallbackCode;
    return GlassCard(
      gradient: AppColors.mandarinGradient,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasChildren ? 'Add another child' : 'Link your child',
            style: text.titleMedium?.copyWith(color: AppColors.paper),
          ),
          const SizedBox(height: 6),
          Text(
            'On your child’s Kidversity account, open Me → Family and type this code.',
            style: text.bodyMedium?.copyWith(
              color: AppColors.paper.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: code.isLoading && value == null
                    ? const LinearProgressIndicator(minHeight: 3)
                    : SelectableText(
                        value ?? '—',
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                        ),
                      ),
              ),
              if (value != null)
                IconButton.filledTonal(
                  tooltip: 'Copy code',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: value));
                    if (context.mounted) {
                      context.showSuccessSnackbar('Family code copied.');
                    }
                  },
                  icon: const Icon(Icons.copy_rounded),
                ),
            ],
          ),
          if (code.hasError && value == null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.invalidate(familyCodeProvider),
              child: const Text('Try again'),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoChildrenYet extends StatelessWidget {
  const _NoChildrenYet();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final steps = [
      (
        Icons.person_add_alt_1_rounded,
        'Your child signs up as a Student',
        'They pick a name and a companion, then start the Mandarin and maths pathways.',
      ),
      (
        Icons.password_rounded,
        'They type your family code',
        'Me → Family on their account. You will see them here straight away.',
      ),
      if (Features.payments)
        (
          Icons.lock_open_rounded,
          'You unlock packs when they are ready',
          '₦2,500 opens the next 10 lessons in one subject, or ₦6,500 for 3 packs.',
        )
      else
        (
          Icons.insights_rounded,
          'Follow along',
          'Lessons finished, streaks, and where they are in Mandarin and maths.',
        ),
    ];
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Three steps to get started', style: text.titleMedium),
          const SizedBox(height: 12),
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SoftIcon(icon: steps[i].$1, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(steps[i].$2, style: text.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        steps[i].$3,
                        style: text.bodySmall?.copyWith(
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DueCard extends StatelessWidget {
  final FamilyLearner learner;
  final LearnerSubjectStatus status;
  final String subjectTitle;
  final int credits;
  final bool busy;
  final VoidCallback onUseCredit;
  final VoidCallback onBuy;

  const _DueCard({
    required this.learner,
    required this.status,
    required this.subjectTitle,
    required this.credits,
    required this.busy,
    required this.onUseCredit,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final packTitle = status.packToOfferTitle ?? 'the next pack';
    final headline = status.needsPack
        ? '${learner.displayName} is waiting for $packTitle'
        : '${learner.displayName} reached lesson 8 of ${status.currentPackTitle ?? 'this pack'}';
    final detail = status.needsPack
        ? 'The next $subjectTitle lesson is locked until a pack is unlocked.'
        : '$packTitle comes next in $subjectTitle. Unlock it now so there is no pause.';
    return GlassCard(
      padding: const EdgeInsets.all(16),
      border: Border.all(color: AppColors.spark, width: 1.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EmojiText(learner.avatarEmoji, size: 26),
              const SizedBox(width: 10),
              Expanded(child: Text(headline, style: text.titleSmall)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: busy ? null : onBuy,
                child: Text(
                  status.needsPack || status.nextPackPriceKobo <= 0
                      ? 'See pack & price'
                      : 'Unlock · ${nairaLabel(status.nextPackPriceKobo)}',
                ),
              ),
              if (credits > 0)
                OutlinedButton(
                  onPressed: busy ? null : onUseCredit,
                  child: Text('Use a credit ($credits left)'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LearnerCard extends StatelessWidget {
  final FamilyLearner learner;
  final Map<String, String> subjectTitles;
  final VoidCallback onOpenPacks;

  const _LearnerCard({
    required this.learner,
    required this.subjectTitles,
    required this.onOpenPacks,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hours = (learner.minutesLearned / 60).toStringAsFixed(1);
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: EmojiText(learner.avatarEmoji, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(learner.displayName, style: text.titleMedium),
                    Text(
                      learner.activeToday
                          ? 'Learned today · ${learner.streakDays}-day streak'
                          : '${learner.streakDays}-day streak · $hours h learned',
                      style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              if (Features.payments)
                TextButton(onPressed: onOpenPacks, child: const Text('Packs')),
            ],
          ),
          const SizedBox(height: 14),
          for (final subject in learner.subjects) ...[
            _SubjectProgressRow(
              title: subjectTitles[subject.subjectId] ?? subject.subjectId,
              status: subject,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _SubjectProgressRow extends StatelessWidget {
  final String title;
  final LearnerSubjectStatus status;

  const _SubjectProgressRow({required this.title, required this.status});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final line = status.finished
        ? 'Finished all ${status.lessonsTotal} lessons'
        : status.needsPack
        ? 'Paused at lesson ${status.nextSequence} · needs ${status.currentPackTitle ?? 'a pack'}'
        : status.currentPackOwned
        ? '${status.currentPackTitle} · ${status.completedInCurrentPack}/${status.currentPackSize} done'
        : 'Lesson ${status.nextSequence ?? 1} next${(status.nextSequence ?? 1) <= 2 ? ' · free' : ''}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: text.titleSmall)),
            Text(
              '${status.lessonsCompleted}/${status.lessonsTotal}',
              style: text.labelLarge,
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: status.progress,
            minHeight: 8,
            backgroundColor: AppColors.backgroundAlt,
            color: status.needsPack ? AppColors.warning : AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(line, style: text.bodySmall?.copyWith(color: AppColors.inkSoft)),
      ],
    );
  }
}

class _LedgerCard extends StatelessWidget {
  final FamilyOverview family;
  final VoidCallback onOpenPacks;

  const _LedgerCard({required this.family, required this.onOpenPacks});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final stats = family.stats;
    final paid = [
      for (final purchase in family.purchases)
        if (purchase.status == 'paid') purchase,
    ];
    String forWhom(PaymentPurchase purchase) {
      if (purchase.isBundle) return '3 credits';
      final learner = family.learnerById(purchase.learnerUserId);
      return learner == null ? '' : 'for ${learner.displayName}';
    }

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Purchases', style: text.titleMedium)),
              TextButton(
                onPressed: onOpenPacks,
                child: const Text('Pathway & prices'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _Stat(label: 'Paid so far', value: stats.amountPaidLabel),
              _Stat(label: 'Packs owned', value: '${stats.packsOwned}'),
              _Stat(label: 'Packs finished', value: '${stats.packsCompleted}'),
              _Stat(label: 'Credits left', value: '${stats.creditsRemaining}'),
            ],
          ),
          const SizedBox(height: 14),
          if (paid.isEmpty)
            Text(
              'No purchases yet. Lessons 1–2 of every subject are free, and packs never expire.',
              style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
            )
          else
            for (final purchase in paid.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      purchase.isBundle
                          ? Icons.card_giftcard_rounded
                          : Icons.menu_book_rounded,
                      size: 18,
                      color: AppColors.inkSoft,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${purchase.isBundle ? 'Bundle' : (purchase.packId ?? 'Pack')} ${forWhom(purchase)}',
                        style: text.bodyMedium,
                      ),
                    ),
                    Text(purchase.amountLabel, style: text.labelLarge),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.bodySmall),
        Text(value, style: text.titleMedium),
      ],
    );
  }
}

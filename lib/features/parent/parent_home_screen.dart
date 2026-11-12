import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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
import '../../theme/role_style.dart';
import '../../widgets/common.dart';
import '../../widgets/error_boundary.dart';
import '../../widgets/kv_ui.dart';

/// A parent's home: each child's week, where they are, and the family code.
class ParentHomeScreen extends ConsumerStatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  ConsumerState<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends ConsumerState<ParentHomeScreen> {
  bool _busy = false;
  String? _selectedLearnerId;

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
    final name = firstName(auth.displayName);
    final greeting = name.isEmpty ? timeGreeting() : '${timeGreeting()}, $name';

    return overview.when(
      loading: () => const KvPage(
        children: [LoadingIndicator(message: 'Loading your family…')],
      ),
      error: (error, _) => KvPage(
        children: [
          ErrorDisplay(
            message: 'Your family could not be loaded.',
            error: error,
            onRetry: _refresh,
          ),
        ],
      ),
      data: (family) {
        final learners = family.learners;
        FamilyLearner? selected;
        for (final learner in learners) {
          if (learner.userId == _selectedLearnerId) selected = learner;
        }
        selected ??= learners.firstOrNull;

        return KvPage(
          onRefresh: _refresh,
          children: [
            _FamilyHero(greeting: greeting, learners: learners),
            if (_busy) const LinearProgressIndicator(minHeight: 3),
            if (learners.isEmpty) ...[
              _FamilyCodeCard(
                fallbackCode: family.linkCode,
                hasChildren: false,
              ),
              const _NoChildrenYet(),
            ] else ...[
              if (learners.length > 1)
                _ChildSwitcher(
                  learners: learners,
                  selectedId: selected!.userId,
                  onSelect: (id) => setState(() => _selectedLearnerId = id),
                ),
              _FamilyBody(
                family: family,
                learner: selected!,
                busy: _busy,
                onUseCredit: _useCredit,
                onOpenPacks: _openPacks,
              ),
              _FamilyCodeCard(fallbackCode: family.linkCode, hasChildren: true),
            ],
            if (Features.payments)
              _LedgerCard(family: family, onOpenPacks: () => _openPacks()),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _busy ? null : _deleteAccount,
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete my parent account'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FamilyHero extends StatelessWidget {
  final String greeting;
  final List<FamilyLearner> learners;

  const _FamilyHero({required this.greeting, required this.learners});

  @override
  Widget build(BuildContext context) {
    final String title;
    final String body;
    if (learners.isEmpty) {
      title = 'Link your child to follow along.';
      body =
          'Give them your family code. Their progress shows here right away.';
    } else if (learners.length == 1) {
      final child = learners.first;
      final first = firstName(child.displayName);
      title = child.activeToday
          ? '$first learned today.'
          : child.streakDays > 0
          ? '$first has a ${child.streakDays}-day streak.'
          : '$first has not learned today yet.';
      body = child.activeToday
          ? 'A few minutes every day keeps the streak going.'
          : 'A gentle reminder after school helps keep the habit.';
    } else {
      final today = learners.where((l) => l.activeToday).length;
      title = '$today of ${learners.length} children learned today.';
      body = 'Pick a child below to see where they are.';
    }
    return HeroBanner(
      colors: HeroColors.parent,
      eyebrow: greeting,
      title: title,
      body: body,
    );
  }
}

class _ChildSwitcher extends StatelessWidget {
  final List<FamilyLearner> learners;
  final String selectedId;
  final ValueChanged<String> onSelect;

  const _ChildSwitcher({
    required this.learners,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < learners.length; i++)
          _ChildChip(
            learner: learners[i],
            tint: AppTint.cycle[(i + 4) % AppTint.cycle.length],
            selected: learners[i].userId == selectedId,
            onTap: () => onSelect(learners[i].userId),
          ),
      ],
    );
  }
}

class _ChildChip extends StatelessWidget {
  final FamilyLearner learner;
  final AppTint tint;
  final bool selected;
  final VoidCallback onTap;

  const _ChildChip({
    required this.learner,
    required this.tint,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: AppColors.surface,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? AppTint.coral.ink : const Color(0xFFEFE3DF),
            width: 2,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 18, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tint.soft,
                    shape: BoxShape.circle,
                  ),
                  child: EmojiText(learner.avatarEmoji, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  learner.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.ink : AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FamilyBody extends ConsumerWidget {
  final FamilyOverview family;
  final FamilyLearner learner;
  final bool busy;
  final Future<void> Function(FamilyLearner learner, String packId) onUseCredit;
  final void Function({String? learnerId, String? subjectId, String? packId})
  onOpenPacks;

  const _FamilyBody({
    required this.family,
    required this.learner,
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
      for (final l in family.learners)
        for (final status in l.actionsDue) (l, status),
    ];
    final first = firstName(learner.displayName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (Features.payments && due.isNotEmpty) ...[
          KvSectionTitle(
            title: 'Waiting on you',
            subtitle: credits > 0
                ? 'You have $credits pack credit${credits == 1 ? '' : 's'} to use.'
                : 'Unlock the next pack so lessons keep opening.',
          ),
          for (final (l, status) in due) ...[
            _DueCard(
              learner: l,
              status: status,
              subjectTitle: subjectTitles[status.subjectId] ?? status.subjectId,
              credits: credits,
              busy: busy,
              onUseCredit: () => onUseCredit(l, status.packToOffer!),
              onBuy: () => onOpenPacks(
                learnerId: l.userId,
                subjectId: status.subjectId,
                packId: status.packToOffer,
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
        ],
        KvSectionTitle(
          title: '$first at a glance',
          subtitle: learner.activeToday
              ? 'Learned today'
              : _lastActive(learner.lastActivityDate),
        ),
        _LearnerStats(learner: learner),
        const SizedBox(height: 24),
        _WhereTheyAre(
          learner: learner,
          subjectTitles: subjectTitles,
          onOpenPacks: () => onOpenPacks(learnerId: learner.userId),
        ),
      ],
    );
  }
}

String _lastActive(DateTime? last) {
  if (last == null) return 'Not started yet';
  final now = DateTime.now();
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(last.year, last.month, last.day)).inDays;
  if (days <= 1) return 'Last learned yesterday';
  return 'Last learned $days days ago';
}

class _LearnerStats extends StatelessWidget {
  final FamilyLearner learner;

  const _LearnerStats({required this.learner});

  @override
  Widget build(BuildContext context) {
    final minutes = learner.minutesLearned;
    final streak = learner.streakDays;
    return AdaptiveGrid(
      minTileWidth: 150,
      children: [
        MetricTile(
          tint: AppTint.coral,
          icon: Icons.local_fire_department_rounded,
          label: 'Streak',
          value: '$streak ${streak == 1 ? 'day' : 'days'}',
          caption: learner.activeToday
              ? 'Kept going today'
              : 'Learn today to keep it',
        ),
        MetricTile(
          tint: AppTint.violet,
          icon: Icons.timer_rounded,
          label: 'Time learning',
          value: minutes >= 120
              ? '${(minutes / 60).toStringAsFixed(1)} h'
              : '$minutes min',
          caption: 'Since they joined',
        ),
        MetricTile(
          tint: AppTint.mint,
          icon: Icons.check_circle_rounded,
          label: 'Lessons done',
          value: '${learner.lessonsCompleted}',
          caption: 'Across every subject',
        ),
        MetricTile(
          tint: AppTint.sun,
          icon: Icons.star_rounded,
          label: 'XP earned',
          value: '${learner.xp}',
          caption: 'Level ${learner.xp ~/ 500 + 1}',
        ),
      ],
    );
  }
}

AppTint _subjectTint(String subjectId, int index) {
  final id = subjectId.toLowerCase();
  if (id.contains('mandarin') || id.contains('chinese')) {
    return AppTint.mandarin;
  }
  if (id.contains('math')) return AppTint.maths;
  if (id.contains('exam')) return AppTint.exams;
  return AppTint.cycle[(index + 3) % AppTint.cycle.length];
}

class _WhereTheyAre extends StatelessWidget {
  final FamilyLearner learner;
  final Map<String, String> subjectTitles;
  final VoidCallback onOpenPacks;

  const _WhereTheyAre({
    required this.learner,
    required this.subjectTitles,
    required this.onOpenPacks,
  });

  @override
  Widget build(BuildContext context) {
    final first = firstName(learner.displayName);
    return KvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KvSectionTitle(
            title: 'Where $first is',
            subtitle: 'Lessons open one at a time as each one is finished.',
            action: Features.payments
                ? TextButton(onPressed: onOpenPacks, child: const Text('Packs'))
                : null,
          ),
          if (learner.subjects.isEmpty)
            const Text(
              'No lessons started yet.',
              style: TextStyle(color: AppColors.inkSoft),
            ),
          for (var i = 0; i < learner.subjects.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            _SubjectProgressRow(
              title:
                  subjectTitles[learner.subjects[i].subjectId] ??
                  _prettyId(learner.subjects[i].subjectId),
              status: learner.subjects[i],
              tint: _subjectTint(learner.subjects[i].subjectId, i),
            ),
          ],
        ],
      ),
    );
  }
}

String _prettyId(String id) {
  if (id.isEmpty) return 'Subject';
  final words = id.replaceAll(RegExp(r'[_-]+'), ' ').trim();
  return words[0].toUpperCase() + words.substring(1);
}

class _SubjectProgressRow extends StatelessWidget {
  final String title;
  final LearnerSubjectStatus status;
  final AppTint tint;

  const _SubjectProgressRow({
    required this.title,
    required this.status,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final line = status.finished
        ? 'Finished all ${status.lessonsTotal} lessons'
        : status.needsPack
        ? 'Paused at lesson ${status.nextSequence} · needs ${status.currentPackTitle ?? 'a pack'}'
        : status.currentPackOwned
        ? '${status.currentPackTitle} · ${status.completedInCurrentPack}/${status.currentPackSize} done'
        : 'Lesson ${status.nextSequence ?? 1} next';
    return Row(
      children: [
        TintIcon(tint: tint, icon: Icons.menu_book_rounded, size: 40),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Text(
                    '${status.lessonsCompleted} of ${status.lessonsTotal}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: tint.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              KvBar(
                value: status.progress,
                tint: status.needsPack ? AppTint.sun : tint,
                height: 10,
              ),
              const SizedBox(height: 4),
              Text(
                line,
                style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
              ),
            ],
          ),
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
    final code = ref.watch(familyCodeProvider);
    final value = code.whenOrNull(data: (value) => value) ?? fallbackCode;
    return KvCard(
      tint: AppTint.sun,
      child: Wrap(
        spacing: 20,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasChildren ? 'Add another child' : 'Your family code',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'On your child’s Kidversity account, open Me, then Family, and type this code.',
                  style: TextStyle(fontSize: 14, color: AppTint.sun.ink),
                ),
                if (code.hasError && value == null)
                  TextButton(
                    onPressed: () => ref.invalidate(familyCodeProvider),
                    child: const Text('Try again'),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: code.isLoading && value == null
                    ? const SizedBox(
                        width: 120,
                        child: LinearProgressIndicator(minHeight: 3),
                      )
                    : SelectableText(
                        value ?? '—',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                          color: AppColors.ink,
                        ),
                      ),
              ),
              if (value != null) ...[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Copy family code',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: value));
                    if (context.mounted) {
                      context.showSuccessSnackbar('Family code copied.');
                    }
                  },
                  icon: const Icon(Icons.copy_rounded),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _NoChildrenYet extends StatelessWidget {
  const _NoChildrenYet();

  @override
  Widget build(BuildContext context) {
    final steps = [
      (
        AppTint.violet,
        Icons.person_add_alt_1_rounded,
        'Your child signs up as a Student',
        'They pick a name and a companion, then start learning.',
      ),
      (
        AppTint.sun,
        Icons.password_rounded,
        'They type your family code',
        'Me, then Family, on their account. You will see them here straight away.',
      ),
      if (Features.payments)
        (
          AppTint.mint,
          Icons.lock_open_rounded,
          'You unlock packs when they are ready',
          '₦2,500 opens the next 10 lessons in one subject, or ₦6,500 for 3 packs.',
        )
      else
        (
          AppTint.mint,
          Icons.insights_rounded,
          'Follow along',
          'Lessons finished, streaks, and where they are in each subject.',
        ),
    ];
    return KvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const KvSectionTitle(title: 'Three steps to get started'),
          for (var i = 0; i < steps.length; i++)
            KvListRow(
              divider: i > 0,
              leading: TintIcon(tint: steps[i].$1, icon: steps[i].$2),
              title: steps[i].$3,
              detail: steps[i].$4,
            ),
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

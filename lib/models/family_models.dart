import 'payment_models.dart';

/// One child linked to a parent's family.
class FamilyLearner {
  final String userId;
  final String displayName;
  final String avatarEmoji;
  final int xp;
  final int streakDays;
  final int minutesLearned;
  final DateTime? lastActivityDate;
  final List<LearnerSubjectStatus> subjects;

  const FamilyLearner({
    required this.userId,
    required this.displayName,
    required this.avatarEmoji,
    required this.xp,
    required this.streakDays,
    required this.minutesLearned,
    required this.subjects,
    this.lastActivityDate,
  });

  factory FamilyLearner.fromJson(Map<String, dynamic> json) => FamilyLearner(
    userId: json['user_id'] as String? ?? '',
    displayName: json['display_name'] as String? ?? 'Learner',
    avatarEmoji: json['avatar_emoji'] as String? ?? '🦊',
    xp: (json['xp'] as num?)?.toInt() ?? 0,
    streakDays: (json['streak_days'] as num?)?.toInt() ?? 0,
    minutesLearned: (json['minutes_learned'] as num?)?.toInt() ?? 0,
    lastActivityDate: DateTime.tryParse(
      json['last_activity_date'] as String? ?? '',
    ),
    subjects: [
      for (final item in (json['subjects'] as List? ?? const []))
        if (item is Map)
          LearnerSubjectStatus.fromJson(Map<String, dynamic>.from(item)),
    ],
  );

  /// Subjects where the parent should act: a closed pack or a lesson-8 prompt.
  List<LearnerSubjectStatus> get actionsDue => [
    for (final subject in subjects)
      if (subject.packToOffer != null) subject,
  ];

  int get lessonsCompleted =>
      subjects.fold(0, (sum, subject) => sum + subject.lessonsCompleted);

  bool get activeToday {
    final last = lastActivityDate;
    if (last == null) return false;
    final now = DateTime.now();
    return last.year == now.year &&
        last.month == now.month &&
        last.day == now.day;
  }
}

class FamilyOverview {
  final String familyId;
  final String label;
  final String? linkCode;
  final PaymentFamilyStats stats;
  final List<FamilyLearner> learners;
  final List<PaymentPurchase> purchases;

  const FamilyOverview({
    required this.familyId,
    required this.label,
    required this.linkCode,
    required this.stats,
    required this.learners,
    required this.purchases,
  });

  factory FamilyOverview.fromJson(Map<String, dynamic> json) => FamilyOverview(
    familyId: json['family_id'] as String? ?? '',
    label: json['label'] as String? ?? 'Your family',
    linkCode: json['link_code'] as String?,
    stats: PaymentFamilyStats.fromJson(
      Map<String, dynamic>.from(json['stats'] as Map? ?? const {}),
    ),
    learners: [
      for (final item in (json['learners'] as List? ?? const []))
        if (item is Map)
          FamilyLearner.fromJson(Map<String, dynamic>.from(item)),
    ],
    purchases: [
      for (final item in (json['purchases'] as List? ?? const []))
        if (item is Map)
          PaymentPurchase.fromJson(Map<String, dynamic>.from(item)),
    ],
  );

  FamilyLearner? learnerById(String? userId) {
    if (userId == null) return null;
    for (final learner in learners) {
      if (learner.userId == userId) return learner;
    }
    return null;
  }

  int get actionsDue =>
      learners.fold(0, (sum, learner) => sum + learner.actionsDue.length);
}

/// Platform-wide payment analytics for the admin console.
class PaymentAnalytics {
  final Map<String, int> totals;
  final List<PaymentSubjectAnalytics> bySubject;
  final List<PaymentFamilyRow> families;

  const PaymentAnalytics({
    required this.totals,
    required this.bySubject,
    required this.families,
  });

  factory PaymentAnalytics.fromJson(Map<String, dynamic> json) {
    final rawTotals = Map<String, dynamic>.from(json['totals'] as Map? ?? {});
    return PaymentAnalytics(
      totals: {
        for (final entry in rawTotals.entries)
          entry.key: (entry.value as num?)?.toInt() ?? 0,
      },
      bySubject: [
        for (final item in (json['by_subject'] as List? ?? const []))
          if (item is Map)
            PaymentSubjectAnalytics.fromJson(Map<String, dynamic>.from(item)),
      ],
      families: [
        for (final item in (json['families'] as List? ?? const []))
          if (item is Map)
            PaymentFamilyRow.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }

  int total(String key) => totals[key] ?? 0;
}

class PaymentSubjectAnalytics {
  final String subjectId;
  final String title;
  final int packsOwned;
  final int packsCompleted;
  final int revenueKobo;

  const PaymentSubjectAnalytics({
    required this.subjectId,
    required this.title,
    required this.packsOwned,
    required this.packsCompleted,
    required this.revenueKobo,
  });

  factory PaymentSubjectAnalytics.fromJson(Map<String, dynamic> json) =>
      PaymentSubjectAnalytics(
        subjectId: json['subject_id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        packsOwned: (json['packs_owned'] as num?)?.toInt() ?? 0,
        packsCompleted: (json['packs_completed'] as num?)?.toInt() ?? 0,
        revenueKobo: (json['revenue_kobo'] as num?)?.toInt() ?? 0,
      );

  double get completionRate =>
      packsOwned == 0 ? 0 : packsCompleted / packsOwned;
}

class PaymentFamilyRow {
  final String familyId;
  final String label;
  final PaymentFamilyStats stats;
  final List<String> subjects;

  const PaymentFamilyRow({
    required this.familyId,
    required this.label,
    required this.stats,
    required this.subjects,
  });

  factory PaymentFamilyRow.fromJson(Map<String, dynamic> json) =>
      PaymentFamilyRow(
        familyId: json['family_id'] as String? ?? '',
        label: json['label'] as String? ?? 'Family',
        stats: PaymentFamilyStats.fromJson(
          Map<String, dynamic>.from(json['stats'] as Map? ?? const {}),
        ),
        subjects: [
          for (final item in (json['subjects'] as List? ?? const [])) '$item',
        ],
      );
}

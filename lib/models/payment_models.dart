class PaymentPack {
  final String id;
  final int packIndex;
  final String title;
  final String milestoneLabel;
  final int startSequence;
  final int endSequence;
  final int lessonCount;
  final int priceKobo;

  const PaymentPack({
    required this.id,
    required this.packIndex,
    required this.title,
    required this.milestoneLabel,
    required this.startSequence,
    required this.endSequence,
    required this.lessonCount,
    required this.priceKobo,
  });

  factory PaymentPack.fromJson(Map<String, dynamic> json) => PaymentPack(
    id: json['id'] as String? ?? '',
    packIndex: _int(json['pack_index']),
    title: json['title'] as String? ?? 'Pack',
    milestoneLabel: json['milestone_label'] as String? ?? '',
    startSequence: _int(json['start_sequence']),
    endSequence: _int(json['end_sequence']),
    lessonCount: _int(json['lesson_count']),
    priceKobo: _int(json['price_kobo']),
  );

  String get priceNairaLabel => nairaLabel(priceKobo);

  bool coversSequence(int sequence) =>
      sequence >= startSequence && sequence <= endSequence;
}

class PaymentSubject {
  final String id;
  final String title;
  final String description;
  final int lessonCount;
  final List<PaymentPack> packs;

  const PaymentSubject({
    required this.id,
    required this.title,
    required this.description,
    required this.lessonCount,
    required this.packs,
  });

  factory PaymentSubject.fromJson(Map<String, dynamic> json) => PaymentSubject(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? 'Subject',
    description: json['description'] as String? ?? '',
    lessonCount: _int(json['lesson_count']),
    packs: [
      for (final item in (json['packs'] as List? ?? const []))
        if (item is Map) PaymentPack.fromJson(Map<String, dynamic>.from(item)),
    ],
  );
}

class PaymentCatalog {
  final int freeLessons;
  final int packPriceKobo;
  final int bundlePriceKobo;
  final int bundleCredits;
  final String currency;
  final List<PaymentSubject> subjects;

  const PaymentCatalog({
    required this.freeLessons,
    required this.packPriceKobo,
    required this.bundlePriceKobo,
    required this.bundleCredits,
    required this.currency,
    required this.subjects,
  });

  factory PaymentCatalog.fromJson(Map<String, dynamic> json) => PaymentCatalog(
    freeLessons: _int(json['free_lessons'], fallback: 2),
    packPriceKobo: _int(json['pack_price_kobo'], fallback: 250000),
    bundlePriceKobo: _int(json['bundle_price_kobo'], fallback: 650000),
    bundleCredits: _int(json['bundle_credits'], fallback: 3),
    currency: json['currency'] as String? ?? 'NGN',
    subjects: [
      for (final item in (json['subjects'] as List? ?? const []))
        if (item is Map)
          PaymentSubject.fromJson(Map<String, dynamic>.from(item)),
    ],
  );

  String get packPriceLabel => nairaLabel(packPriceKobo);
  String get bundlePriceLabel => nairaLabel(bundlePriceKobo);

  PaymentSubject? subjectById(String id) {
    for (final subject in subjects) {
      if (subject.id == id) return subject;
    }
    return null;
  }

  PaymentPack? packForSequence(String subjectId, int sequence) {
    final subject = subjectById(subjectId);
    if (subject == null) return null;
    for (final pack in subject.packs) {
      if (pack.coversSequence(sequence)) return pack;
    }
    return null;
  }
}

class PaymentEntitlement {
  final String id;
  final String subjectId;
  final String packId;
  final int startSequence;
  final int endSequence;

  const PaymentEntitlement({
    required this.id,
    required this.subjectId,
    required this.packId,
    required this.startSequence,
    required this.endSequence,
  });

  factory PaymentEntitlement.fromJson(Map<String, dynamic> json) =>
      PaymentEntitlement(
        id: json['id'] as String? ?? '',
        subjectId: json['subject_id'] as String? ?? '',
        packId: json['pack_id'] as String? ?? '',
        startSequence: _int(json['start_sequence']),
        endSequence: _int(json['end_sequence']),
      );

  bool covers(int sequence) =>
      sequence >= startSequence && sequence <= endSequence;
}

class PaymentPurchase {
  final String id;
  final String productType;
  final String? subjectId;
  final String? packId;
  final int amountKobo;
  final String status;
  final DateTime? createdAt;
  final DateTime? paidAt;
  final String? learnerUserId;

  const PaymentPurchase({
    required this.id,
    required this.productType,
    this.subjectId,
    this.packId,
    required this.amountKobo,
    required this.status,
    this.createdAt,
    this.paidAt,
    this.learnerUserId,
  });

  factory PaymentPurchase.fromJson(Map<String, dynamic> json) =>
      PaymentPurchase(
        id: json['id'] as String? ?? '',
        productType: json['product_type'] as String? ?? '',
        subjectId: json['subject_id'] as String?,
        packId: json['pack_id'] as String?,
        amountKobo: _int(json['amount_kobo']),
        status: json['status'] as String? ?? 'pending',
        createdAt: _date(json['created_at']),
        paidAt: _date(json['paid_at']),
        learnerUserId: json['learner_user_id'] as String?,
      );

  bool get isBundle => productType == 'bundle_3';
  String get amountLabel => nairaLabel(amountKobo);
}

class PaymentFamilyStats {
  final int paidPurchases;
  final int amountPaidKobo;
  final int bundlesBought;
  final int packsOwned;
  final int packsCompleted;
  final int repeatPurchases;
  final int subjectsPurchased;
  final bool crossSubject;
  final int creditsRemaining;
  final int learners;
  final DateTime? lastPaidAt;

  const PaymentFamilyStats({
    required this.paidPurchases,
    required this.amountPaidKobo,
    required this.bundlesBought,
    required this.packsOwned,
    required this.packsCompleted,
    required this.repeatPurchases,
    required this.subjectsPurchased,
    required this.crossSubject,
    required this.creditsRemaining,
    required this.learners,
    this.lastPaidAt,
  });

  factory PaymentFamilyStats.fromJson(Map<String, dynamic> json) =>
      PaymentFamilyStats(
        paidPurchases: _int(json['paid_purchases']),
        amountPaidKobo: _int(json['amount_paid_kobo']),
        bundlesBought: _int(json['bundles_bought']),
        packsOwned: _int(json['packs_owned']),
        packsCompleted: _int(json['packs_completed']),
        repeatPurchases: _int(json['repeat_purchases']),
        subjectsPurchased: _int(json['subjects_purchased']),
        crossSubject: json['cross_subject'] == true,
        creditsRemaining: _int(json['credits_remaining']),
        learners: _int(json['learners']),
        lastPaidAt: _date(json['last_paid_at']),
      );

  /// Kept for older call sites: 1 when the family owns packs in 2+ subjects.
  int get crossSubjectPurchases => crossSubject ? subjectsPurchased - 1 : 0;

  String get amountPaidLabel => nairaLabel(amountPaidKobo);
}

/// Where a learner is in one subject, as computed by the server.
class LearnerSubjectStatus {
  final String subjectId;
  final int lessonsTotal;
  final int lessonsCompleted;
  final int? nextSequence;
  final bool finished;
  final bool needsPack;
  final String? currentPackId;
  final String? currentPackTitle;
  final bool currentPackOwned;
  final int completedInCurrentPack;
  final int currentPackSize;
  final String? nextPackId;
  final String? nextPackTitle;
  final int nextPackPriceKobo;
  final bool nextPackOwned;
  final bool renewPromptDue;
  final List<String> ownedPackIds;

  const LearnerSubjectStatus({
    required this.subjectId,
    required this.lessonsTotal,
    required this.lessonsCompleted,
    required this.nextSequence,
    required this.finished,
    required this.needsPack,
    required this.currentPackId,
    required this.currentPackTitle,
    required this.currentPackOwned,
    required this.completedInCurrentPack,
    required this.currentPackSize,
    required this.nextPackId,
    required this.nextPackTitle,
    required this.nextPackPriceKobo,
    required this.nextPackOwned,
    required this.renewPromptDue,
    required this.ownedPackIds,
  });

  factory LearnerSubjectStatus.fromJson(Map<String, dynamic> json) =>
      LearnerSubjectStatus(
        subjectId: json['subject_id'] as String? ?? '',
        lessonsTotal: _int(json['lessons_total']),
        lessonsCompleted: _int(json['lessons_completed']),
        nextSequence: json['next_sequence'] == null
            ? null
            : _int(json['next_sequence']),
        finished: json['finished'] == true,
        needsPack: json['needs_pack'] == true,
        currentPackId: json['current_pack_id'] as String?,
        currentPackTitle: json['current_pack_title'] as String?,
        currentPackOwned: json['current_pack_owned'] == true,
        completedInCurrentPack: _int(json['completed_in_current_pack']),
        currentPackSize: _int(json['current_pack_size']),
        nextPackId: json['next_pack_id'] as String?,
        nextPackTitle: json['next_pack_title'] as String?,
        nextPackPriceKobo: _int(json['next_pack_price_kobo']),
        nextPackOwned: json['next_pack_owned'] == true,
        renewPromptDue: json['renew_prompt_due'] == true,
        ownedPackIds: [
          for (final item in (json['owned_pack_ids'] as List? ?? const []))
            '$item',
        ],
      );

  double get progress => lessonsTotal <= 0
      ? 0
      : (lessonsCompleted / lessonsTotal).clamp(0.0, 1.0).toDouble();

  /// The pack a parent should be offered next, if any.
  String? get packToOffer {
    if (needsPack && currentPackId != null) return currentPackId;
    if (renewPromptDue && nextPackId != null) return nextPackId;
    return null;
  }

  String? get packToOfferTitle {
    if (needsPack && currentPackId != null) return currentPackTitle;
    if (renewPromptDue && nextPackId != null) return nextPackTitle;
    return null;
  }
}

class PaymentAccess {
  final String familyId;
  final String? familyRole;
  final bool hasGuardian;
  final int creditsRemaining;
  final List<PaymentEntitlement> entitlements;
  final List<PaymentPurchase> purchases;
  final List<LearnerSubjectStatus> subjects;
  final PaymentFamilyStats stats;

  const PaymentAccess({
    required this.familyId,
    required this.creditsRemaining,
    required this.entitlements,
    required this.purchases,
    required this.stats,
    this.familyRole,
    this.hasGuardian = false,
    this.subjects = const [],
  });

  factory PaymentAccess.fromJson(Map<String, dynamic> json) => PaymentAccess(
    familyId: json['family_id'] as String? ?? '',
    familyRole: json['family_role'] as String?,
    hasGuardian: json['has_guardian'] == true,
    creditsRemaining: _int(json['credits_remaining']),
    entitlements: [
      for (final item in (json['entitlements'] as List? ?? const []))
        if (item is Map)
          PaymentEntitlement.fromJson(Map<String, dynamic>.from(item)),
    ],
    purchases: [
      for (final item in (json['purchases'] as List? ?? const []))
        if (item is Map)
          PaymentPurchase.fromJson(Map<String, dynamic>.from(item)),
    ],
    subjects: [
      for (final item in (json['subjects'] as List? ?? const []))
        if (item is Map)
          LearnerSubjectStatus.fromJson(Map<String, dynamic>.from(item)),
    ],
    stats: PaymentFamilyStats.fromJson(
      Map<String, dynamic>.from(json['stats'] as Map? ?? const {}),
    ),
  );

  LearnerSubjectStatus? statusFor(String subjectId) {
    for (final status in subjects) {
      if (status.subjectId == subjectId) return status;
    }
    return null;
  }

  bool ownsPack(String packId) =>
      entitlements.any((item) => item.packId == packId);

  bool hasAccess(
    String subjectId,
    int sequence, {
    Set<String>? completedLessonIds,
  }) {
    if (sequence <= 2) return true;
    if (entitlements.any(
      (item) => item.subjectId == subjectId && item.covers(sequence),
    )) {
      return true;
    }
    // Mandarin revision for lessons already completed before packs.
    if (subjectId == 'mandarin' && completedLessonIds != null) {
      final id = 'mfv1_l${sequence.toString().padLeft(2, '0')}';
      if (completedLessonIds.contains(id)) return true;
    }
    return false;
  }
}

class PaymentCheckoutSession {
  final String purchaseId;
  final String reference;
  final int amountKobo;
  final String authorizationUrl;
  final String? accessCode;
  final String productType;
  final String? packId;
  final String? subjectId;

  const PaymentCheckoutSession({
    required this.purchaseId,
    required this.reference,
    required this.amountKobo,
    required this.authorizationUrl,
    this.accessCode,
    required this.productType,
    this.packId,
    this.subjectId,
  });

  factory PaymentCheckoutSession.fromJson(Map<String, dynamic> json) =>
      PaymentCheckoutSession(
        purchaseId: json['purchaseId'] as String? ?? '',
        reference: json['reference'] as String? ?? '',
        amountKobo: _int(json['amountKobo']),
        authorizationUrl: json['authorizationUrl'] as String? ?? '',
        accessCode: json['accessCode'] as String?,
        productType: json['productType'] as String? ?? '',
        packId: json['packId'] as String?,
        subjectId: json['subjectId'] as String?,
      );
}

/// ₦2,500 style label from kobo.
String nairaLabel(int kobo) {
  final naira = (kobo / 100).round();
  final digits = naira.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${naira < 0 ? '-' : ''}₦$buffer';
}

int _int(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? fallback;
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse('$value');
}

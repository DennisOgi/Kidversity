class ClassBoardEntry {
  final String userId;
  final String displayName;
  final String avatar;
  final int weeklyXp;
  final int weeklyLessons;
  final int totalXp;
  final int totalLessons;
  final bool optedIn;
  final bool isYou;
  final int rank;

  const ClassBoardEntry({
    required this.userId,
    required this.displayName,
    required this.avatar,
    required this.weeklyXp,
    required this.weeklyLessons,
    required this.totalXp,
    required this.totalLessons,
    required this.optedIn,
    required this.isYou,
    required this.rank,
  });

  factory ClassBoardEntry.fromJson(Map<String, dynamic> json) =>
      ClassBoardEntry(
        userId: json['user_id'] as String? ?? '',
        displayName: json['display_name'] as String? ?? 'Learner',
        avatar: json['avatar'] as String? ?? '🦊',
        weeklyXp: (json['weekly_xp'] as num?)?.toInt() ?? 0,
        weeklyLessons: (json['weekly_lessons'] as num?)?.toInt() ?? 0,
        totalXp: (json['total_xp'] as num?)?.toInt() ?? 0,
        totalLessons: (json['total_lessons'] as num?)?.toInt() ?? 0,
        optedIn: json['opted_in'] as bool? ?? false,
        isYou: json['is_you'] as bool? ?? false,
        rank: (json['rank'] as num?)?.toInt() ?? 0,
      );
}

class ClassBoardSnapshot {
  final String? classId;
  final String? className;
  final DateTime weekStart;
  final bool viewerOptedIn;
  final bool viewerIsTeacher;
  final int memberCount;
  final int hiddenCount;
  final List<ClassBoardEntry> entries;

  const ClassBoardSnapshot({
    required this.weekStart,
    required this.viewerOptedIn,
    required this.viewerIsTeacher,
    required this.memberCount,
    required this.hiddenCount,
    required this.entries,
    this.classId,
    this.className,
  });

  bool get hasClass => classId != null && classId!.isNotEmpty;

  factory ClassBoardSnapshot.fromJson(Map<String, dynamic> json) {
    final weekRaw = json['week_start'] as String? ?? '';
    return ClassBoardSnapshot(
      classId: json['class_id'] as String?,
      className: json['class_name'] as String?,
      weekStart: _weekStartFrom(weekRaw),
      viewerOptedIn: json['viewer_opted_in'] as bool? ?? false,
      viewerIsTeacher: json['viewer_is_teacher'] as bool? ?? false,
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      hiddenCount: (json['hidden_count'] as num?)?.toInt() ?? 0,
      entries: [
        for (final item in json['entries'] as List? ?? const [])
          ClassBoardEntry.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
    );
  }

  String get weekLabel {
    final start = DateTime.utc(weekStart.year, weekStart.month, weekStart.day);
    final end = start.add(const Duration(days: 6));
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (start.month == end.month) {
      return '${start.day}–${end.day} ${months[start.month - 1]}';
    }
    return '${start.day} ${months[start.month - 1]} – ${end.day} ${months[end.month - 1]}';
  }
}

DateTime _weekStartFrom(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    final now = DateTime.now().toUtc();
    return DateTime.utc(now.year, now.month, now.day);
  }
  return DateTime.utc(parsed.year, parsed.month, parsed.day);
}

class AdminOverview {
  final int schoolCount;
  final int studentCount;
  final int teacherCount;
  final int reviewerCount;
  final int classCount;
  final int active7d;
  final int lessonsThisWeek;
  final int liveSessionsThisWeek;
  final int examAttemptsThisWeek;
  final int mathsAttemptsThisWeek;

  const AdminOverview({
    required this.schoolCount,
    required this.studentCount,
    required this.teacherCount,
    required this.reviewerCount,
    required this.classCount,
    required this.active7d,
    required this.lessonsThisWeek,
    required this.liveSessionsThisWeek,
    required this.examAttemptsThisWeek,
    required this.mathsAttemptsThisWeek,
  });

  factory AdminOverview.fromJson(Map<String, dynamic> json) => AdminOverview(
    schoolCount: _int(json['school_count']),
    studentCount: _int(json['student_count']),
    teacherCount: _int(json['teacher_count']),
    reviewerCount: _int(json['reviewer_count']),
    classCount: _int(json['class_count']),
    active7d: _int(json['active_7d']),
    lessonsThisWeek: _int(json['lessons_this_week']),
    liveSessionsThisWeek: _int(json['live_sessions_this_week']),
    examAttemptsThisWeek: _int(json['exam_attempts_this_week']),
    mathsAttemptsThisWeek: _int(json['maths_attempts_this_week']),
  );
}

class AdminSchoolSummary {
  final String id;
  final String name;
  final DateTime? createdAt;
  final int studentCount;
  final int teacherCount;
  final int classCount;
  final int weeklyXp;
  final DateTime? lastActivity;

  const AdminSchoolSummary({
    required this.id,
    required this.name,
    this.createdAt,
    required this.studentCount,
    required this.teacherCount,
    required this.classCount,
    required this.weeklyXp,
    this.lastActivity,
  });

  factory AdminSchoolSummary.fromJson(Map<String, dynamic> json) =>
      AdminSchoolSummary(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'School',
        createdAt: _date(json['created_at']),
        studentCount: _int(json['student_count']),
        teacherCount: _int(json['teacher_count']),
        classCount: _int(json['class_count']),
        weeklyXp: _int(json['weekly_xp']),
        lastActivity: _date(json['last_activity']),
      );
}

class AdminSchoolDetail {
  final String id;
  final String name;
  final DateTime? createdAt;
  final List<AdminSchoolClass> classes;
  final List<AdminStaffMember> staff;
  final List<AdminTopLearner> topLearners;

  const AdminSchoolDetail({
    required this.id,
    required this.name,
    this.createdAt,
    required this.classes,
    required this.staff,
    required this.topLearners,
  });

  factory AdminSchoolDetail.fromJson(Map<String, dynamic> json) =>
      AdminSchoolDetail(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'School',
        createdAt: _date(json['created_at']),
        classes: _mapList(json['classes'], AdminSchoolClass.fromJson),
        staff: _mapList(json['staff'], AdminStaffMember.fromJson),
        topLearners: _mapList(json['top_learners'], AdminTopLearner.fromJson),
      );
}

class AdminSchoolClass {
  final String id;
  final String name;
  final String? joinCode;
  final String teacherId;
  final String teacherName;
  final int memberCount;

  const AdminSchoolClass({
    required this.id,
    required this.name,
    this.joinCode,
    required this.teacherId,
    required this.teacherName,
    required this.memberCount,
  });

  factory AdminSchoolClass.fromJson(Map<String, dynamic> json) =>
      AdminSchoolClass(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Class',
        joinCode: json['join_code'] as String?,
        teacherId: json['teacher_id'] as String? ?? '',
        teacherName: json['teacher_name'] as String? ?? 'Unassigned',
        memberCount: _int(json['member_count']),
      );
}

class AdminStaffMember {
  final String userId;
  final String displayName;
  final String? email;
  final String role;
  final String avatarEmoji;

  const AdminStaffMember({
    required this.userId,
    required this.displayName,
    this.email,
    required this.role,
    required this.avatarEmoji,
  });

  factory AdminStaffMember.fromJson(Map<String, dynamic> json) =>
      AdminStaffMember(
        userId: json['user_id'] as String? ?? '',
        displayName: json['display_name'] as String? ?? 'Member',
        email: json['email'] as String?,
        role: json['role'] as String? ?? 'teacher',
        avatarEmoji: json['avatar_emoji'] as String? ?? '👤',
      );
}

class AdminTopLearner {
  final String userId;
  final String displayName;
  final String avatarEmoji;
  final int weeklyXp;
  final int lessonsCompleted;

  const AdminTopLearner({
    required this.userId,
    required this.displayName,
    required this.avatarEmoji,
    required this.weeklyXp,
    required this.lessonsCompleted,
  });

  factory AdminTopLearner.fromJson(Map<String, dynamic> json) =>
      AdminTopLearner(
        userId: json['user_id'] as String? ?? '',
        displayName: json['display_name'] as String? ?? 'Learner',
        avatarEmoji: json['avatar_emoji'] as String? ?? '🙂',
        weeklyXp: _int(json['weekly_xp']),
        lessonsCompleted: _int(json['lessons_completed']),
      );
}

class AdminUserSummary {
  final String userId;
  final String displayName;
  final String? email;
  final String? role;
  final String avatarEmoji;
  final int xp;
  final int lessonsCompleted;
  final int streakDays;
  final DateTime? lastActivity;
  final bool active;
  final List<AdminUserSchool> schools;

  const AdminUserSummary({
    required this.userId,
    required this.displayName,
    this.email,
    this.role,
    required this.avatarEmoji,
    required this.xp,
    required this.lessonsCompleted,
    required this.streakDays,
    this.lastActivity,
    required this.active,
    required this.schools,
  });

  factory AdminUserSummary.fromJson(Map<String, dynamic> json) =>
      AdminUserSummary(
        userId: json['user_id'] as String? ?? '',
        displayName: json['display_name'] as String? ?? 'User',
        email: json['email'] as String?,
        role: json['role'] as String?,
        avatarEmoji: json['avatar_emoji'] as String? ?? '🙂',
        xp: _int(json['xp']),
        lessonsCompleted: _int(json['lessons_completed']),
        streakDays: _int(json['streak_days']),
        lastActivity: _date(json['last_activity']),
        active: json['active'] as bool? ?? true,
        schools: _mapList(json['schools'], AdminUserSchool.fromJson),
      );
}

class AdminUserList {
  final int total;
  final List<AdminUserSummary> users;

  const AdminUserList({required this.total, required this.users});

  factory AdminUserList.fromJson(Map<String, dynamic> json) => AdminUserList(
    total: _int(json['total']),
    users: _mapList(json['users'], AdminUserSummary.fromJson),
  );
}

class AdminUserSchool {
  final String id;
  final String name;
  final String role;

  const AdminUserSchool({
    required this.id,
    required this.name,
    required this.role,
  });

  factory AdminUserSchool.fromJson(Map<String, dynamic> json) =>
      AdminUserSchool(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'School',
        role: json['role'] as String? ?? '',
      );
}

class AdminUserPerformance {
  final String userId;
  final String displayName;
  final String? email;
  final String? role;
  final String avatarEmoji;
  final int xp;
  final int level;
  final int streakDays;
  final int minutesLearned;
  final int lessonsCompleted;
  final DateTime? lastActivity;
  final bool active;
  final int foundationCompleted;
  final double foundationAvgScore;
  final int lessonsThisWeek;
  final List<String> completedLessonIds;
  final int examAttempts;
  final double examAvgScore;
  final int mathsAttempts;
  final double mathsAvgScore;
  final List<AdminDayCount> weeklyActivity;
  final List<AdminUserSchool> schools;

  const AdminUserPerformance({
    required this.userId,
    required this.displayName,
    this.email,
    this.role,
    required this.avatarEmoji,
    required this.xp,
    required this.level,
    required this.streakDays,
    required this.minutesLearned,
    required this.lessonsCompleted,
    this.lastActivity,
    required this.active,
    required this.foundationCompleted,
    required this.foundationAvgScore,
    required this.lessonsThisWeek,
    required this.completedLessonIds,
    required this.examAttempts,
    required this.examAvgScore,
    required this.mathsAttempts,
    required this.mathsAvgScore,
    required this.weeklyActivity,
    required this.schools,
  });

  factory AdminUserPerformance.fromJson(Map<String, dynamic> json) =>
      AdminUserPerformance(
        userId: json['user_id'] as String? ?? '',
        displayName: json['display_name'] as String? ?? 'User',
        email: json['email'] as String?,
        role: json['role'] as String?,
        avatarEmoji: json['avatar_emoji'] as String? ?? '🙂',
        xp: _int(json['xp']),
        level: _int(json['level']),
        streakDays: _int(json['streak_days']),
        minutesLearned: _int(json['minutes_learned']),
        lessonsCompleted: _int(json['lessons_completed']),
        lastActivity: _date(json['last_activity']),
        active: json['active'] as bool? ?? true,
        foundationCompleted: _int(json['foundation_completed']),
        foundationAvgScore: _double(json['foundation_avg_score']),
        lessonsThisWeek: _int(json['lessons_this_week']),
        completedLessonIds: _list(json['completed_lesson_ids'])
            .map((e) => e.toString())
            .toList(),
        examAttempts: _int(json['exam_attempts']),
        examAvgScore: _double(json['exam_avg_score']),
        mathsAttempts: _int(json['maths_attempts']),
        mathsAvgScore: _double(json['maths_avg_score']),
        weeklyActivity: _mapList(json['weekly_activity'], AdminDayCount.fromJson),
        schools: _mapList(json['schools'], AdminUserSchool.fromJson),
      );
}

class AdminDayCount {
  final DateTime day;
  final int count;

  const AdminDayCount({required this.day, required this.count});

  factory AdminDayCount.fromJson(Map<String, dynamic> json) => AdminDayCount(
    day: _date(json['day']) ?? DateTime.now(),
    count: _int(json['count']),
  );
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

double _double(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse('$value');
}

List<dynamic> _list(dynamic value) {
  if (value is List) return value;
  return const [];
}

List<T> _mapList<T>(
  dynamic value,
  T Function(Map<String, dynamic> json) fromJson,
) {
  return [
    for (final item in _list(value))
      if (item is Map) fromJson(Map<String, dynamic>.from(item)),
  ];
}

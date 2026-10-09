class SchoolClassInfo {
  final String id;
  final String name;
  final String? joinCode;
  final String teacherId;
  final String teacherName;
  final int memberCount;

  const SchoolClassInfo({
    required this.id,
    required this.name,
    required this.teacherId,
    required this.teacherName,
    required this.memberCount,
    this.joinCode,
  });

  factory SchoolClassInfo.fromJson(Map<String, dynamic> json) {
    final assigned = json['teacher_id'] as String? ?? '';
    return SchoolClassInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Class',
      joinCode: json['join_code'] as String?,
      teacherId: assigned,
      teacherName: assigned.isEmpty
          ? 'Unassigned'
          : json['teacher_name'] as String? ?? 'Teacher',
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
    );
  }

  bool get hasTeacher => teacherId.isNotEmpty;
}

class SchoolRankEntry {
  final String userId;
  final String displayName;
  final String avatar;
  final int weeklyXp;
  final int examCorrect;
  final int mathsCorrect;
  final int totalXp;
  final bool optedIn;
  final bool isYou;
  final int rank;

  const SchoolRankEntry({
    required this.userId,
    required this.displayName,
    required this.avatar,
    required this.weeklyXp,
    required this.examCorrect,
    required this.mathsCorrect,
    required this.totalXp,
    required this.optedIn,
    required this.isYou,
    required this.rank,
  });

  factory SchoolRankEntry.fromJson(Map<String, dynamic> json) =>
      SchoolRankEntry(
        userId: json['user_id'] as String? ?? '',
        displayName: json['display_name'] as String? ?? 'Learner',
        avatar: json['avatar'] as String? ?? '🦊',
        weeklyXp: (json['weekly_xp'] as num?)?.toInt() ?? 0,
        examCorrect: (json['exam_correct'] as num?)?.toInt() ?? 0,
        mathsCorrect: (json['maths_correct'] as num?)?.toInt() ?? 0,
        totalXp: (json['total_xp'] as num?)?.toInt() ?? 0,
        optedIn: json['opted_in'] as bool? ?? false,
        isYou: json['is_you'] as bool? ?? false,
        rank: (json['rank'] as num?)?.toInt() ?? 0,
      );
}

class SchoolPerson {
  final String userId;
  final String displayName;
  final String email;
  final String role;
  final List<String> classIds;

  const SchoolPerson({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.role,
    this.classIds = const [],
  });

  factory SchoolPerson.fromJson(Map<String, dynamic> json) => SchoolPerson(
    userId: json['user_id'] as String? ?? '',
    displayName: json['display_name'] as String? ?? 'Learner',
    email: json['email'] as String? ?? '',
    role: json['role'] as String? ?? 'student',
    classIds: [
      for (final id in json['class_ids'] as List? ?? const [])
        id.toString(),
    ],
  );

  bool inClass(String classId) => classIds.contains(classId);
}

class SchoolDirectory {
  final List<SchoolPerson> teachers;
  final List<SchoolPerson> students;

  const SchoolDirectory({
    this.teachers = const [],
    this.students = const [],
  });

  factory SchoolDirectory.fromJson(Map<String, dynamic> json) =>
      SchoolDirectory(
        teachers: [
          for (final item in json['teachers'] as List? ?? const [])
            SchoolPerson.fromJson(Map<String, dynamic>.from(item as Map)),
        ],
        students: [
          for (final item in json['students'] as List? ?? const [])
            SchoolPerson.fromJson(Map<String, dynamic>.from(item as Map)),
        ],
      );

  static const empty = SchoolDirectory();
}

class SchoolMembership {
  final String id;
  final String name;
  final String role;

  const SchoolMembership({
    required this.id,
    required this.name,
    required this.role,
  });

  bool get isAdmin => role == 'admin';

  factory SchoolMembership.fromJson(Map<String, dynamic> json) =>
      SchoolMembership(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'School',
        role: json['role'] as String? ?? 'student',
      );
}

class SchoolOverview {
  final String? schoolId;
  final String? schoolName;
  final String? viewerRole;
  final int studentCount;
  final List<SchoolClassInfo> classes;
  final List<SchoolRankEntry> entries;
  final List<SchoolMembership> memberships;

  const SchoolOverview({
    required this.studentCount,
    required this.classes,
    required this.entries,
    this.memberships = const [],
    this.schoolId,
    this.schoolName,
    this.viewerRole,
  });

  bool get hasSchool => schoolId != null && schoolId!.isNotEmpty;

  bool get isAdmin => viewerRole == 'admin';

  bool get canManageClasses => viewerRole == 'admin' || viewerRole == 'teacher';

  SchoolRankEntry? get you => entries.where((entry) => entry.isYou).firstOrNull;

  factory SchoolOverview.fromJson(Map<String, dynamic> json) => SchoolOverview(
    schoolId: json['school_id'] as String?,
    schoolName: json['school_name'] as String?,
    viewerRole: json['viewer_role'] as String?,
    studentCount: (json['student_count'] as num?)?.toInt() ?? 0,
    classes: [
      for (final item in json['classes'] as List? ?? const [])
        SchoolClassInfo.fromJson(Map<String, dynamic>.from(item as Map)),
    ],
    entries: [
      for (final item in json['entries'] as List? ?? const [])
        SchoolRankEntry.fromJson(Map<String, dynamic>.from(item as Map)),
    ],
    memberships: [
      for (final item in json['memberships'] as List? ?? const [])
        SchoolMembership.fromJson(Map<String, dynamic>.from(item as Map)),
    ],
  );

  static const empty = SchoolOverview(
    studentCount: 0,
    classes: [],
    entries: [],
  );
}

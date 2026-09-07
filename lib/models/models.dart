enum UserRole { student, teacher, reviewer }

class StudentPerformance {
  final String name;
  final String avatarEmoji;
  final double overallMastery;
  final int lessonsDone;
  final String strength;
  final String growthArea;
  final List<double> weeklyActivity;

  const StudentPerformance({
    required this.name,
    required this.avatarEmoji,
    required this.overallMastery,
    required this.lessonsDone,
    required this.strength,
    required this.growthArea,
    required this.weeklyActivity,
  });
}

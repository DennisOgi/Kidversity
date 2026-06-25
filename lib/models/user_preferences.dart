/// User settings stored in `user_profiles.preferences` JSONB.
class UserPreferences {
  final bool dyslexiaFriendly;
  final bool showCaptions;
  final bool joinLeaderboard;
  final String? gender;
  final int? age;

  const UserPreferences({
    this.dyslexiaFriendly = false,
    this.showCaptions = true,
    this.joinLeaderboard = true,
    this.gender,
    this.age,
  });

  factory UserPreferences.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const UserPreferences();
    return UserPreferences(
      dyslexiaFriendly: json['dyslexia_friendly'] as bool? ?? false,
      showCaptions: json['show_captions'] as bool? ?? true,
      joinLeaderboard: json['join_leaderboard'] as bool? ?? true,
      gender: json['gender'] as String?,
      age: (json['age'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'dyslexia_friendly': dyslexiaFriendly,
        'show_captions': showCaptions,
        'join_leaderboard': joinLeaderboard,
        if (gender != null) 'gender': gender,
        if (age != null) 'age': age,
      };

  UserPreferences copyWith({
    bool? dyslexiaFriendly,
    bool? showCaptions,
    bool? joinLeaderboard,
    String? gender,
    int? age,
  }) =>
      UserPreferences(
        dyslexiaFriendly: dyslexiaFriendly ?? this.dyslexiaFriendly,
        showCaptions: showCaptions ?? this.showCaptions,
        joinLeaderboard: joinLeaderboard ?? this.joinLeaderboard,
        gender: gender ?? this.gender,
        age: age ?? this.age,
      );
}

/// Subject mastery row for profile screen.
class SubjectSkill {
  final String subject;
  final double mastery;

  const SubjectSkill({required this.subject, required this.mastery});
}

/// Teacher dashboard headline metrics.
class TeacherMetrics {
  final int studentCount;
  final int lessonCount;
  final double avgMastery;

  const TeacherMetrics({
    required this.studentCount,
    required this.lessonCount,
    required this.avgMastery,
  });
}

/// Daily learning goal progress.
class DailyGoalProgress {
  final int completed;
  final int target;

  const DailyGoalProgress({required this.completed, this.target = 5});

  double get ratio => target == 0 ? 0 : (completed / target).clamp(0, 1);
}

/// User settings stored in `user_profiles.preferences` JSONB.
class UserPreferences {
  final bool dyslexiaFriendly;
  final bool showCaptions;
  final String? gender;
  final int? age;

  const UserPreferences({
    this.dyslexiaFriendly = false,
    this.showCaptions = true,
    this.gender,
    this.age,
  });

  factory UserPreferences.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const UserPreferences();
    return UserPreferences(
      dyslexiaFriendly: json['dyslexia_friendly'] as bool? ?? false,
      showCaptions: json['show_captions'] as bool? ?? true,
      gender: json['gender'] as String?,
      age: (json['age'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'dyslexia_friendly': dyslexiaFriendly,
    'show_captions': showCaptions,
    if (gender != null) 'gender': gender,
    if (age != null) 'age': age,
  };

  UserPreferences copyWith({
    bool? dyslexiaFriendly,
    bool? showCaptions,
    String? gender,
    int? age,
  }) => UserPreferences(
    dyslexiaFriendly: dyslexiaFriendly ?? this.dyslexiaFriendly,
    showCaptions: showCaptions ?? this.showCaptions,
    gender: gender ?? this.gender,
    age: age ?? this.age,
  );
}

import '../models/models.dart';

/// Pre-built personas for live demos. Password is shared for simplicity.
class DemoAccount {
  const DemoAccount({
    required this.email,
    required this.password,
    required this.displayName,
    required this.avatarEmoji,
    required this.role,
    required this.level,
    required this.xp,
    required this.streakDays,
    required this.lessonsCompleted,
    required this.minutesLearned,
    required this.buttonLabel,
    required this.buttonEmoji,
  });

  final String email;
  final String password;
  final String displayName;
  final String avatarEmoji;
  final UserRole role;
  final int level;
  final int xp;
  final int streakDays;
  final int lessonsCompleted;
  final int minutesLearned;
  final String buttonLabel;
  final String buttonEmoji;
}

abstract final class DemoAccounts {
  static const password = 'Demo1234!';

  static const student = DemoAccount(
    email: 'student@kidversity.demo',
    password: password,
    displayName: 'Chioma',
    avatarEmoji: '🦊',
    role: UserRole.student,
    level: 7,
    xp: 1840,
    streakDays: 12,
    lessonsCompleted: 23,
    minutesLearned: 540,
    buttonLabel: 'Demo as student',
    buttonEmoji: '🎒',
  );

  static const teacher = DemoAccount(
    email: 'teacher@kidversity.demo',
    password: password,
    displayName: 'Ms. Adebayo',
    avatarEmoji: '👩‍🏫',
    role: UserRole.teacher,
    level: 1,
    xp: 0,
    streakDays: 0,
    lessonsCompleted: 0,
    minutesLearned: 0,
    buttonLabel: 'Demo as teacher',
    buttonEmoji: '📚',
  );

  static const all = [student, teacher];
}

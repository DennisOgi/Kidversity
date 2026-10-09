import 'package:flutter_test/flutter_test.dart';
import 'package:kidversity/models/school_models.dart';

void main() {
  test('school overview parses classes and ranks', () {
    final overview = SchoolOverview.fromJson({
      'school_id': 's1',
      'school_name': 'Pearls Garden',
      'viewer_role': 'admin',
      'student_count': 2,
      'memberships': [
        {'id': 's1', 'name': 'Pearls Garden', 'role': 'admin'},
        {'id': 's2', 'name': 'Another School', 'role': 'teacher'},
      ],
      'classes': [
        {
          'id': 'c1',
          'name': 'Year 4',
          'join_code': 'ABC234',
          'teacher_id': 't1',
          'teacher_name': 'Ada',
          'member_count': 12,
        },
      ],
      'entries': [
        {
          'user_id': 'u1',
          'display_name': 'Zion',
          'avatar': '🦊',
          'weekly_xp': 40,
          'exam_correct': 8,
          'maths_correct': 3,
          'total_xp': 100,
          'opted_in': true,
          'is_you': false,
          'rank': 1,
        },
      ],
    });

    expect(overview.hasSchool, isTrue);
    expect(overview.isAdmin, isTrue);
    expect(overview.classes.single.joinCode, 'ABC234');
    expect(overview.classes.single.memberCount, 12);
    expect(overview.entries.single.examCorrect, 8);
    expect(overview.you, isNull);
    expect(overview.memberships, hasLength(2));
    expect(overview.memberships.last.name, 'Another School');
    expect(overview.classes.single.hasTeacher, isTrue);
  });

  test('a class without a teacher is unassigned', () {
    final info = SchoolClassInfo.fromJson({
      'id': 'c2',
      'name': 'Year 5',
      'join_code': 'XYZ890',
      'teacher_id': null,
      'teacher_name': 'Teacher',
      'member_count': 0,
    });
    expect(info.hasTeacher, isFalse);
    expect(info.teacherName, 'Unassigned');
  });

  test('school directory parses teachers and class membership', () {
    final directory = SchoolDirectory.fromJson({
      'teachers': [
        {
          'user_id': 't1',
          'display_name': 'Ada',
          'email': 'ada@school.org',
          'role': 'teacher',
          'class_ids': ['c1'],
        },
      ],
      'students': [
        {
          'user_id': 's1',
          'display_name': 'Zion',
          'email': 'zion@school.org',
          'role': 'student',
          'class_ids': [],
        },
      ],
    });
    expect(directory.teachers.single.inClass('c1'), isTrue);
    expect(directory.students.single.inClass('c1'), isFalse);
  });

  test('a student without a school gets an empty overview', () {
    final overview = SchoolOverview.fromJson({
      'school_id': null,
      'school_name': null,
      'viewer_role': null,
      'student_count': 0,
      'classes': const [],
      'entries': const [],
    });
    expect(overview.hasSchool, isFalse);
    expect(overview.canManageClasses, isFalse);
  });
}

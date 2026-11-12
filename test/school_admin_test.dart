import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidversity/data/app_state.dart';
import 'package:kidversity/features/school/school_admin_screens.dart';
import 'package:kidversity/models/school_models.dart';
import 'package:kidversity/router/navigation.dart';
import 'package:kidversity/theme/app_theme.dart';

final _overview = SchoolOverview.fromJson({
  'school_id': 's1',
  'school_name': 'Pearls Garden School',
  'viewer_role': 'admin',
  'student_count': 2,
  'classes': [
    {'id': 'c1', 'name': 'JSS 2A', 'teacher_id': 't1', 'member_count': 1},
    {'id': 'c2', 'name': 'JSS 3B', 'teacher_id': '', 'member_count': 0},
  ],
  'entries': [],
});

final _directory = SchoolDirectory.fromJson({
  'teachers': [],
  'students': [
    {
      'user_id': 's1',
      'display_name': 'Tomi Okafor',
      'email': 'tomi@mail.ng',
      'role': 'student',
      'class_ids': ['c1'],
    },
    {
      'user_id': 's2',
      'display_name': 'Bella Tijani',
      'email': 'bella@mail.ng',
      'role': 'student',
      'class_ids': [],
    },
  ],
  'people': [],
});

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1300, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        schoolOverviewProvider.overrideWith((ref) async => _overview),
        schoolDirectoryProvider.overrideWith((ref) async => _directory),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('students page lists unplaced students and offers classes', (
    tester,
  ) async {
    await _pump(tester, const SchoolStudentsScreen());

    expect(find.text('Bella Tijani'), findsOneWidget);
    // Placed students are hidden until "All" is chosen.
    expect(find.text('Tomi Okafor'), findsNothing);

    await tester.tap(find.text('Place').first);
    await tester.pumpAndSettle();

    expect(find.text('Place in JSS 2A'), findsOneWidget);
    expect(find.text('Place in JSS 3B'), findsOneWidget);
    expect(find.text('Remove from school'), findsOneWidget);
  });

  test('staff invite links carry the code', () {
    expect(staffCodeFromPath('/join/staff/KQ7M-4TZP'), 'KQ7M-4TZP');
    expect(staffCodeFromPath('/teacher/home'), isNull);
    expect(staffInviteLink('KQ7M-4TZP'), endsWith('/join/staff/KQ7M-4TZP'));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidversity/models/class_board_models.dart';
import 'package:kidversity/models/user_preferences.dart';
import 'package:kidversity/widgets/class_board_card.dart';

void main() {
  test('class board parses weekly ranks', () {
    final snap = ClassBoardSnapshot.fromJson({
      'class_id': 'c1',
      'class_name': 'Ms Fox',
      'week_start': '2026-09-07',
      'viewer_opted_in': true,
      'viewer_is_teacher': false,
      'member_count': 3,
      'hidden_count': 1,
      'entries': [
        {
          'user_id': '1',
          'display_name': 'Olala',
          'avatar': '🦊',
          'weekly_xp': 200,
          'weekly_lessons': 2,
          'total_xp': 500,
          'total_lessons': 5,
          'opted_in': true,
          'is_you': true,
          'rank': 1,
        },
      ],
    });
    expect(snap.hasClass, isTrue);
    expect(snap.weekLabel, '7–13 Sep');
    expect(snap.entries.single.weeklyXp, 200);
    expect(snap.entries.single.isYou, isTrue);
  });

  test('class board opt-in defaults off', () {
    expect(const UserPreferences().classLeaderboard, isFalse);
    expect(
      UserPreferences.fromJson({'show_captions': false}).classLeaderboard,
      isFalse,
    );
    expect(
      UserPreferences.fromJson({
        'class_leaderboard': true,
      }).toJson()['class_leaderboard'],
      isTrue,
    );
  });

  testWidgets('class board names the week and opt-in switch', (tester) async {
    final snap = ClassBoardSnapshot.fromJson({
      'class_id': 'c1',
      'class_name': 'Ms Fox',
      'week_start': '2026-09-07',
      'viewer_opted_in': false,
      'viewer_is_teacher': false,
      'member_count': 2,
      'hidden_count': 1,
      'entries': const [],
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClassBoardCard(snapshot: snap, onOptInChanged: (_) {}),
        ),
      ),
    );
    expect(find.text('Class board'), findsOneWidget);
    expect(find.text('Show me on the class board'), findsOneWidget);
    expect(find.textContaining('7–13 Sep'), findsOneWidget);
    expect(find.text('MOVEMENT'), findsOneWidget);
  });
}

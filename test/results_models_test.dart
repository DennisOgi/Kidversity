import 'package:flutter_test/flutter_test.dart';
import 'package:kidversity/models/results_models.dart';

void main() {
  test('status against target', () {
    expect(statusFor(null, 60), TargetStatus.noData);
    expect(statusFor(58, null), TargetStatus.noData);
    expect(statusFor(58, 65), TargetStatus.below);
    expect(statusFor(65, 65), TargetStatus.onTarget);
    expect(statusFor(72, 70), TargetStatus.onTarget);
    expect(statusFor(80, 70), TargetStatus.above);
  });

  test('gap and score labels read naturally', () {
    expect(gapLabel(-7), '7 points below target');
    expect(gapLabel(2), '2 points above target');
    expect(gapLabel(1), '1 point above target');
    expect(gapLabel(0), 'On target');
    expect(fmtScore(58), '58');
    expect(fmtScore(58.5), '58.5');
  });

  test('pupil profile parses server json', () {
    final p = PupilProfile.fromJson({
      'student_id': 'u1',
      'display_name': 'Amara Okafor',
      'avatar_emoji': '🦁',
      'can_edit': true,
      'term_label': 'First term 2026/2027',
      'subjects': [
        {
          'subject_id': 's1',
          'name': 'Mathematics',
          'target': 65,
          'baseline': '45.00',
          'latest': 58.0,
          'results': [
            {
              'id': 'r1',
              'kind': 'baseline',
              'title': '',
              'score': 45,
              'assessed_on': '2026-09-15',
            },
          ],
        },
        {'subject_id': 's2', 'name': 'English', 'target': null},
      ],
    });
    final maths = p.subjects.first;
    expect(maths.gap, -7);
    expect(maths.growth, 13);
    expect(maths.results.single.label, 'Baseline');
    expect(p.needsSupport, 1);
    expect(p.subjects.last.status, TargetStatus.noData);
  });

  test('class results count pupils who need support', () {
    final c = ClassResults.fromJson({
      'term_label': 'First term',
      'subjects': [
        {'id': 's1', 'name': 'Mathematics'},
      ],
      'pupils': [
        {
          'student_id': 'a',
          'display_name': 'A',
          'scores': {
            's1': {'target': 65, 'latest': 58},
          },
        },
        {
          'student_id': 'b',
          'display_name': 'B',
          'scores': {
            's1': {'target': 65, 'latest': 70},
          },
        },
      ],
    });
    expect(c.needSupport, 1);
    expect(c.pupils.first.scores['s1']!.status, TargetStatus.below);
  });
}

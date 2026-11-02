import 'package:flutter_test/flutter_test.dart';

import 'package:kidversity/models/family_models.dart';
import 'package:kidversity/models/payment_models.dart';

void main() {
  test('naira labels group thousands', () {
    expect(nairaLabel(250000), '₦2,500');
    expect(nairaLabel(650000), '₦6,500');
    expect(nairaLabel(12345600), '₦123,456');
    expect(nairaLabel(0), '₦0');
  });

  test('a learner at lesson 8 of a paid pack is offered the next pack', () {
    final status = LearnerSubjectStatus.fromJson(const {
      'subject_id': 'mandarin',
      'lessons_total': 30,
      'lessons_completed': 10,
      'next_sequence': 11,
      'finished': false,
      'needs_pack': false,
      'current_pack_id': 'mandarin_pack_1',
      'current_pack_title': 'Pack 1 · Lessons 3–12',
      'current_pack_owned': true,
      'completed_in_current_pack': 8,
      'current_pack_size': 10,
      'next_pack_id': 'mandarin_pack_2',
      'next_pack_title': 'Pack 2 · Lessons 13–22',
      'next_pack_price_kobo': 250000,
      'next_pack_owned': false,
      'renew_prompt_due': true,
      'owned_pack_ids': ['mandarin_pack_1'],
    });
    expect(status.packToOffer, 'mandarin_pack_2');
    expect(status.packToOfferTitle, 'Pack 2 · Lessons 13–22');
    expect(status.progress, closeTo(1 / 3, 0.001));
  });

  test('a learner stopped at a locked lesson is offered the current pack', () {
    final status = LearnerSubjectStatus.fromJson(const {
      'subject_id': 'maths',
      'lessons_total': 20,
      'lessons_completed': 2,
      'next_sequence': 3,
      'needs_pack': true,
      'current_pack_id': 'maths_pack_1',
      'current_pack_title': 'Pack 1 · Levels 3–12',
      'renew_prompt_due': false,
    });
    expect(status.packToOffer, 'maths_pack_1');
  });

  test('family overview counts actions due across children', () {
    final family = FamilyOverview.fromJson(const {
      'family_id': 'f1',
      'label': 'Okafor family',
      'link_code': 'FAM-AB2CD',
      'stats': {
        'paid_purchases': 2,
        'repeat_purchases': 1,
        'cross_subject': true,
      },
      'learners': [
        {
          'user_id': 'a',
          'display_name': 'Ada',
          'subjects': [
            {
              'subject_id': 'mandarin',
              'needs_pack': true,
              'current_pack_id': 'p1',
            },
            {'subject_id': 'maths', 'needs_pack': false},
          ],
        },
        {
          'user_id': 'b',
          'display_name': 'Obi',
          'subjects': [
            {
              'subject_id': 'maths',
              'renew_prompt_due': true,
              'next_pack_id': 'maths_pack_2',
            },
          ],
        },
      ],
      'purchases': [],
    });
    expect(family.actionsDue, 2);
    expect(family.learnerById('b')?.displayName, 'Obi');
    expect(family.stats.repeatPurchases, 1);
    expect(family.stats.crossSubject, isTrue);
  });
}

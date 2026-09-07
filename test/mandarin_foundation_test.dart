import 'package:flutter_test/flutter_test.dart';
import 'package:kidversity/core/error_handler.dart';
import 'package:kidversity/data/mandarin_foundation_data.dart';
import 'package:kidversity/models/models.dart';
import 'package:kidversity/models/mandarin_content.dart';
import 'package:kidversity/router/navigation.dart';
import 'package:kidversity/services/mandarin_experience_builder.dart';

void main() {
  group('Mandarin Foundation V1', () {
    test('contains three modules and thirty sequenced lessons', () {
      final course = MandarinFoundationData.course;

      expect(course.modules, hasLength(3));
      expect(course.lessons, hasLength(30));
      expect(
        course.lessons.map((lesson) => lesson.sequence),
        orderedEquals(List.generate(30, (index) => index + 1)),
      );
    });

    test('only lessons 1 to 3 are approved and playable', () {
      final playable = MandarinFoundationData.course.lessons
          .where((lesson) => lesson.isPlayable)
          .toList();

      expect(playable.map((lesson) => lesson.sequence), [1, 2, 3]);
      expect(playable.every((lesson) => lesson.assessment.length == 5), isTrue);
    });

    test('lesson sequence matches the approved Plan B brief', () {
      final titles = MandarinFoundationData.course.lessons
          .map((lesson) => lesson.title)
          .toList();

      expect(titles[3], 'What Is Your Name?');
      expect(titles[6], 'Numbers 1–5');
      expect(titles[19], 'Module 2 Quest — Review and Assessment');
      expect(titles[28], 'My First Mandarin Conversation');
      expect(titles[29], 'Mandarin Foundation Quest — Final Assessment');
    });

    test('experience builder rejects unapproved lesson shells', () {
      final shell = MandarinFoundationData.course.lessons[3];

      expect(
        () => const MandarinExperienceBuilder().build(shell),
        throwsStateError,
      );
    });

    test('experience builder preserves approved Mandarin exactly', () {
      final lesson = MandarinFoundationData.course.lessons.first;
      final experience = const MandarinExperienceBuilder().build(lesson);

      expect(experience.characterStages.first.simplified, '你好');
      expect(experience.characterStages.first.pinyin, 'nǐ hǎo');
      expect(experience.quest, hasLength(5));
    });

    test('sequential unlock requires the immediately previous lesson', () {
      final lessons = MandarinFoundationData.course.lessons;

      expect(
        isFoundationLessonUnlocked(lessons.first, const {}, lessons),
        isTrue,
      );
      expect(
        isFoundationLessonUnlocked(lessons[1], const {}, lessons),
        isFalse,
      );
      expect(
        isFoundationLessonUnlocked(lessons[1], {lessons.first.id}, lessons),
        isTrue,
      );
      expect(
        isFoundationLessonUnlocked(lessons[2], {lessons.first.id}, lessons),
        isFalse,
      );
    });
  });

  group('Plan B roles', () {
    test('reviewer routes resolve to reviewer role', () {
      expect(roleFromPath('/reviewer/queue'), UserRole.reviewer);
    });

    test('Foundation routes resolve to student role', () {
      expect(roleFromPath('/student/foundation/mfv1_l01'), UserRole.student);
    });

    test('reviewer routes are protected', () {
      expect(isProtectedRoute('/reviewer/queue'), isTrue);
    });
  });

  group('Operation results', () {
    test('void operations can report successful completion', () {
      final result = Result<void>.success(null);

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
    });
  });
}

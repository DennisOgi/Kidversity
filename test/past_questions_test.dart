import 'package:flutter_test/flutter_test.dart';
import 'package:kidversity/models/models.dart';
import 'package:kidversity/models/past_questions_models.dart';
import 'package:kidversity/router/navigation.dart';

void main() {
  test('student exam routes stay protected in the student space', () {
    expect(AppRoutes.studentExams, '/student/exams');
    expect(AppRoutes.studentExamSession, '/student/exams/session');
    expect(roleFromPath(AppRoutes.studentExams), UserRole.student);
    expect(isProtectedRoute(AppRoutes.studentExamSession), isTrue);
  });

  test('exam labels and blurbs cover every Sdash slug family', () {
    const cases = [
      PastExamType(id: 1, name: 'UTME', slug: 'utme'),
      PastExamType(id: 2, name: 'WASSCE', slug: 'wassce'),
      PastExamType(id: 3, name: 'NECO', slug: 'neco'),
      PastExamType(id: 4, name: 'Post-UTME', slug: 'post-utme'),
      PastExamType(id: 5, name: 'Post-UTME AAUA', slug: 'post-utme-aaua'),
      PastExamType(id: 6, name: 'University', slug: 'university'),
    ];

    expect(cases[0].shortLabel, 'UTME');
    expect(cases[1].shortLabel, 'WASSCE');
    expect(cases[2].shortLabel, 'NECO');
    expect(cases[3].shortLabel, 'Post-UTME');
    expect(cases[4].shortLabel, 'Post-UTME');
    expect(cases[5].shortLabel, 'University');
    expect(cases[0].blurb, contains('UTME'));
    expect(cases[4].blurb, isNotEmpty);
  });

  test('practice modes map to API-safe question limits', () {
    expect(PastPracticeMode.quick.limit, 10);
    expect(PastPracticeMode.standard.limit, 20);
    expect(PastPracticeMode.challenge.limit, 40);
    expect(PastPracticeMode.challenge.limit, lessThanOrEqualTo(50));
  });

  test('PastQuestion parses options, skips empty e, and grades answers', () {
    final question = PastQuestion.fromJson({
      'id': 4821,
      'question': 'Which of the following is table salt?',
      'section': 'Use the passage.',
      'option': {
        'a': 'NaCl',
        'b': 'KCl',
        'c': 'CaCO3',
        'd': 'NaOH',
        'e': '',
      },
      'answer': 'A',
      'solution': 'NaCl is sodium chloride.',
      'image': null,
      'examtype': 'UTME',
      'examyear': 2022,
      'university': null,
    });

    expect(question.id, 4821);
    expect(question.options.map((o) => o.key), ['a', 'b', 'c', 'd']);
    expect(question.answerKey, 'a');
    expect(question.examYear, '2022');
    expect(question.isCorrect('a'), isTrue);
    expect(question.isCorrect('b'), isFalse);
    expect(question.correctText, 'NaCl');
    expect(question.section, 'Use the passage.');
  });

  test('session config headline includes exam, subject, and year', () {
    const config = PastQuestionsSessionConfig(
      exam: PastExamType(id: 1, name: 'UTME', slug: 'utme'),
      subject: PastSubject(id: 2, name: 'Biology', slug: 'biology'),
      year: 2021,
      mode: PastPracticeMode.standard,
    );
    expect(config.headline, 'UTME · Biology · 2021');
  });

  test('sandbox-locked subjects are English and Mathematics only', () {
    expect(
      const PastSubject(id: 1, name: 'English', slug: 'english').isSandboxLocked,
      isTrue,
    );
    expect(
      const PastSubject(
        id: 2,
        name: 'Mathematics',
        slug: 'mathematics',
      ).isSandboxLocked,
      isTrue,
    );
    expect(
      const PastSubject(id: 3, name: 'Biology', slug: 'biology').isSandboxLocked,
      isFalse,
    );
  });

  test('university exams hide SSCE-only subjects', () {
    const university = PastExamType(
      id: 9,
      name: 'University',
      slug: 'university',
    );
    const subjects = [
      PastSubject(id: 1, name: 'Biology', slug: 'biology'),
      PastSubject(id: 2, name: 'Home Economics', slug: 'homeeconomics'),
      PastSubject(id: 3, name: 'Civic Education', slug: 'civiledu'),
      PastSubject(id: 4, name: 'Current Affairs', slug: 'currentaffairs'),
      PastSubject(id: 5, name: 'Fine Art', slug: 'fineart'),
    ];
    final scoped = university.subjectsFor(subjects);
    expect(scoped.map((s) => s.slug), ['biology', 'currentaffairs']);
    expect(university.isUniversityFamily, isTrue);
  });
}

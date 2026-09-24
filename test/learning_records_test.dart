import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kidversity/features/reports/report_content.dart';
import 'package:kidversity/features/student/maths_bank.dart';
import 'package:kidversity/models/learning_records_models.dart';
import 'package:kidversity/models/past_questions_models.dart';

PastQuestion _question(int id) => PastQuestion(
  id: id,
  question: 'Question $id',
  options: const [
    PastQuestionOption(key: 'a', text: 'One'),
    PastQuestionOption(key: 'b', text: 'Two'),
  ],
  answerKey: 'b',
  examType: 'utme',
  examYear: '2019',
  solution: 'Because two.',
);

ExamAttempt _attempt(String subject, int correct, int total) => ExamAttempt(
  id: '$subject$correct',
  userId: 'u',
  examSlug: 'utme',
  examLabel: 'UTME',
  subjectSlug: subject.toLowerCase(),
  subjectName: subject,
  year: null,
  mode: 'standard',
  total: total,
  correct: correct,
  durationSeconds: 600,
  assignmentId: null,
  createdAt: DateTime.now(),
);

void main() {
  test('saved misses replay exactly as they came from Sdash', () {
    final original = _question(7);
    final copy = PastQuestion.fromJson(original.toJson());
    expect(copy.id, 7);
    expect(copy.question, 'Question 7');
    expect(copy.options.map((o) => o.key), ['a', 'b']);
    expect(copy.answerKey, 'b');
    expect(copy.solution, 'Because two.');
    expect(copy.isCorrect('B'), isTrue);
  });

  test('every maths level offers four options including the answer', () {
    final random = Random(42);
    for (final level in mathsLevels) {
      for (var i = 0; i < 200; i++) {
        final sum = makeMathsSum(level.sequence, random);
        expect(sum.options, contains(sum.answer), reason: sum.prompt);
        expect(sum.options.toSet(), hasLength(4), reason: sum.prompt);
      }
    }
  });

  test('fraction and percentage answers are whole numbers that check out', () {
    final random = Random(7);
    for (var i = 0; i < 200; i++) {
      final fraction = makeMathsSum(7, random);
      final match = RegExp(r'(\d+)/(\d+) of (\d+)').firstMatch(fraction.prompt)!;
      final top = int.parse(match.group(1)!);
      final bottom = int.parse(match.group(2)!);
      final whole = int.parse(match.group(3)!);
      expect(int.parse(fraction.answer) * bottom, whole * top);

      final percent = makeMathsSum(8, random);
      final p = RegExp(r'(\d+)% of (\d+)').firstMatch(percent.prompt)!;
      expect(
        int.parse(percent.answer) * 100,
        int.parse(p.group(1)!) * int.parse(p.group(2)!),
      );
    }
  });

  test('mistake groups build a retry session capped at twenty', () {
    final mistakes = [
      for (var i = 0; i < 25; i++)
        ExamMistake(
          questionId: i,
          examSlug: 'utme',
          examLabel: 'UTME',
          subjectSlug: 'biology',
          subjectName: 'Biology',
          question: _question(i),
          missCount: i % 3 + 1,
          lastMissedAt: DateTime.now(),
        ),
    ];
    final groups = groupMistakes(mistakes);
    expect(groups, hasLength(1));
    final config = groups.single.retryConfig();
    expect(config.isRetry, isTrue);
    expect(config.wireMode, 'retry');
    expect(config.preset, hasLength(20));
    expect(config.isMock, isFalse);
  });

  test('mock mode gives UTME pacing', () {
    expect(PastPracticeMode.mock.limit, 40);
    expect(PastPracticeMode.mock.timeLimit, const Duration(minutes: 30));
    expect(PastPracticeMode.quick.timeLimit, isNull);
  });

  test('exam assignments open the right paper and hand in on finish', () {
    final assignment = ClassAssignment(
      id: 'a1',
      classId: 'c1',
      kind: AssignmentKind.exam,
      title: '20 UTME Biology questions',
      config: const {
        'exam_slug': 'utme',
        'exam_name': 'UTME',
        'subject_slug': 'biology',
        'subject_name': 'Biology',
        'year': 2019,
        'count': 20,
      },
      dueAt: null,
      createdAt: DateTime.now(),
    );
    final config = assignment.examConfig!;
    expect(config.assignmentId, 'a1');
    expect(config.mode, PastPracticeMode.standard);
    expect(config.year, 2019);
    expect(config.subject.slug, 'biology');
  });

  test('reports flag a weak subject and the next maths level', () {
    final report = ProgressReport(
      userId: 'u',
      name: 'Ada',
      avatar: '🦊',
      lessons: const [],
      attempts: [_attempt('Chemistry', 8, 20), _attempt('Biology', 18, 20)],
      maths: [
        MathsResult(level: 1, correct: 9, total: 10, createdAt: DateTime.now()),
      ],
      openMistakes: 12,
      generatedAt: DateTime.now(),
    );
    expect(report.examAverage, 65);
    expect(report.mathsLevelsPassed, {1});
    final steps = reportNextSteps(report);
    expect(steps.first, contains('Chemistry'));
    expect(steps.any((s) => s.contains('level 2')), isTrue);
    expect(steps.any((s) => s.contains('12 missed')), isTrue);

    final html = reportHtml(report);
    expect(html, contains('Ada'));
    expect(html, contains('window.print()'));
  });

  test('report html escapes student names', () {
    final report = ProgressReport(
      userId: 'u',
      name: '<script>x</script>',
      avatar: '🦊',
      lessons: const [],
      attempts: const [],
      maths: const [],
      openMistakes: 0,
      generatedAt: DateTime.now(),
    );
    expect(reportHtml(report), isNot(contains('<script>x')));
  });
}

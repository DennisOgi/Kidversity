import 'package:flutter_test/flutter_test.dart';
import 'package:kidversity/features/student/exam_topics.dart';
import 'package:kidversity/models/learning_records_models.dart';
import 'package:kidversity/models/past_questions_models.dart';

PastQuestion _question(
  int id,
  String stem, {
  String? solution,
  String answer = 'a',
  List<PastQuestionOption>? options,
}) {
  return PastQuestion(
    id: id,
    question: stem,
    options:
        options ??
        const [
          PastQuestionOption(key: 'a', text: 'One'),
          PastQuestionOption(key: 'b', text: 'Two'),
        ],
    answerKey: answer,
    examType: 'UTME',
    examYear: '2020',
    solution: solution,
  );
}

void main() {
  test('ecological succession belongs to biology ecology', () {
    final topic = topicForQuestion(
      'biology',
      _question(
        1,
        'Ecological succession is the gradual change of a community.',
      ),
    );
    expect(topic?.id, 'ecology');
  });

  test('the first matching topic owns a question', () {
    final topic = topicForQuestion(
      'biology',
      _question(2, 'Succession changes the population around a cell nucleus.'),
    );
    expect(topic?.id, 'ecology');
    final ecology = examTopicById('biology', 'ecology')!;
    final cells = examTopicById('biology', 'cells')!;
    final owned = questionsForTopic('biology', cells, [
      _question(2, 'Succession changes the population around a cell nucleus.'),
    ]);
    expect(
      questionsForTopic('biology', ecology, [
        _question(
          2,
          'Succession changes the population around a cell nucleus.',
        ),
      ]),
      hasLength(1),
    );
    expect(owned, isEmpty);
  });

  test('a topic keeps solved questions first and stops at eight', () {
    final ecology = examTopicById('biology', 'ecology')!;
    final questions = [
      for (var i = 0; i < 10; i++)
        _question(
          i,
          'Food chain $i in this habitat.',
          solution: i >= 7 ? 'Worked solution $i' : null,
        ),
    ];
    final picked = questionsForTopic('biology', ecology, questions);
    expect(picked, hasLength(examTopicSize));
    expect(picked.take(3).map((q) => q.id), [7, 8, 9]);
  });

  test('unchecked or empty questions are skipped', () {
    final topic = topicForQuestion(
      'biology',
      _question(3, 'A habitat with no keyed answer.', answer: ''),
    );
    expect(topic, isNull);
  });

  test('a topic preset is practice, not a mistake retry', () {
    final config = PastQuestionsSessionConfig(
      exam: const PastExamType(id: 1, name: 'UTME', slug: 'utme'),
      subject: const PastSubject(id: 2, name: 'Biology', slug: 'biology'),
      mode: PastPracticeMode.quick,
      preset: [_question(4, 'A food web links habitats.')],
      topicId: 'ecology',
      topicTitle: 'Ecology',
    );
    expect(config.isTopic, isTrue);
    expect(config.isRetry, isFalse);
    expect(config.wireMode, 'quick');
    expect(config.headline, 'UTME · Biology · Ecology');
    expect(topicCleared(6, 8), isTrue);
    expect(topicCleared(5, 8), isFalse);
  });

  test('a topic assignment stays an exam and opens that topic', () {
    final assignment = ClassAssignment(
      id: 't1',
      classId: 'c1',
      kind: AssignmentKind.exam,
      title: 'UTME Biology: Ecology',
      config: const {
        'exam_slug': 'utme',
        'exam_name': 'UTME',
        'subject_slug': 'biology',
        'subject_name': 'Biology',
        'count': 8,
        'topic_id': 'ecology',
        'topic_title': 'Ecology',
      },
      dueAt: null,
      createdAt: DateTime.now(),
    );
    final config = assignment.examConfig!;
    expect(config.topicId, 'ecology');
    expect(config.topicTitle, 'Ecology');
    expect(config.mode, PastPracticeMode.quick);
    expect(config.wireMode, 'quick');
    expect(config.isRetry, isFalse);
  });
}

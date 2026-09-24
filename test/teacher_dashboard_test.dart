import 'package:flutter_test/flutter_test.dart';
import 'package:kidversity/services/foundation_progress_service.dart';

FoundationStudentProgress _student({
  required String id,
  required String name,
  required LearningMovement movement,
  int completed = 0,
  double average = 0,
  int thisWeek = 0,
  List<String> reasons = const [],
  List<StruggleItem> struggles = const [],
}) {
  return FoundationStudentProgress(
    userId: id,
    name: name,
    avatarEmoji: '🦊',
    completedLessonIds: {for (var i = 0; i < completed; i++) 'l$i'},
    averageScore: average,
    scoresByLesson: {
      for (var i = 0; i < completed; i++) 'l$i': average.round(),
    },
    weakItemIds: [for (final item in struggles) item.key],
    lastCompletedAt: completed == 0
        ? null
        : DateTime.now().subtract(Duration(days: thisWeek > 0 ? 1 : 20)),
    lessonsThisWeek: thisWeek,
    lessonsPreviousWeek: 0,
    struggles: struggles,
    strengths: average >= 80 ? const ['Greetings'] : const [],
    attentionReasons: reasons,
    movement: movement,
  );
}

void main() {
  test('class dashboard ranks attention and aggregates hotspots', () {
    final quiet = _student(
      id: '1',
      name: 'Ada',
      movement: LearningMovement.quiet,
      reasons: const ['No lesson finished in 14+ days'],
    );
    final rising = _student(
      id: '2',
      name: 'Ben',
      movement: LearningMovement.rising,
      completed: 4,
      average: 90,
      thisWeek: 2,
    );
    final struggling = _student(
      id: '3',
      name: 'Cara',
      movement: LearningMovement.struggling,
      completed: 3,
      average: 48,
      thisWeek: 1,
      reasons: const ['Average score below 60%'],
      struggles: const [
        StruggleItem(
          key: 'nihao',
          label: '你好',
          detail: 'hello',
          missCount: 2,
          lessonTitle: 'Greetings',
        ),
        StruggleItem(
          key: 'xiexie',
          label: '谢谢',
          detail: 'thank you',
          missCount: 1,
          lessonTitle: 'Greetings',
        ),
      ],
    );

    final board = FoundationProgressService.instance.buildDashboard([
      rising,
      quiet,
      struggling,
    ]);

    expect(board.attentionQueue.map((s) => s.name), ['Cara', 'Ada']);
    expect(board.moversThisWeek.map((s) => s.name), ['Ben', 'Cara']);
    expect(board.lessonsThisWeek, 3);
    expect(board.classHotspots.first.label, '你好');
    expect(board.classHotspots.first.missCount, 2);
  });

  test('learner movement labels are presentation-ready', () {
    expect(
      _student(
        id: '1',
        name: 'Ada',
        movement: LearningMovement.rising,
      ).movementLabel,
      'Rising',
    );
    expect(
      _student(
        id: '2',
        name: 'Ben',
        movement: LearningMovement.struggling,
      ).movementLabel,
      'Needs support',
    );
  });
}

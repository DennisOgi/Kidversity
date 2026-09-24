enum RopePullBank { lessons15, module1, dailyReview, pastQuestions, maths }

extension RopePullBankX on RopePullBank {
  String get wire {
    switch (this) {
      case RopePullBank.lessons15:
        return 'lessons_1_5';
      case RopePullBank.module1:
        return 'module_1';
      case RopePullBank.dailyReview:
        return 'daily_review';
      case RopePullBank.pastQuestions:
        return 'past_questions';
      case RopePullBank.maths:
        return 'maths';
    }
  }

  String get title {
    switch (this) {
      case RopePullBank.lessons15:
        return 'Lessons 1–5';
      case RopePullBank.module1:
        return 'Module 1';
      case RopePullBank.dailyReview:
        return 'Daily review words';
      case RopePullBank.pastQuestions:
        return 'Exam practice';
      case RopePullBank.maths:
        return 'Four operations';
    }
  }

  String get subtitle {
    switch (this) {
      case RopePullBank.lessons15:
        return 'Hello, names, numbers — the first week';
      case RopePullBank.module1:
        return 'Everything through the Module 1 quest';
      case RopePullBank.dailyReview:
        return 'Words you have already unlocked';
      case RopePullBank.pastQuestions:
        return 'One exam, one subject, first correct tug';
      case RopePullBank.maths:
        return 'Times tables, mixed sums, and one-step problems';
    }
  }

  static RopePullBank fromWire(String value) {
    return switch (value) {
      'module_1' => RopePullBank.module1,
      'daily_review' => RopePullBank.dailyReview,
      'past_questions' => RopePullBank.pastQuestions,
      'maths' => RopePullBank.maths,
      _ => RopePullBank.lessons15,
    };
  }
}

class RopePullQuestion {
  final String id;
  final String simplified;
  final String pinyin;
  final String english;
  final List<String> options;
  final String answer;
  final String? audioUrl;
  final String? prompt;
  final String? solution;
  final bool split;
  final String? kind;

  const RopePullQuestion({
    required this.id,
    required this.simplified,
    required this.pinyin,
    required this.english,
    required this.options,
    required this.answer,
    this.audioUrl,
    this.prompt,
    this.solution,
    this.split = false,
    this.kind,
  });

  RopePullQuestion copyWith({bool? split, String? kind}) => RopePullQuestion(
    id: id,
    simplified: simplified,
    pinyin: pinyin,
    english: english,
    options: options,
    answer: answer,
    audioUrl: audioUrl,
    prompt: prompt,
    solution: solution,
    split: split ?? this.split,
    kind: kind ?? this.kind,
  );

  bool get isExamPrompt => prompt != null && prompt!.trim().isNotEmpty;

  factory RopePullQuestion.fromJson(Map<String, dynamic> json) {
    final options = (json['options'] as List? ?? const [])
        .map((item) => item.toString())
        .toList();
    return RopePullQuestion(
      id: json['id'] as String? ?? '',
      simplified: json['simplified'] as String? ?? '',
      pinyin: json['pinyin'] as String? ?? '',
      english: json['english'] as String? ?? '',
      options: options,
      answer: json['answer'] as String? ?? '',
      audioUrl: json['audio_url'] as String?,
      prompt: json['prompt'] as String?,
      solution: json['solution'] as String?,
      split: json['split'] == true,
      kind: json['kind'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'simplified': simplified,
    'pinyin': pinyin,
    'english': english,
    'options': options,
    'answer': answer,
    if (audioUrl != null) 'audio_url': audioUrl,
    if (prompt != null && prompt!.trim().isNotEmpty) 'prompt': prompt,
    if (solution != null && solution!.trim().isNotEmpty) 'solution': solution,
    if (split) 'split': true,
    if (kind != null) 'kind': kind,
  };
}

enum RopePullStatus { lobby, playing, finished }

enum RopePullOutcome { blue, red, draw }

class RopePullPlayer {
  final String userId;
  final String displayName;
  final String avatar;
  final String team;

  const RopePullPlayer({
    required this.userId,
    required this.displayName,
    required this.avatar,
    required this.team,
  });

  bool get isBlue => team == 'blue';

  factory RopePullPlayer.fromJson(Map<String, dynamic> json) => RopePullPlayer(
    userId: json['user_id'] as String? ?? '',
    displayName: json['display_name'] as String? ?? 'Learner',
    avatar: json['avatar'] as String? ?? '🦊',
    team: json['team'] as String? ?? 'blue',
  );
}

class RopePullAnswer {
  final String userId;
  final int roundIndex;
  final String selected;
  final bool isCorrect;

  const RopePullAnswer({
    required this.userId,
    required this.roundIndex,
    required this.selected,
    required this.isCorrect,
  });

  factory RopePullAnswer.fromJson(Map<String, dynamic> json) => RopePullAnswer(
    userId: json['user_id'] as String? ?? '',
    roundIndex: (json['round_index'] as num?)?.toInt() ?? 0,
    selected: json['selected'] as String? ?? '',
    isCorrect: json['is_correct'] as bool? ?? false,
  );
}

class RopePullRoom {
  final String id;
  final String hostId;
  final String joinCode;
  final RopePullBank bank;
  final RopePullStatus status;
  final int currentRound;
  final DateTime? roundStartedAt;
  final int ropeScore;
  final List<RopePullQuestion> questions;

  const RopePullRoom({
    required this.id,
    required this.hostId,
    required this.joinCode,
    required this.bank,
    required this.status,
    required this.currentRound,
    required this.ropeScore,
    required this.questions,
    this.roundStartedAt,
  });

  factory RopePullRoom.fromJson(Map<String, dynamic> json) {
    final questionsRaw = json['questions'] as List? ?? const [];
    final status = switch (json['status'] as String?) {
      'playing' => RopePullStatus.playing,
      'finished' => RopePullStatus.finished,
      _ => RopePullStatus.lobby,
    };
    return RopePullRoom(
      id: json['id'] as String? ?? '',
      hostId: json['host_id'] as String? ?? '',
      joinCode: json['join_code'] as String? ?? '',
      bank: RopePullBankX.fromWire(json['bank'] as String? ?? ''),
      status: status,
      currentRound: (json['current_round'] as num?)?.toInt() ?? 0,
      roundStartedAt: DateTime.tryParse(
        json['round_started_at'] as String? ?? '',
      )?.toUtc(),
      ropeScore: (json['rope_score'] as num?)?.toInt() ?? 0,
      questions: questionsRaw
          .map(
            (item) => RopePullQuestion.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }

  bool get isSplit =>
      questions.length >= 4 && questions.first.split;

  int get roundCount => isSplit ? questions.length ~/ 2 : questions.length;

  bool get isExamMatch =>
      bank == RopePullBank.pastQuestions ||
      bank == RopePullBank.maths ||
      questions.any(
        (question) =>
            question.isExamPrompt ||
            question.kind == 'exam' ||
            question.kind == 'maths',
      );

  bool get isMathsMatch =>
      bank == RopePullBank.maths ||
      questions.any((question) => question.kind == 'maths');

  String get roundLabel {
    if (isMathsMatch) return 'Four operations';
    if (isExamMatch) return 'Exam practice';
    return bank.title;
  }

  int get roundSeconds {
    if (isMathsMatch) return 15;
    if (isExamMatch) return 25;
    return 10;
  }

  RopePullQuestion? get currentQuestion {
    if (questions.isEmpty) return null;
    if (!isSplit) {
      return questions[currentRound.clamp(0, questions.length - 1)];
    }
    return questionFor('blue');
  }

  RopePullQuestion? questionFor(String team) {
    if (questions.isEmpty) return null;
    if (!isSplit) {
      return questions[currentRound.clamp(0, questions.length - 1)];
    }
    final index = currentRound * 2 + (team == 'red' ? 1 : 0);
    if (index < 0 || index >= questions.length) return null;
    return questions[index];
  }
}

class RopePullSnapshot {
  final RopePullRoom room;
  final List<RopePullPlayer> players;
  final List<RopePullAnswer> answers;

  const RopePullSnapshot({
    required this.room,
    required this.players,
    required this.answers,
  });

  factory RopePullSnapshot.fromJson(Map<String, dynamic> json) {
    final room = RopePullRoom.fromJson(
      Map<String, dynamic>.from(json['room'] as Map),
    );
    final players = (json['players'] as List? ?? const [])
        .map(
          (item) =>
              RopePullPlayer.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    final answers = (json['answers'] as List? ?? const [])
        .map(
          (item) =>
              RopePullAnswer.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    return RopePullSnapshot(room: room, players: players, answers: answers);
  }

  List<RopePullPlayer> get blue =>
      players.where((player) => player.isBlue).toList();
  List<RopePullPlayer> get red =>
      players.where((player) => !player.isBlue).toList();

  RopePullPlayer? playerFor(String? userId) {
    if (userId == null) return null;
    for (final player in players) {
      if (player.userId == userId) return player;
    }
    return null;
  }

  RopePullAnswer? answerFor(String userId, int round) {
    for (final answer in answers) {
      if (answer.userId == userId && answer.roundIndex == round) return answer;
    }
    return null;
  }

  int get blueTugs {
    final rounds = <int>{};
    for (final answer in answers.where((item) => item.isCorrect)) {
      if (playerFor(answer.userId)?.isBlue == true) {
        rounds.add(answer.roundIndex);
      }
    }
    return rounds.length;
  }

  int get redTugs {
    final rounds = <int>{};
    for (final answer in answers.where((item) => item.isCorrect)) {
      final player = playerFor(answer.userId);
      if (player != null && !player.isBlue) rounds.add(answer.roundIndex);
    }
    return rounds.length;
  }

  RopePullOutcome get outcome {
    if (room.ropeScore < 0) return RopePullOutcome.blue;
    if (room.ropeScore > 0) return RopePullOutcome.red;
    return RopePullOutcome.draw;
  }

  int correctCountFor(String userId) => answers
      .where((item) => item.userId == userId && item.isCorrect)
      .length;

  List<RopePullQuestion> missedBy(String userId) {
    final team = playerFor(userId)?.team ?? 'blue';
    final missed = <RopePullQuestion>[];
    for (var i = 0; i < room.roundCount; i++) {
      final answer = answerFor(userId, i);
      final question = room.isSplit
          ? room.questions[i * 2 + (team == 'red' ? 1 : 0)]
          : room.questions[i];
      if (answer == null || !answer.isCorrect) missed.add(question);
    }
    return missed;
  }
}

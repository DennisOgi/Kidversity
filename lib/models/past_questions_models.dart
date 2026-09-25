class PastExamType {
  final int id;
  final String name;
  final String slug;

  const PastExamType({
    required this.id,
    required this.name,
    required this.slug,
  });

  factory PastExamType.fromJson(Map<String, dynamic> json) => PastExamType(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? 'Exam',
    slug: json['slug'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'slug': slug};

  String get shortLabel {
    final upper = name.toUpperCase();
    if (upper.contains('WASSCE')) return 'WASSCE';
    if (upper.contains('NECO')) return 'NECO';
    if (upper == 'UTME' || upper.contains('JAMB')) return 'UTME';
    if (upper.contains('POST')) {
      return name.trim().isEmpty ? 'Post-UTME' : name.trim();
    }
    if (upper.contains('UNIVERSITY')) return 'University';
    return name;
  }

  String get blurb {
    if (slug == 'utme') {
      return 'JAMB-style UTME practice across core subjects.';
    }
    if (slug == 'wassce') {
      return 'WAEC WASSCE papers with worked solutions.';
    }
    if (slug == 'neco') {
      return 'NECO past questions for SSCE readiness.';
    }
    if (slug.contains('post-utme')) {
      return 'University screening drills — pick a subject used in Post-UTME.';
    }
    if (slug == 'university') {
      return 'University packs — Use of English & screening subjects, not full SSCE.';
    }
    return 'Past questions for $shortLabel.';
  }

  bool get isUniversityFamily =>
      slug == 'university' || slug.contains('post-utme');

  bool get isSsceFamily => slug == 'wassce' || slug == 'neco';

  /// Paid Sdash plans expose the full subject list for every exam type.
  List<PastSubject> subjectsFor(List<PastSubject> all) => all;
}

class PastSubject {
  final int id;
  final String name;
  final String slug;

  const PastSubject({required this.id, required this.name, required this.slug});

  factory PastSubject.fromJson(Map<String, dynamic> json) => PastSubject(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? 'Subject',
    slug: json['slug'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'slug': slug};

  /// Kept so older call sites compile. The paid Sdash plan unlocks every subject.
  bool get isSandboxLocked => false;

  String get family => switch (slug) {
    'biology' ||
    'chemistry' ||
    'physics' ||
    'mathematics' ||
    'agriculture' ||
    'computer' ||
    'geology' => 'Science',
    'geography' ||
    'government' ||
    'economics' ||
    'history' ||
    'currentaffairs' ||
    'civiledu' ||
    'crk' ||
    'irk' => 'Social science',
    'accounting' || 'commerce' || 'insurance' => 'Commercial',
    'english' ||
    'englishlit' ||
    'arabic' ||
    'hausa' ||
    'igbo' ||
    'yoruba' => 'Languages',
    _ => 'Creative',
  };
}

class PastQuestionOption {
  final String key;
  final String text;

  const PastQuestionOption({required this.key, required this.text});
}

class PastQuestion {
  final int id;
  final String question;
  final String? section;
  final List<PastQuestionOption> options;
  final String answerKey;
  final String? solution;
  final String? imageUrl;
  final String examType;
  final String examYear;
  final String? university;

  const PastQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.answerKey,
    required this.examType,
    required this.examYear,
    this.section,
    this.solution,
    this.imageUrl,
    this.university,
  });

  factory PastQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['option'];
    final options = <PastQuestionOption>[];
    if (rawOptions is Map) {
      for (final entry in rawOptions.entries) {
        final text = entry.value?.toString().trim() ?? '';
        if (text.isEmpty) continue;
        options.add(
          PastQuestionOption(
            key: entry.key.toString().toLowerCase(),
            text: text,
          ),
        );
      }
      options.sort((a, b) => a.key.compareTo(b.key));
    }
    return PastQuestion(
      id: (json['id'] as num?)?.toInt() ?? 0,
      question: json['question'] as String? ?? '',
      section: json['section'] as String?,
      options: options,
      answerKey: (json['answer'] as String? ?? '').toLowerCase().trim(),
      solution: json['solution'] as String?,
      imageUrl: json['image'] as String?,
      examType: json['examtype'] as String? ?? '',
      examYear: json['examyear']?.toString() ?? '',
      university: json['university'] as String?,
    );
  }

  /// Same shape as the Sdash payload, so saved misses replay without the API.
  Map<String, dynamic> toJson() => {
    'id': id,
    'question': question,
    if (section != null) 'section': section,
    'option': {for (final option in options) option.key: option.text},
    'answer': answerKey,
    if (solution != null) 'solution': solution,
    if (imageUrl != null) 'image': imageUrl,
    'examtype': examType,
    'examyear': examYear,
    if (university != null) 'university': university,
  };

  bool isCorrect(String? selectedKey) =>
      selectedKey != null && selectedKey.toLowerCase().trim() == answerKey;

  String? get correctText {
    for (final option in options) {
      if (option.key == answerKey) return option.text;
    }
    return null;
  }
}

enum PastPracticeMode { quick, standard, challenge, mock }

extension PastPracticeModeX on PastPracticeMode {
  String get title => switch (this) {
    PastPracticeMode.quick => 'Quick 10',
    PastPracticeMode.standard => 'Standard 20',
    PastPracticeMode.challenge => 'Challenge 40',
    PastPracticeMode.mock => 'Timed mock',
  };

  String get subtitle => switch (this) {
    PastPracticeMode.quick => 'Warm-up set',
    PastPracticeMode.standard => 'Exam rhythm',
    PastPracticeMode.challenge => 'Long paper stamina',
    PastPracticeMode.mock => '40 questions, 30 minutes, marked at the end',
  };

  int get limit => switch (this) {
    PastPracticeMode.quick => 10,
    PastPracticeMode.standard => 20,
    PastPracticeMode.challenge => 40,
    PastPracticeMode.mock => 40,
  };

  /// UTME pace: roughly 45 seconds a question.
  Duration? get timeLimit =>
      this == PastPracticeMode.mock ? Duration(seconds: limit * 45) : null;

  static PastPracticeMode forCount(int count) {
    if (count <= 10) return PastPracticeMode.quick;
    if (count <= 20) return PastPracticeMode.standard;
    return PastPracticeMode.challenge;
  }
}

class PastQuestionsSessionConfig {
  final PastExamType exam;
  final PastSubject subject;
  final int? year;
  final PastPracticeMode mode;
  final String? university;

  /// Saved misses to replay instead of fetching from Sdash.
  final List<PastQuestion>? preset;
  final String? assignmentId;
  final String? topicId;
  final String? topicTitle;

  const PastQuestionsSessionConfig({
    required this.exam,
    required this.subject,
    required this.mode,
    this.year,
    this.university,
    this.preset,
    this.assignmentId,
    this.topicId,
    this.topicTitle,
  });

  bool get isTopic => topicId != null;

  bool get isRetry => preset != null && !isTopic;

  bool get isMock => mode == PastPracticeMode.mock && !isRetry && !isTopic;

  String get wireMode => isRetry ? 'retry' : mode.name;

  String get headline => isTopic
      ? '${exam.shortLabel} · ${subject.name} · $topicTitle'
      : '${isRetry ? 'Mistakes · ' : ''}${exam.shortLabel} · ${subject.name}'
            '${year == null ? '' : ' · $year'}';
}

class PastQuestionsCatalog {
  final List<PastExamType> exams;
  final List<PastSubject> subjects;
  final List<int> years;

  const PastQuestionsCatalog({
    required this.exams,
    required this.subjects,
    required this.years,
  });
}

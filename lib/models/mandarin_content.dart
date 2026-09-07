enum CourseLessonStatus { shell, ready, inReview, approved }

enum ReviewStatus { pending, approved, corrected, rejected }

enum MandarinActivityType { listenTap, match, mcq, fillBlank }

bool isFoundationLessonUnlocked(
  MandarinCourseLesson lesson,
  Set<String> completedLessonIds,
  Iterable<MandarinCourseLesson> courseLessons,
) {
  if (lesson.sequence == 1) return true;
  final previous = courseLessons.where(
    (candidate) => candidate.sequence == lesson.sequence - 1,
  );
  return previous.isNotEmpty && completedLessonIds.contains(previous.first.id);
}

class ContentSourceRef {
  final String name;
  final String? url;
  final String licence;
  final String? datasetVersion;

  const ContentSourceRef({
    required this.name,
    this.url,
    required this.licence,
    this.datasetVersion,
  });
}

const kKidversityFirstPartySource = ContentSourceRef(
  name: 'Kidversity Foundation V1 first-party pack',
  licence: 'All rights reserved — original Kidversity content',
  datasetVersion: '1.0',
);

class MandarinVocabItem {
  final String id;
  final String simplified;
  final String pinyin;
  final String english;
  final String partOfSpeech;
  final ReviewStatus reviewStatus;
  final String? audioUrl;
  final ContentSourceRef source;

  const MandarinVocabItem({
    required this.id,
    required this.simplified,
    required this.pinyin,
    required this.english,
    this.partOfSpeech = '',
    this.reviewStatus = ReviewStatus.approved,
    this.audioUrl,
    this.source = kKidversityFirstPartySource,
  });
}

class MandarinExample {
  final String id;
  final String chinese;
  final String pinyin;
  final String english;
  final ContentSourceRef source;

  const MandarinExample({
    required this.id,
    required this.chinese,
    required this.pinyin,
    required this.english,
    this.source = kKidversityFirstPartySource,
  });
}

class MandarinGrammarPattern {
  final String id;
  final String pattern;
  final String explanation;
  final String chinese;
  final String pinyin;
  final String english;
  final ContentSourceRef source;

  const MandarinGrammarPattern({
    required this.id,
    required this.pattern,
    required this.explanation,
    required this.chinese,
    required this.pinyin,
    required this.english,
    this.source = kKidversityFirstPartySource,
  });
}

class MandarinDialogueLine {
  final String id;
  final String speaker;
  final String chinese;
  final String pinyin;
  final String english;
  final String? audioUrl;
  final ContentSourceRef source;

  const MandarinDialogueLine({
    required this.id,
    required this.speaker,
    required this.chinese,
    required this.pinyin,
    required this.english,
    this.audioUrl,
    this.source = kKidversityFirstPartySource,
  });
}

class MandarinActivity {
  final String id;
  final MandarinActivityType type;
  final String prompt;
  final String answer;
  final List<String> distractors;
  final String explanation;
  final String? audioUrl;
  final ContentSourceRef source;

  const MandarinActivity({
    required this.id,
    required this.type,
    required this.prompt,
    required this.answer,
    this.distractors = const [],
    this.explanation = '',
    this.audioUrl,
    this.source = kKidversityFirstPartySource,
  });

  List<String> get options => [answer, ...distractors];
}

class MandarinAssessmentItem {
  final String id;
  final String question;
  final MandarinActivityType type;
  final String correctAnswer;
  final List<String> distractors;
  final String explanation;
  final String? audioUrl;
  final ContentSourceRef source;

  const MandarinAssessmentItem({
    required this.id,
    required this.question,
    required this.type,
    required this.correctAnswer,
    this.distractors = const [],
    required this.explanation,
    this.audioUrl,
    this.source = kKidversityFirstPartySource,
  });

  List<String> get options => [correctAnswer, ...distractors];
}

class MandarinCourseLesson {
  final String id;
  final int sequence;
  final int moduleSequence;
  final String title;
  final String objective;
  final CourseLessonStatus status;
  final List<MandarinVocabItem> vocabulary;
  final List<MandarinExample> examples;
  final List<MandarinGrammarPattern> grammar;
  final List<MandarinDialogueLine> dialogue;
  final List<MandarinActivity> activities;
  final List<MandarinAssessmentItem> assessment;
  final String explanation;
  final int xpReward;

  const MandarinCourseLesson({
    required this.id,
    required this.sequence,
    required this.moduleSequence,
    required this.title,
    required this.objective,
    required this.status,
    this.vocabulary = const [],
    this.examples = const [],
    this.grammar = const [],
    this.dialogue = const [],
    this.activities = const [],
    this.assessment = const [],
    this.explanation = '',
    this.xpReward = 100,
  });

  bool get isPlayable => status == CourseLessonStatus.approved;
}

class MandarinModule {
  final int sequence;
  final String title;
  final String subtitle;
  final List<MandarinCourseLesson> lessons;

  const MandarinModule({
    required this.sequence,
    required this.title,
    required this.subtitle,
    required this.lessons,
  });
}

class MandarinCourse {
  final String id;
  final String title;
  final String level;
  final String targetAge;
  final List<MandarinModule> modules;

  const MandarinCourse({
    required this.id,
    required this.title,
    required this.level,
    required this.targetAge,
    required this.modules,
  });

  List<MandarinCourseLesson> get lessons =>
      modules.expand((module) => module.lessons).toList(growable: false);
}

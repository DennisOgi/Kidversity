import '../models/mandarin_content.dart';

class MandarinExperience {
  final MandarinCourseLesson source;
  final List<MandarinVocabItem> characterStages;
  final String explanation;
  final List<MandarinDialogueLine> dialogue;
  final List<MandarinActivity> practice;
  final List<MandarinAssessmentItem> quest;

  const MandarinExperience({
    required this.source,
    required this.characterStages,
    required this.explanation,
    required this.dialogue,
    required this.practice,
    required this.quest,
  });
}

/// Builds learner experiences only from an approved content pack.
///
/// It is deliberately deterministic: it cannot invent Chinese, alter Pinyin,
/// or bypass review. A later English-generation adapter can enrich explanation
/// copy, but that output must return to `in_review` before learners can see it.
class MandarinExperienceBuilder {
  const MandarinExperienceBuilder();

  MandarinExperience build(MandarinCourseLesson pack) {
    if (!pack.isPlayable) {
      throw StateError(
        'Only approved lessons can produce a learner experience.',
      );
    }
    final unapprovedWords = pack.vocabulary.where(
      (item) =>
          item.reviewStatus != ReviewStatus.approved &&
          item.reviewStatus != ReviewStatus.corrected,
    );
    if (unapprovedWords.isNotEmpty) {
      throw StateError(
        'The lesson contains vocabulary that has not passed review.',
      );
    }
    if (pack.vocabulary.isEmpty || pack.assessment.isEmpty) {
      throw StateError(
        'An approved lesson must include vocabulary and assessment items.',
      );
    }

    return MandarinExperience(
      source: pack,
      characterStages: List.unmodifiable(pack.vocabulary),
      explanation: pack.explanation,
      dialogue: List.unmodifiable(pack.dialogue),
      practice: List.unmodifiable(pack.activities),
      quest: List.unmodifiable(pack.assessment),
    );
  }
}

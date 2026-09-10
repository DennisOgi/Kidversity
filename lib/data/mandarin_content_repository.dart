import 'package:flutter/foundation.dart';

import '../models/mandarin_content.dart';
import '../services/supabase_service.dart';
import 'mandarin_foundation_data.dart';

abstract interface class MandarinContentRepository {
  Future<MandarinCourse> loadCourse();
}

class HybridMandarinContentRepository implements MandarinContentRepository {
  const HybridMandarinContentRepository();

  @override
  Future<MandarinCourse> loadCourse() async {
    final service = SupabaseService.instance;
    if (!service.isInitialized) {
      if (kDebugMode) {
        debugPrint(
          'MandarinContentRepository: Supabase unavailable; using approved local pack.',
        );
        return MandarinFoundationData.course;
      }
      throw StateError('Mandarin content is temporarily unavailable.');
    }

    try {
      final lessonRows = await service.client
          .from('course_lessons')
          .select()
          .eq('course_id', MandarinFoundationData.courseId)
          .eq('status', 'approved')
          .order('sequence');

      if ((lessonRows as List).isEmpty) {
        if (kDebugMode) {
          debugPrint(
            'MandarinContentRepository: remote course empty; using approved local pack.',
          );
          return MandarinFoundationData.course;
        }
        throw StateError('Mandarin content is temporarily unavailable.');
      }

      final remote = await _mapRemoteCourse(service, lessonRows);
      debugPrint(
        'MandarinContentRepository: loaded ${remote.lessons.length} remote lessons.',
      );
      return remote;
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'MandarinContentRepository: remote load failed ($error); using approved local pack.',
        );
        return MandarinFoundationData.course;
      }
      rethrow;
    }
  }

  Future<MandarinCourse> _mapRemoteCourse(
    SupabaseService service,
    List<dynamic> lessonRows,
  ) async {
    final lessonIds = lessonRows
        .map((row) => (row as Map)['id'] as String)
        .toList();
    final vocabRows = await service.client
        .from('vocab_items')
        .select(
          '*, content_sources(source_name, url, licence, dataset_version)',
        )
        .inFilter('lesson_id', lessonIds)
        .order('sequence');
    final exampleRows = await service.client
        .from('examples')
        .select(
          '*, content_sources(source_name, url, licence, dataset_version)',
        )
        .inFilter('lesson_id', lessonIds)
        .order('sequence');
    final grammarRows = await service.client
        .from('grammar_patterns')
        .select(
          '*, content_sources(source_name, url, licence, dataset_version)',
        )
        .inFilter('lesson_id', lessonIds);
    final dialogueRows = await service.client
        .from('dialogues')
        .select(
          '*, content_sources(source_name, url, licence, dataset_version)',
        )
        .inFilter('lesson_id', lessonIds)
        .order('sequence');
    final activityRows = await service.client
        .from('activities')
        .select(
          '*, content_sources(source_name, url, licence, dataset_version)',
        )
        .inFilter('lesson_id', lessonIds)
        .order('sequence');
    final assessmentRows = await service.client
        .from('assessment_items')
        .select(
          '*, content_sources(source_name, url, licence, dataset_version)',
        )
        .inFilter('lesson_id', lessonIds)
        .order('sequence');
    final audioRows = await service.client
        .from('audio_clips')
        .select('item_type, item_id, audio_url, storage_path')
        .inFilter('lesson_id', lessonIds);
    final audioUrls = <String, String?>{};
    for (final raw in audioRows as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      final key = '${row['item_type']}:${row['item_id']}';
      final storagePath = row['storage_path'] as String?;
      if (storagePath != null && storagePath.isNotEmpty) {
        audioUrls[key] = await service.client.storage
            .from('mandarin-audio')
            .createSignedUrl(storagePath, 3600);
      } else {
        audioUrls[key] = row['audio_url'] as String?;
      }
    }

    final lessons = lessonRows
        .map((raw) {
          final row = Map<String, dynamic>.from(raw as Map);
          final id = row['id'] as String;
          return MandarinCourseLesson(
            id: id,
            sequence: (row['sequence'] as num).toInt(),
            moduleSequence: (row['module_sequence'] as num).toInt(),
            title: row['title'] as String,
            objective: row['objective'] as String? ?? '',
            explanation: row['explanation'] as String? ?? '',
            status: _lessonStatus(row['status'] as String?),
            xpReward: (row['xp_reward'] as num?)?.toInt() ?? 100,
            vocabulary: (vocabRows as List)
                .where((item) => (item as Map)['lesson_id'] == id)
                .map(
                  (item) => _vocab(
                    Map<String, dynamic>.from(item as Map),
                    audioUrls['vocab:${item['id']}'],
                  ),
                )
                .toList(growable: false),
            examples: (exampleRows as List)
                .where((item) => (item as Map)['lesson_id'] == id)
                .map(
                  (item) => _example(
                    Map<String, dynamic>.from(item as Map),
                    audioUrls['example:${item['id']}'],
                  ),
                )
                .toList(growable: false),
            grammar: (grammarRows as List)
                .where((item) => (item as Map)['lesson_id'] == id)
                .map(
                  (item) => _grammar(
                    Map<String, dynamic>.from(item as Map),
                    audioUrls['grammar:${item['id']}'],
                  ),
                )
                .toList(growable: false),
            dialogue: (dialogueRows as List)
                .where((item) => (item as Map)['lesson_id'] == id)
                .map(
                  (item) => _dialogue(
                    Map<String, dynamic>.from(item as Map),
                    audioUrls['dialogue:${item['id']}'],
                  ),
                )
                .toList(growable: false),
            activities: (activityRows as List)
                .where((item) => (item as Map)['lesson_id'] == id)
                .map(
                  (item) => _activity(
                    Map<String, dynamic>.from(item as Map),
                    audioUrls['activity:${item['id']}'],
                  ),
                )
                .toList(growable: false),
            assessment: (assessmentRows as List)
                .where((item) => (item as Map)['lesson_id'] == id)
                .map(
                  (item) => _assessment(
                    Map<String, dynamic>.from(item as Map),
                    audioUrls['assessment:${item['id']}'],
                  ),
                )
                .toList(growable: false),
          );
        })
        .toList(growable: false);

    List<MandarinCourseLesson> moduleLessons(int module) => lessons
        .where((lesson) => lesson.moduleSequence == module)
        .toList(growable: false);

    return MandarinCourse(
      id: MandarinFoundationData.courseId,
      title: 'Mandarin Foundation',
      level: 'Complete beginner',
      targetAge: '7–12',
      modules: [
        MandarinModule(
          sequence: 1,
          title: 'First Contact',
          subtitle: 'Hear Mandarin, understand tones, and say hello.',
          lessons: moduleLessons(1),
        ),
        MandarinModule(
          sequence: 2,
          title: 'My World',
          subtitle: 'Talk about yourself and the world around you.',
          lessons: moduleLessons(2),
        ),
        MandarinModule(
          sequence: 3,
          title: 'Everyday Mandarin',
          subtitle: 'Use Mandarin in everyday situations.',
          lessons: moduleLessons(3),
        ),
      ],
    );
  }

  MandarinVocabItem _vocab(Map<String, dynamic> row, String? audioUrl) =>
      MandarinVocabItem(
        id: row['id'] as String,
        simplified: row['simplified_chinese'] as String,
        pinyin: row['pinyin'] as String,
        english: row['english_meaning'] as String,
        partOfSpeech: row['part_of_speech'] as String? ?? '',
        reviewStatus: _reviewStatus(row['review_status'] as String?),
        audioUrl: audioUrl,
        source: _source(row),
      );

  MandarinExample _example(Map<String, dynamic> row, String? audioUrl) =>
      MandarinExample(
        id: row['id'] as String,
        chinese: row['chinese'] as String,
        pinyin: row['pinyin'] as String,
        english: row['english'] as String,
        audioUrl: audioUrl,
        source: _source(row),
      );

  MandarinGrammarPattern _grammar(Map<String, dynamic> row, String? audioUrl) =>
      MandarinGrammarPattern(
        id: row['id'] as String,
        pattern: row['pattern'] as String,
        explanation: row['explanation'] as String,
        chinese: row['chinese'] as String,
        pinyin: row['pinyin'] as String,
        english: row['english'] as String,
        audioUrl: audioUrl,
        source: _source(row),
      );

  MandarinDialogueLine _dialogue(Map<String, dynamic> row, String? audioUrl) =>
      MandarinDialogueLine(
        id: row['id'] as String,
        speaker: row['speaker'] as String? ?? 'Speaker',
        chinese: row['chinese'] as String,
        pinyin: row['pinyin'] as String,
        english: row['english'] as String,
        audioUrl: audioUrl,
        source: _source(row),
      );

  MandarinActivity _activity(Map<String, dynamic> row, String? audioUrl) =>
      MandarinActivity(
        id: row['id'] as String,
        type: _activityType(row['type'] as String?),
        prompt: row['prompt'] as String,
        answer: row['answer'] as String,
        distractors: List<String>.from(row['distractors'] as List? ?? const []),
        explanation: row['explanation'] as String? ?? '',
        audioUrl: audioUrl,
        source: _source(row),
      );

  MandarinAssessmentItem _assessment(
    Map<String, dynamic> row,
    String? audioUrl,
  ) => MandarinAssessmentItem(
    id: row['id'] as String,
    question: row['question'] as String,
    type: _activityType(row['type'] as String?),
    correctAnswer: row['correct_answer'] as String,
    distractors: List<String>.from(row['distractors'] as List? ?? const []),
    explanation: row['explanation'] as String? ?? '',
    audioUrl: audioUrl,
    source: _source(row),
  );

  ContentSourceRef _source(Map<String, dynamic> row) {
    final raw = row['content_sources'];
    if (raw is! Map) return kKidversityFirstPartySource;
    return ContentSourceRef(
      name: raw['source_name'] as String? ?? 'Unknown source',
      url: raw['url'] as String?,
      licence: raw['licence'] as String? ?? 'Unverified',
      datasetVersion: raw['dataset_version'] as String?,
    );
  }

  CourseLessonStatus _lessonStatus(String? value) => switch (value) {
    'ready' => CourseLessonStatus.ready,
    'in_review' => CourseLessonStatus.inReview,
    'approved' => CourseLessonStatus.approved,
    _ => CourseLessonStatus.shell,
  };

  ReviewStatus _reviewStatus(String? value) => switch (value) {
    'approved' => ReviewStatus.approved,
    'corrected' => ReviewStatus.corrected,
    'rejected' => ReviewStatus.rejected,
    _ => ReviewStatus.pending,
  };

  MandarinActivityType _activityType(String? value) => switch (value) {
    'listen_tap' => MandarinActivityType.listenTap,
    'match' => MandarinActivityType.match,
    'fill_blank' => MandarinActivityType.fillBlank,
    _ => MandarinActivityType.mcq,
  };
}

import '../core/error_handler.dart' as app_errors;
import 'supabase_service.dart';

class FoundationReviewItem {
  final String type;
  final String id;
  final String lessonId;
  final String chinese;
  final String pinyin;
  final String english;
  final String prompt;
  final String? audioUrl;
  final bool audioGenerated;

  const FoundationReviewItem({
    required this.type,
    required this.id,
    required this.lessonId,
    this.chinese = '',
    this.pinyin = '',
    this.english = '',
    this.prompt = '',
    this.audioUrl,
    this.audioGenerated = false,
  });
}

class FoundationReviewService {
  static const instance = FoundationReviewService._();
  const FoundationReviewService._();

  Future<app_errors.Result<List<FoundationReviewItem>>> fetchQueue() async {
    final service = SupabaseService.instance;
    if (!service.isInitialized) {
      return app_errors.Result.success(const []);
    }
    try {
      final lessons = await service.client
          .from('course_lessons')
          .select()
          .inFilter('status', ['ready', 'in_review'])
          .eq('metadata_review_status', 'pending')
          .order('sequence');
      final vocab = await _pending(service, 'vocab_items');
      final examples = await _pending(service, 'examples');
      final grammar = await _pending(service, 'grammar_patterns');
      final dialogues = await _pending(service, 'dialogues');
      final activities = await _pending(service, 'activities');
      final assessments = await _pending(service, 'assessment_items');
      final audio = await _pending(service, 'audio_clips');

      final queue = <FoundationReviewItem>[
        for (final raw in lessons as List)
          FoundationReviewItem(
            type: 'lesson',
            id: (raw as Map)['id'] as String,
            lessonId: raw['id'] as String,
            prompt: raw['objective'] as String? ?? '',
            chinese: raw['title'] as String? ?? '',
            english: raw['explanation'] as String? ?? '',
          ),
        for (final raw in vocab)
          FoundationReviewItem(
            type: 'vocab',
            id: raw['id'] as String,
            lessonId: raw['lesson_id'] as String,
            chinese: raw['simplified_chinese'] as String? ?? '',
            pinyin: raw['pinyin'] as String? ?? '',
            english: raw['english_meaning'] as String? ?? '',
          ),
        for (final raw in examples)
          FoundationReviewItem(
            type: 'example',
            id: raw['id'] as String,
            lessonId: raw['lesson_id'] as String,
            chinese: raw['chinese'] as String? ?? '',
            pinyin: raw['pinyin'] as String? ?? '',
            english: raw['english'] as String? ?? '',
          ),
        for (final raw in grammar)
          FoundationReviewItem(
            type: 'grammar',
            id: raw['id'] as String,
            lessonId: raw['lesson_id'] as String,
            prompt: raw['pattern'] as String? ?? '',
            chinese: raw['chinese'] as String? ?? '',
            pinyin: raw['pinyin'] as String? ?? '',
            english: [
              raw['english'] as String? ?? '',
              raw['explanation'] as String? ?? '',
            ].where((value) => value.isNotEmpty).join(' · '),
          ),
        for (final raw in dialogues)
          FoundationReviewItem(
            type: 'dialogue',
            id: raw['id'] as String,
            lessonId: raw['lesson_id'] as String,
            prompt: raw['speaker'] as String? ?? '',
            chinese: raw['chinese'] as String? ?? '',
            pinyin: raw['pinyin'] as String? ?? '',
            english: raw['english'] as String? ?? '',
          ),
        for (final raw in activities)
          FoundationReviewItem(
            type: 'activity',
            id: raw['id'] as String,
            lessonId: raw['lesson_id'] as String,
            prompt: raw['prompt'] as String? ?? '',
            chinese: raw['answer'] as String? ?? '',
            english: raw['explanation'] as String? ?? '',
          ),
        for (final raw in assessments)
          FoundationReviewItem(
            type: 'assessment',
            id: raw['id'] as String,
            lessonId: raw['lesson_id'] as String,
            prompt: raw['question'] as String? ?? '',
            chinese: raw['correct_answer'] as String? ?? '',
            english: raw['explanation'] as String? ?? '',
          ),
        for (final raw in audio) await _audioItem(service, raw),
      ];
      queue.sort((a, b) {
        final lesson = a.lessonId.compareTo(b.lessonId);
        return lesson != 0 ? lesson : a.type.compareTo(b.type);
      });
      return app_errors.Result.success(queue);
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'Fetch Foundation review queue',
      );
      return app_errors.Result.failure('Could not load the review queue.');
    }
  }

  Future<List<Map<String, dynamic>>> _pending(
    SupabaseService service,
    String table,
  ) async {
    final rows = await service.client
        .from(table)
        .select()
        .eq('review_status', 'pending')
        .order('lesson_id')
        .limit(500);
    return [
      for (final row in rows as List) Map<String, dynamic>.from(row as Map),
    ];
  }

  Future<FoundationReviewItem> _audioItem(
    SupabaseService service,
    Map<String, dynamic> row,
  ) async {
    final path = row['storage_path'] as String?;
    final url = path == null || path.isEmpty
        ? null
        : await service.client.storage
              .from('mandarin-audio')
              .createSignedUrl(path, 1800);
    return FoundationReviewItem(
      type: 'audio',
      id: row['id'] as String,
      lessonId: row['lesson_id'] as String,
      prompt: '${row['item_type']} · ${row['voice'] ?? 'Not generated'}',
      chinese: row['audio_text'] as String? ?? '',
      english: row['provider'] as String? ?? 'Awaiting Google audio',
      audioUrl: url,
      audioGenerated: url != null,
    );
  }

  Future<app_errors.Result<void>> review({
    required FoundationReviewItem item,
    required String verdict,
    String notes = '',
    Map<String, dynamic> corrections = const {},
  }) => _invokeReview({
    'action': 'review',
    'itemType': item.type,
    'itemId': item.id,
    'verdict': verdict,
    'notes': notes,
    'corrections': corrections,
  });

  Future<app_errors.Result<void>> submitLesson(String lessonId) =>
      _invokeReview({'action': 'submit', 'lessonId': lessonId});

  Future<app_errors.Result<void>> publishLesson(String lessonId) =>
      _invokeReview({'action': 'publish', 'lessonId': lessonId});

  Future<app_errors.Result<void>> _invokeReview(
    Map<String, dynamic> body,
  ) async {
    final service = SupabaseService.instance;
    if (!service.isInitialized) {
      return app_errors.Result.failure('Reviews are temporarily unavailable.');
    }
    try {
      app_errors.ErrorHandler.addBreadcrumb(
        'Submitting Foundation review action',
        category: 'foundation.review',
        data: {
          'action': body['action'],
          'lesson_id': body['lessonId'],
          'item_type': body['itemType'],
        },
      );
      final response = await service.client.functions.invoke(
        'foundation-review',
        body: body,
      );
      final data = response.data;
      if (response.status >= 400 || data is Map && data['error'] != null) {
        return app_errors.Result.failure('Could not save this review.');
      }
      return app_errors.Result.success(null);
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'Review Foundation item',
      );
      return app_errors.Result.failure('Could not save this review.');
    }
  }

  Future<app_errors.Result<void>> generateAudio(String clipId) async {
    final service = SupabaseService.instance;
    if (!service.isInitialized) {
      return app_errors.Result.failure('Audio generation is unavailable.');
    }
    try {
      app_errors.ErrorHandler.addBreadcrumb(
        'Generating Mandarin audio',
        category: 'foundation.audio',
        data: {'clip_id': clipId},
      );
      final response = await service.client.functions.invoke(
        'generate-mandarin-tts',
        body: {'clipId': clipId},
      );
      final data = response.data;
      if (response.status >= 400 || data is Map && data['error'] != null) {
        return app_errors.Result.failure('Could not generate this audio.');
      }
      return app_errors.Result.success(null);
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'Generate Mandarin audio',
      );
      return app_errors.Result.failure('Could not generate this audio.');
    }
  }
}

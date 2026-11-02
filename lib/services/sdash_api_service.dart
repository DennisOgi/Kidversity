import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/error_handler.dart' as app_errors;
import '../models/past_questions_models.dart';
import 'exam_bank_service.dart';

/// Nigerian past questions, served from Kidversity's own exam bank.
///
/// The SdashAPI token lives only on the server (the `exam-bank` Edge
/// Function). The app reads the bank and, when a paper is missing, asks the
/// server to fetch that one paper. No third-party key ships in the app.
class SdashApiService {
  SdashApiService._();
  static final instance = SdashApiService._();

  static const _catalogCacheKey = 'sdash_catalog_v3';
  static const _catalogCachedAtKey = 'sdash_catalog_cached_at_v3';
  static const _cacheTtl = Duration(hours: 24);

  Future<app_errors.Result<PastQuestionsCatalog>> fetchCatalog({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await _readCachedCatalog();
      if (cached != null) return app_errors.Result.success(cached);
    }
    final bank = await ExamBankService.instance.readCatalog();
    if (bank != null && bank.exams.isNotEmpty) {
      unawaited(_writeCachedCatalog(bank));
      return app_errors.Result.success(bank);
    }
    return app_errors.Result.success(ExamBankService.fallbackCatalog);
  }

  Future<app_errors.Result<List<PastQuestion>>> fetchQuestions({
    required String examSlug,
    required String subjectSlug,
    required int limit,
    int? year,
    String? university,
  }) async {
    final wanted = limit.clamp(1, 50);
    final pinnedYear =
        year ??
        await ExamBankService.instance.pickYear(
          examSlug: examSlug,
          subjectSlug: subjectSlug,
          university: university,
        ) ??
        (ExamBankService.fallbackCatalog.years.isEmpty
            ? null
            : ExamBankService.fallbackCatalog.years.first);
    if (pinnedYear == null) {
      return app_errors.Result.failure(
        'Pick a year so this session stays on one paper.',
      );
    }

    Future<List<PastQuestion>> draw() async => _keepPaper(
      await ExamBankService.instance.draw(
        examSlug: examSlug,
        subjectSlug: subjectSlug,
        limit: wanted,
        year: pinnedYear,
        university: university,
      ),
      year: pinnedYear,
    );

    final cached = await draw();
    if (cached.length >= wanted) return app_errors.Result.success(cached);

    // Ask the server to fetch this paper once; it is cached for everyone.
    final added = await ExamBankService.instance.fillPaper(
      examSlug: examSlug,
      subjectSlug: subjectSlug,
      year: pinnedYear,
    );
    final refreshed = added > 0 ? await draw() : cached;
    if (refreshed.isNotEmpty) return app_errors.Result.success(refreshed);
    return app_errors.Result.failure(
      'No $pinnedYear questions are in the bank for that exam and subject yet. '
      'Try another year.',
    );
  }

  /// Flags a question for the content team. Stored with the learner's
  /// attempt notes until a review queue for past questions exists.
  Future<app_errors.Result<void>> reportQuestion({
    required int questionId,
    String reportType = 'wrong_answer',
    String? message,
  }) async {
    await app_errors.ErrorHandler.reportError(
      StateError('Past question reported: $questionId ($reportType)'),
      StackTrace.current,
      context: 'past_question.report ${message ?? ''}'.trim(),
    );
    return app_errors.Result.success(null);
  }

  List<PastQuestion> _keepPaper(
    List<PastQuestion> questions, {
    required int year,
  }) {
    final wanted = year.toString();
    return [
      for (final question in questions)
        if (question.examYear == wanted) question,
    ];
  }

  Future<PastQuestionsCatalog?> _readCachedCatalog() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedAtRaw = prefs.getString(_catalogCachedAtKey);
    final payload = prefs.getString(_catalogCacheKey);
    if (cachedAtRaw == null || payload == null) return null;
    final cachedAt = DateTime.tryParse(cachedAtRaw);
    if (cachedAt == null || DateTime.now().difference(cachedAt) > _cacheTtl) {
      return null;
    }
    final json = jsonDecode(payload);
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);
    return PastQuestionsCatalog(
      exams: [
        for (final item in map['exams'] as List? ?? const [])
          PastExamType.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
      subjects: [
        for (final item in map['subjects'] as List? ?? const [])
          PastSubject.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
      years: [
        for (final item in map['years'] as List? ?? const [])
          (item as num).toInt(),
      ],
    );
  }

  Future<void> _writeCachedCatalog(PastQuestionsCatalog catalog) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _catalogCacheKey,
      jsonEncode({
        'exams': [
          for (final exam in catalog.exams)
            {'id': exam.id, 'name': exam.name, 'slug': exam.slug},
        ],
        'subjects': [
          for (final subject in catalog.subjects)
            {'id': subject.id, 'name': subject.name, 'slug': subject.slug},
        ],
        'years': catalog.years,
      }),
    );
    await prefs.setString(
      _catalogCachedAtKey,
      DateTime.now().toIso8601String(),
    );
  }
}

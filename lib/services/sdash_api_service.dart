import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/env.dart';
import '../core/error_handler.dart' as app_errors;
import '../models/past_questions_models.dart';

class SdashApiService {
  SdashApiService._();
  static final instance = SdashApiService._();

  static const _catalogCacheKey = 'sdash_catalog_v1';
  static const _catalogCachedAtKey = 'sdash_catalog_cached_at_v1';
  static const _cacheTtl = Duration(hours: 24);

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = Env.sdashApiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Map<String, String> get _headers => {
    'AccessToken': Env.sdashAccessToken.trim(),
    'Accept': 'application/json',
  };

  Future<app_errors.Result<PastQuestionsCatalog>> fetchCatalog({
    bool forceRefresh = false,
  }) async {
    if (!Env.hasSdashApi) {
      return app_errors.Result.failure(
        'Past questions are not configured yet. Add SDASH_ACCESS_TOKEN to .env.',
      );
    }

    try {
      if (!forceRefresh) {
        final cached = await _readCachedCatalog();
        if (cached != null) return app_errors.Result.success(cached);
      }

      final examsFuture = _getList('/v1/exams');
      final subjectsFuture = _getList('/v1/subjects');
      final yearsFuture = _getList('/v1/years');
      final examsRaw = await examsFuture;
      final subjectsRaw = await subjectsFuture;
      final yearsRaw = await yearsFuture;

      final catalog = PastQuestionsCatalog(
        exams: [
          for (final item in examsRaw)
            if (item is Map)
              PastExamType.fromJson(Map<String, dynamic>.from(item)),
        ]..sort((a, b) => a.name.compareTo(b.name)),
        subjects: [
          for (final item in subjectsRaw)
            if (item is Map)
              PastSubject.fromJson(Map<String, dynamic>.from(item)),
        ]..sort((a, b) => a.name.compareTo(b.name)),
        years: [
          for (final item in yearsRaw)
            if (item is num)
              item.toInt()
            else
              int.tryParse(item.toString()) ?? 0,
        ].where((year) => year > 0).toList(),
      );

      await _writeCachedCatalog(catalog);
      return app_errors.Result.success(catalog);
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'sdash.fetchCatalog',
      );
      return app_errors.Result.failure(_friendlyError(error));
    }
  }

  Future<app_errors.Result<List<PastQuestion>>> fetchQuestions({
    required String examSlug,
    required String subjectSlug,
    required int limit,
    int? year,
    String? university,
  }) async {
    if (!Env.hasSdashApi) {
      return app_errors.Result.failure(
        'Past questions are not configured yet. Add SDASH_ACCESS_TOKEN to .env.',
      );
    }

    try {
      final query = <String, String>{
        'type': examSlug,
        'subject': subjectSlug,
        'limit': limit.clamp(1, 50).toString(),
      };
      if (year != null) query['year'] = year.toString();
      if (university != null && university.trim().isNotEmpty) {
        query['university'] = university.trim().toLowerCase();
      }

      final payload = await _getJson('/v1/q', query);
      final data = payload['data'];
      final questions = <PastQuestion>[];
      if (data is List) {
        for (final item in data) {
          if (item is Map) {
            questions.add(
              PastQuestion.fromJson(Map<String, dynamic>.from(item)),
            );
          }
        }
      } else if (data is Map) {
        questions.add(PastQuestion.fromJson(Map<String, dynamic>.from(data)));
      }

      if (questions.isEmpty) {
        return app_errors.Result.failure(
          'No questions matched that exam, subject, and year. Try another year.',
        );
      }
      return app_errors.Result.success(questions);
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'sdash.fetchQuestions',
      );
      return app_errors.Result.failure(_friendlyError(error));
    }
  }

  Future<app_errors.Result<void>> reportQuestion({
    required int questionId,
    String reportType = 'wrong_answer',
    String? message,
  }) async {
    if (!Env.hasSdashApi) {
      return app_errors.Result.failure('Past questions are not configured.');
    }
    try {
      final response = await http
          .post(
            _uri('/v1/report'),
            headers: {..._headers, 'Content-Type': 'application/json'},
            body: jsonEncode({
              'question_id': questionId,
              'report_type': reportType,
              if (message != null && message.trim().isNotEmpty)
                'message': message.trim(),
            }),
          )
          .timeout(Duration(seconds: Env.apiTimeoutSeconds));
      final body = _decode(response.body);
      if (response.statusCode >= 400 || (body['status'] is num && (body['status'] as num) >= 400)) {
        throw StateError(body['message']?.toString() ?? 'Report failed');
      }
      return app_errors.Result.success(null);
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'sdash.reportQuestion',
      );
      return app_errors.Result.failure(_friendlyError(error));
    }
  }

  Future<List<dynamic>> _getList(String path) async {
    final payload = await _getJson(path);
    final data = payload['data'];
    if (data is List) return data;
    return const [];
  }

  Future<Map<String, dynamic>> _getJson(
    String path, [
    Map<String, String>? query,
  ]) async {
    final response = await http
        .get(_uri(path, query), headers: _headers)
        .timeout(Duration(seconds: Env.apiTimeoutSeconds));
    final body = _decode(response.body);
    final status = body['status'];
    if (response.statusCode == 401 || status == 401) {
      throw StateError('Invalid past-questions API token.');
    }
    if (response.statusCode == 403 || status == 403) {
      final message = body['message']?.toString().trim();
      throw StateError(
        (message != null && message.isNotEmpty)
            ? message
            : 'Past-questions access denied for this plan.',
      );
    }
    if (response.statusCode == 429 || status == 429) {
      throw StateError('Past-questions quota reached for this month.');
    }
    if (response.statusCode == 404 || status == 404) {
      throw StateError('No questions matched those filters.');
    }
    if (response.statusCode >= 400 || (status is num && status >= 400)) {
      throw StateError(body['message']?.toString() ?? 'Request failed');
    }
    return body;
  }

  Map<String, dynamic> _decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw StateError('Unexpected API response');
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

  String _friendlyError(Object error) {
    final text = error.toString().replaceFirst('Bad state: ', '').trim();
    final lower = text.toLowerCase();
    if (lower.contains('sandbox') || lower.contains('paid plan')) {
      return text;
    }
    if (lower.contains('not written in the')) {
      return text;
    }
    if (lower.contains('quota')) {
      return 'Past-questions quota reached for this month.';
    }
    if (lower.contains('token') || lower.contains('401')) {
      return 'Past-questions API token is missing or invalid.';
    }
    if (lower.contains('no questions matched')) {
      return 'No questions matched those filters. Try another year or subject.';
    }
    if (lower.contains('socketexception') ||
        lower.contains('timeoutexception')) {
      return 'Could not reach the past-questions service. Check your connection.';
    }
    if (text.isNotEmpty && text != 'Instance of \'StateError\'') {
      return text;
    }
    return 'Could not load past questions right now.';
  }
}

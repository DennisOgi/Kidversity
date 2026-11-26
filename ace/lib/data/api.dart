import 'package:supabase_flutter/supabase_flutter.dart';

/// Every ACE read and write goes through checked server functions. The app
/// never reads answer keys: a question's answer and worked solution only
/// arrive in the response to a submitted practice attempt.
class AceApi {
  AceApi();

  /// Swappable for previews and tests.
  static AceApi instance = AceApi();

  SupabaseClient get _db => Supabase.instance.client;

  Future<Map<String, dynamic>> _rpc(
    String fn, [
    Map<String, dynamic>? params,
  ]) async {
    final raw = await _db.rpc(fn, params: params);
    return Map<String, dynamic>.from(raw as Map);
  }

  Future<Map<String, dynamic>> me() => _rpc('ace_me');

  Future<Map<String, dynamic>> joinSchool(String code) =>
      _rpc('ace_join_school', {'p_code': code});

  Future<Map<String, dynamic>> channel(String id) =>
      _rpc('ace_channel', {'p_channel': id});

  Future<Map<String, dynamic>> lesson(String id) =>
      _rpc('ace_lesson', {'p_lesson': id});

  Future<Map<String, dynamic>> progress(String channelId) =>
      _rpc('ace_progress', {'p_channel': channelId});

  Future<Map<String, dynamic>> submit({
    required String questionId,
    num? finalAnswer,
    String? unit,
    String? working,
    String? option,
  }) => _rpc('ace_submit_attempt', {
    'p_question': questionId,
    'p_mode': 'practice',
    'p_response': {
      'final_answer': ?finalAnswer,
      if (unit != null && unit.trim().isNotEmpty) 'unit': unit.trim(),
      if (working != null && working.trim().isNotEmpty)
        'working_text': working.trim(),
      'option': ?option,
    },
  });

  /// Plain words for server error codes.
  static String message(Object error) {
    final text = '$error';
    if (text.contains('INVALID_CODE')) {
      return 'That school code was not recognised. Check it with your teacher.';
    }
    if (text.contains('NOT_FOUND') || text.contains('NOT_AUTHORIZED')) {
      return 'This is not available to your school.';
    }
    if (text.contains('NOT_AUTHENTICATED')) return 'Please sign in again.';
    if (text.contains('INVALID_RESPONSE')) return 'That answer is too long.';
    return 'Something went wrong. Check your connection and try again.';
  }
}

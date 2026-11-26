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

  /// Teacher marks and comments on the learner's work in one lesson,
  /// keyed by question id.
  Future<Map<String, dynamic>> myReviews(String lessonId) =>
      _rpc('ace_my_reviews', {'p_lesson': lessonId});

  // Staff ------------------------------------------------------------------

  Future<Map<String, dynamic>> staffOverview() => _rpc('ace_staff_overview');

  Future<List<Map<String, dynamic>>> _list(
    String fn, [
    Map<String, dynamic>? params,
  ]) async {
    final raw = await _db.rpc(fn, params: params);
    return [
      for (final r in (raw as List? ?? const []))
        Map<String, dynamic>.from(r as Map),
    ];
  }

  Future<List<Map<String, dynamic>>> reviewQueue({
    String state = 'needs_review',
    String? channel,
  }) => _list('ace_review_queue', {'p_state': state, 'p_channel': channel});

  Future<Map<String, dynamic>> attemptDetail(String attemptId) =>
      _rpc('ace_attempt_detail', {'p_attempt': attemptId});

  Future<Map<String, dynamic>> markAttempt({
    required String attemptId,
    required num marks,
    List<Map<String, dynamic>> criteria = const [],
    String? comment,
  }) => _rpc('ace_mark_attempt', {
    'p_attempt': attemptId,
    'p_marks': marks,
    'p_criteria': criteria,
    'p_comment': comment,
  });

  Future<Map<String, dynamic>> classProgress(String channelId) =>
      _rpc('ace_class_progress', {'p_channel': channelId});

  Future<Map<String, dynamic>> studentDetail(String userId) =>
      _rpc('ace_student_detail', {'p_student': userId});

  Future<List<Map<String, dynamic>>> schoolPeople() =>
      _list('ace_school_people');

  Future<void> setMemberRole(String userId, String role) => _db.rpc(
    'ace_set_member_role',
    params: {'p_user': userId, 'p_role': role},
  );

  Future<void> removeMember(String userId) =>
      _db.rpc('ace_remove_member', params: {'p_user': userId});

  Future<String> newJoinCode() async =>
      (await _db.rpc('ace_new_join_code')) as String;

  /// Plain words for server error codes.
  static String message(Object error) {
    final text = '$error';
    if (text.contains('NOT_STAFF')) return 'This area is for teachers.';
    if (text.contains('NOT_ADMIN')) {
      return 'Only a school admin can do that.';
    }
    if (text.contains('INVALID_MARKS')) {
      return 'Marks must be between 0 and the question total.';
    }
    if (text.contains('CANNOT_CHANGE_SELF')) {
      return 'You cannot change your own role or remove yourself.';
    }
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

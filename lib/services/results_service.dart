import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_state.dart';
import '../models/results_models.dart';
import 'supabase_service.dart';

/// Official school results and targets. Every call goes through a
/// server function that checks who may see or change the pupil.
class ResultsService {
  ResultsService._();
  static final instance = ResultsService._();

  SupabaseClient get _db => SupabaseService.instance.client;

  Future<PupilProfile> profile(String studentId) async {
    final raw = await _db.rpc(
      'pupil_profile',
      params: {'p_student': studentId},
    );
    if (raw == null) throw StateError('This pupil could not be found.');
    return PupilProfile.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<ClassResults> classResults(String classId) async {
    final raw = await _db.rpc('class_results', params: {'p_class_id': classId});
    return ClassResults.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<String> addSubject(String name) async {
    final id = await _db.rpc('add_school_subject', params: {'p_name': name});
    return id as String;
  }

  Future<void> setTarget(String studentId, String subjectId, double? target) =>
      _db.rpc(
        'set_pupil_target',
        params: {
          'p_student': studentId,
          'p_subject': subjectId,
          'p_target': target,
        },
      );

  Future<void> recordResult({
    required String studentId,
    required String subjectId,
    required ResultKind kind,
    required double score,
    String title = '',
    DateTime? assessedOn,
  }) => _db.rpc(
    'record_pupil_result',
    params: {
      'p_student': studentId,
      'p_subject': subjectId,
      'p_kind': kind.name,
      'p_score': score,
      'p_title': title,
      'p_assessed_on': assessedOn?.toIso8601String().substring(0, 10),
    },
  );

  Future<void> deleteResult(String resultId) =>
      _db.rpc('delete_pupil_result', params: {'p_result': resultId});

  /// Plain words for server error codes.
  static String message(Object error) {
    final text = '$error';
    if (text.contains('NOT_AUTHORIZED')) {
      return 'Only this pupil\'s teacher or school admin can change results.';
    }
    if (text.contains('INVALID_SCORE')) return 'Scores are from 0 to 100.';
    if (text.contains('INVALID_NAME')) {
      return 'Subject names are 2 to 60 characters.';
    }
    if (text.contains('NEEDS_SCHOOL')) {
      return 'Join your school first to add subjects.';
    }
    if (text.contains('INVALID_SUBJECT')) {
      return 'That subject is not in this pupil\'s school.';
    }
    return 'That did not save. Check your connection and try again.';
  }
}

final pupilProfileProvider = FutureProvider.autoDispose
    .family<PupilProfile, String>((ref, studentId) {
      ref.watch(authControllerProvider.select((a) => a.isAuthenticated));
      return ResultsService.instance.profile(studentId);
    });

final classResultsProvider = FutureProvider.autoDispose
    .family<ClassResults, String>((ref, classId) {
      ref.watch(authControllerProvider.select((a) => a.isAuthenticated));
      return ResultsService.instance.classResults(classId);
    });

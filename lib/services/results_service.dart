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

  // Support actions ---------------------------------------------------------

  Future<List<SupportAction>> supportActions(String studentId) async {
    final raw = await _db.rpc(
      'support_actions',
      params: {'p_student': studentId},
    );
    return [
      for (final r in (raw as List? ?? const []))
        SupportAction.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }

  Future<void> saveSupportAction({
    required String studentId,
    required String action,
    String? id,
    String? subjectId,
    String? owner,
    DateTime? dueOn,
    bool shared = true,
  }) => _db.rpc(
    'save_support_action',
    params: {
      'p_student': studentId,
      'p_action': action,
      'p_id': id,
      'p_subject': subjectId,
      'p_owner': owner,
      'p_due': dueOn?.toIso8601String().substring(0, 10),
      'p_shared': shared,
    },
  );

  Future<void> setSupportStatus(String id, String status, {String? outcome}) =>
      _db.rpc(
        'set_support_status',
        params: {'p_id': id, 'p_status': status, 'p_outcome': outcome},
      );

  // Bulk upload ---------------------------------------------------------------

  /// Saves an uploaded sheet in one go. Rows: student_id, subject_id, score.
  Future<({String batchId, int saved})> importClassScores({
    required String classId,
    required ResultKind kind,
    required List<Map<String, Object>> rows,
    String title = '',
    DateTime? assessedOn,
    String? fileName,
  }) async {
    final raw = await _db.rpc(
      'import_class_scores',
      params: {
        'p_class_id': classId,
        'p_kind': kind.name,
        'p_rows': rows,
        'p_title': title,
        'p_assessed_on': assessedOn?.toIso8601String().substring(0, 10),
        'p_file_name': fileName,
      },
    );
    final m = Map<String, dynamic>.from(raw as Map);
    return (
      batchId: m['batch_id'] as String,
      saved: (m['saved'] as num).toInt(),
    );
  }

  Future<List<ScoreBatch>> scoreBatches(String classId) async {
    final raw = await _db.rpc('score_batches', params: {'p_class_id': classId});
    return [
      for (final r in (raw as List? ?? const []))
        ScoreBatch.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }

  Future<int> undoScoreBatch(String batchId) async =>
      ((await _db.rpc('undo_score_batch', params: {'p_batch': batchId})) as num)
          .toInt();

  /// Plain words for server error codes.
  static String message(Object error) {
    final text = '$error';
    if (text.contains('INVALID_ROWS')) {
      return 'Some rows are not valid. Fix the highlighted rows and try again.';
    }
    if (text.contains('NO_ROWS')) return 'There are no scores to save.';
    if (text.contains('TOO_MANY_ROWS')) {
      return 'That file is too large. Upload up to 5,000 scores at a time.';
    }
    if (text.contains('INVALID_ACTION')) {
      return 'Describe the support action in a few words.';
    }
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

final supportActionsProvider = FutureProvider.autoDispose
    .family<List<SupportAction>, String>((ref, studentId) {
      ref.watch(authControllerProvider.select((a) => a.isAuthenticated));
      return ResultsService.instance.supportActions(studentId);
    });

final scoreBatchesProvider = FutureProvider.autoDispose
    .family<List<ScoreBatch>, String>((ref, classId) {
      ref.watch(authControllerProvider.select((a) => a.isAuthenticated));
      return ResultsService.instance.scoreBatches(classId);
    });

final classResultsProvider = FutureProvider.autoDispose
    .family<ClassResults, String>((ref, classId) {
      ref.watch(authControllerProvider.select((a) => a.isAuthenticated));
      return ResultsService.instance.classResults(classId);
    });

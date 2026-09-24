import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/error_handler.dart' as app_errors;
import '../models/learning_records_models.dart';
import '../models/past_questions_models.dart';
import 'supabase_service.dart';

class LearningRecordsService {
  LearningRecordsService._();
  static final instance = LearningRecordsService._();

  SupabaseClient get _client => SupabaseService.instance.client;

  String? get _uid => SupabaseService.instance.isInitialized
      ? SupabaseService.instance.currentUser?.id
      : null;

  Future<app_errors.Result<void>> _guard(
    String context,
    Future<void> Function() body,
  ) async {
    try {
      if (_uid == null) return app_errors.Result.failure('Sign in first.');
      await body();
      return app_errors.Result.success(null);
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(error, stack, context: context);
      return app_errors.Result.failure('That could not be saved.');
    }
  }

  // Exam practice ------------------------------------------------------------

  Future<app_errors.Result<void>> recordExamAttempt({
    required PastQuestionsSessionConfig config,
    required List<PastQuestion> questions,
    required Map<int, String?> answers,
    required Duration elapsed,
  }) {
    final missed = [
      for (final q in questions)
        if (!q.isCorrect(answers[q.id])) q.toJson(),
    ];
    final cleared = [
      for (final q in questions)
        if (q.isCorrect(answers[q.id])) q.id,
    ];
    return _guard('record_exam_attempt', () async {
      await _client.rpc(
        'record_exam_attempt',
        params: {
          'p_attempt': {
            'exam_slug': config.exam.slug,
            'exam_label': config.exam.shortLabel,
            'subject_slug': config.subject.slug,
            'subject_name': config.subject.name,
            'exam_year': config.year,
            'mode': config.wireMode,
            'total': questions.length,
            'correct': questions.length - missed.length,
            'duration_seconds': elapsed.inSeconds,
            'assignment_id': config.assignmentId,
          },
          'p_missed': missed,
          'p_cleared': cleared,
        },
      );
    });
  }

  Future<List<ExamAttempt>> fetchAttempts({String? userId, int limit = 60}) async {
    final uid = userId ?? _uid;
    if (uid == null) return const [];
    final rows = await _client
        .from('exam_attempts')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);
    return [
      for (final row in rows as List)
        ExamAttempt.fromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  Future<List<ExamMistake>> fetchOpenMistakes() async {
    final uid = _uid;
    if (uid == null) return const [];
    final rows = await _client
        .from('exam_mistakes')
        .select()
        .eq('user_id', uid)
        .isFilter('resolved_at', null)
        .order('last_missed_at', ascending: false)
        .limit(400);
    return [
      for (final row in rows as List)
        ExamMistake.fromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  // Maths --------------------------------------------------------------------

  Future<app_errors.Result<void>> recordMaths({
    required int level,
    required int correct,
    required int total,
    String? assignmentId,
  }) {
    return _guard('record_maths', () async {
      await _client.from('maths_results').insert({
        'level': level,
        'correct': correct,
        'total': total,
      });
      if (assignmentId != null) {
        await _submit(assignmentId, correct: correct, total: total);
      }
    });
  }

  Future<List<MathsResult>> fetchMaths({String? userId}) async {
    final uid = userId ?? _uid;
    if (uid == null) return const [];
    final rows = await _client
        .from('maths_results')
        .select('level, correct, total, created_at')
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(200);
    return [
      for (final row in rows as List)
        MathsResult.fromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  // Assignments --------------------------------------------------------------

  Future<void> _submit(
    String assignmentId, {
    required int correct,
    required int total,
  }) async {
    final existing = await _client
        .from('assignment_submissions')
        .select('correct, total')
        .eq('assignment_id', assignmentId)
        .eq('user_id', _uid!)
        .maybeSingle();
    if (existing != null) {
      final oldCorrect = (existing['correct'] as num).toInt();
      final oldTotal = (existing['total'] as num).toInt();
      if (percentOf(oldCorrect, oldTotal) > percentOf(correct, total)) return;
    }
    await _client.from('assignment_submissions').upsert({
      'assignment_id': assignmentId,
      'user_id': _uid,
      'correct': correct,
      'total': total,
      'completed_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'assignment_id,user_id');
  }

  /// Student view: every assignment from classes they belong to.
  Future<List<ClassAssignment>> fetchMyAssignments() async {
    if (_uid == null) return const [];
    final rows = await _client
        .from('class_assignments')
        .select()
        .order('created_at', ascending: false)
        .limit(40);
    return [
      for (final row in rows as List)
        ClassAssignment.fromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  Future<Map<String, AssignmentSubmission>> fetchMySubmissions() async {
    final uid = _uid;
    if (uid == null) return const {};
    final rows = await _client
        .from('assignment_submissions')
        .select()
        .eq('user_id', uid);
    return {
      for (final row in rows as List)
        (row as Map)['assignment_id'] as String: AssignmentSubmission.fromJson(
          Map<String, dynamic>.from(row),
        ),
    };
  }

  Future<app_errors.Result<void>> createAssignment({
    required String classId,
    required AssignmentKind kind,
    required String title,
    required Map<String, dynamic> config,
    DateTime? dueAt,
  }) {
    return _guard('create_assignment', () async {
      await _client.from('class_assignments').insert({
        'class_id': classId,
        'kind': kind.name,
        'title': title.trim(),
        'config': config,
        'due_at': dueAt?.toUtc().toIso8601String(),
      });
    });
  }

  Future<app_errors.Result<void>> deleteAssignment(String id) {
    return _guard('delete_assignment', () async {
      await _client.from('class_assignments').delete().eq('id', id);
    });
  }

  Future<List<ClassStudent>> fetchClassStudents(String classId) async {
    final members = await _client
        .from('class_members')
        .select('user_id')
        .eq('class_id', classId);
    final ids = [
      for (final row in members as List) (row as Map)['user_id'] as String,
    ];
    if (ids.isEmpty) return const [];
    final profiles = await _client
        .from('user_profiles')
        .select('user_id, display_name, avatar_emoji')
        .inFilter('user_id', ids);
    return [
      for (final row in profiles as List)
        ClassStudent(
          userId: (row as Map)['user_id'] as String,
          name: (row['display_name'] as String?)?.trim().isNotEmpty == true
              ? row['display_name'] as String
              : 'Student',
          avatar: row['avatar_emoji'] as String? ?? '🦊',
        ),
    ]..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Teacher view: assignments for one class with each student's status.
  Future<List<AssignmentProgress>> fetchClassAssignments(String classId) async {
    final rows = await _client
        .from('class_assignments')
        .select()
        .eq('class_id', classId)
        .order('created_at', ascending: false);
    final assignments = [
      for (final row in rows as List)
        ClassAssignment.fromJson(Map<String, dynamic>.from(row as Map)),
    ];
    if (assignments.isEmpty) return const [];
    final students = await fetchClassStudents(classId);
    final studentIds = students.map((s) => s.userId).toList();

    final submissionRows = await _client
        .from('assignment_submissions')
        .select()
        .inFilter('assignment_id', assignments.map((a) => a.id).toList());
    final submissions = [
      for (final row in submissionRows as List)
        AssignmentSubmission.fromJson(Map<String, dynamic>.from(row as Map)),
    ];

    final lessonIds = {
      for (final a in assignments)
        if (a.kind == AssignmentKind.lesson && a.lessonId != null) a.lessonId!,
    };
    final List<dynamic> lessonRows = lessonIds.isEmpty || studentIds.isEmpty
        ? const []
        : await _client
              .from('lesson_results')
              .select('user_id, lesson_id, score')
              .inFilter('lesson_id', lessonIds.toList())
              .inFilter('user_id', studentIds);

    return [
      for (final assignment in assignments)
        AssignmentProgress(
          assignment: assignment,
          students: students,
          submissions: {
            for (final s in submissions)
              if (s.assignmentId == assignment.id) s.userId: s,
          },
          lessonScores: {
            for (final row in lessonRows)
              if ((row as Map)['lesson_id'] == assignment.lessonId)
                row['user_id'] as String: (row['score'] as num).round(),
          },
        ),
    ];
  }

  // Reports ------------------------------------------------------------------

  Future<ProgressReport> fetchReport({String? userId}) async {
    final uid = userId ?? _uid;
    if (uid == null) throw StateError('Sign in to see a report.');
    final profile = await _client
        .from('user_profiles')
        .select('display_name, avatar_emoji')
        .eq('user_id', uid)
        .maybeSingle();
    final lessonRows = await _client
        .from('lesson_results')
        .select('lesson_id, score, completed_at')
        .eq('user_id', uid);
    final attempts = await fetchAttempts(userId: uid, limit: 200);
    final maths = await fetchMaths(userId: uid);
    var openMistakes = 0;
    if (uid == _uid) {
      final mistakes = await _client
          .from('exam_mistakes')
          .select('question_id')
          .eq('user_id', uid)
          .isFilter('resolved_at', null);
      openMistakes = (mistakes as List).length;
    }
    final name = (profile?['display_name'] as String?)?.trim();
    return ProgressReport(
      userId: uid,
      name: name == null || name.isEmpty ? 'Student' : name,
      avatar: profile?['avatar_emoji'] as String? ?? '🦊',
      lessons: [
        for (final row in lessonRows as List)
          LessonRecord(
            lessonId: (row as Map)['lesson_id'] as String,
            score: (row['score'] as num).round(),
            completedAt:
                DateTime.tryParse(row['completed_at'] as String? ?? '')
                    ?.toLocal() ??
                DateTime.now(),
          ),
      ],
      attempts: attempts,
      maths: maths,
      openMistakes: openMistakes,
      generatedAt: DateTime.now(),
    );
  }
}

import 'dart:async';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/error_handler.dart' as app_errors;
import '../models/live_test_models.dart';
import 'supabase_service.dart';

/// Live timed tests — create, join, answer, realtime monitor.
class LiveTestService {
  LiveTestService._();
  static final instance = LiveTestService._();

  SupabaseClient? get _client =>
      SupabaseService.instance.isInitialized ? Supabase.instance.client : null;

  String _randomJoinCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<app_errors.Result<LiveTest>> createTest({
    required String title,
    required String subject,
    required int durationSeconds,
    required List<({String prompt, List<LiveTestOption> options})> questions,
  }) async {
    try {
      final client = _client;
      final user = client?.auth.currentUser;
      if (client == null || user == null) {
        return app_errors.Result.failure('Sign in to create a live test.');
      }

      final classRow = await client.from('classes').select('id').eq('teacher_id', user.id).limit(1).maybeSingle();
      final classId = classRow?['id'] as String?;

      final testRow = await client.from('live_tests').insert({
        'teacher_id': user.id,
        'class_id': classId,
        'title': title,
        'subject': subject,
        'duration_seconds': durationSeconds,
        'status': 'draft',
        'join_code': _randomJoinCode(),
      }).select().single();

      final testId = testRow['id'] as String;
      for (var i = 0; i < questions.length; i++) {
        final q = questions[i];
        await client.from('live_test_questions').insert({
          'test_id': testId,
          'order_index': i,
          'prompt': q.prompt,
          'options': q.options.map((o) => o.toJson()).toList(),
          'points': 1,
        });
      }

      return fetchTest(testId);
    } on PostgrestException catch (e) {
      return app_errors.Result.failure('Could not create test: ${e.message}');
    } catch (e, stack) {
      await app_errors.ErrorHandler.reportError(e, stack, context: 'createTest');
      return app_errors.Result.failure('Unexpected error creating test.');
    }
  }

  Future<app_errors.Result<LiveTest>> createFromTemplate(LiveQuizTemplate template, {int durationSeconds = 300}) {
    final questions = template.questions.map((q) {
      final options = q.$2.asMap().entries.map((e) {
        return LiveTestOption(
          id: 'o${e.key}',
          label: e.value.$1,
          isCorrect: e.value.$2,
        );
      }).toList();
      return (prompt: q.$1, options: options);
    }).toList();

    return createTest(
      title: template.title,
      subject: template.subject,
      durationSeconds: durationSeconds,
      questions: questions,
    );
  }

  Future<app_errors.Result<LiveTest>> fetchTest(String testId) async {
    try {
      final client = _client;
      if (client == null) return app_errors.Result.failure('Not connected');

      final testRow = await client.from('live_tests').select().eq('id', testId).single();
      final qRows = await client
          .from('live_test_questions')
          .select()
          .eq('test_id', testId)
          .order('order_index');

      final questions = (qRows as List).map((r) => LiveTestQuestion.fromRow(Map<String, dynamic>.from(r as Map))).toList();

      return app_errors.Result.success(LiveTest.fromRow(Map<String, dynamic>.from(testRow as Map), questions: questions));
    } catch (e, stack) {
      await app_errors.ErrorHandler.reportError(e, stack, context: 'fetchTest');
      return app_errors.Result.failure('Could not load test.');
    }
  }

  Future<app_errors.Result<LiveTest>> startTest(String testId) async {
    try {
      final client = _client;
      if (client == null) return app_errors.Result.failure('Not connected');

      final existing = await fetchTest(testId);
      if (existing.isFailure || existing.data == null) return existing;

      final test = existing.data!;
      final now = DateTime.now().toUtc();
      final ends = now.add(Duration(seconds: test.durationSeconds));

      await client.from('live_tests').update({
        'status': 'live',
        'started_at': now.toIso8601String(),
        'ends_at': ends.toIso8601String(),
      }).eq('id', testId);

      return fetchTest(testId);
    } catch (e, stack) {
      await app_errors.ErrorHandler.reportError(e, stack, context: 'startTest');
      return app_errors.Result.failure('Could not start test.');
    }
  }

  Future<app_errors.Result<void>> endTest(String testId) async {
    try {
      final client = _client;
      if (client == null) return app_errors.Result.failure('Not connected');

      await client.from('live_tests').update({'status': 'ended'}).eq('id', testId);
      return app_errors.Result.success(null);
    } catch (e) {
      return app_errors.Result.failure('Could not end test.');
    }
  }

  Future<app_errors.Result<List<LiveTest>>> fetchTeacherRecentTests({int limit = 8}) async {
    try {
      final client = _client;
      final user = client?.auth.currentUser;
      if (client == null || user == null) {
        return app_errors.Result.failure('Sign in to view tests.');
      }

      final rows = await client
          .from('live_tests')
          .select()
          .eq('teacher_id', user.id)
          .order('created_at', ascending: false)
          .limit(limit);

      final tests = <LiveTest>[];
      for (final row in rows as List) {
        final testId = row['id'] as String;
        final full = await fetchTest(testId);
        if (full.isSuccess && full.data != null) tests.add(full.data!);
      }
      return app_errors.Result.success(tests);
    } catch (e, stack) {
      await app_errors.ErrorHandler.reportError(e, stack, context: 'fetchTeacherRecentTests');
      return app_errors.Result.failure('Could not load recent tests.');
    }
  }

  Future<app_errors.Result<LiveTest?>> fetchActiveTestForStudent() async {
    try {
      final client = _client;
      final user = client?.auth.currentUser;
      if (client == null || user == null) return app_errors.Result.success(null);

      final memberships = await client.from('class_members').select('class_id').eq('user_id', user.id);
      final classIds = (memberships as List).map((r) => r['class_id'] as String).toList();
      if (classIds.isEmpty) return app_errors.Result.success(null);

      final rows = await client
          .from('live_tests')
          .select()
          .eq('status', 'live')
          .inFilter('class_id', classIds)
          .order('started_at', ascending: false)
          .limit(1);

      if ((rows as List).isEmpty) return app_errors.Result.success(null);

      final testId = rows.first['id'] as String;
      final full = await fetchTest(testId);
      return app_errors.Result.success(full.data);
    } catch (e) {
      return app_errors.Result.success(null);
    }
  }

  Future<app_errors.Result<LiveTestParticipant>> joinTest(String testId) async {
    try {
      final client = _client;
      final user = client?.auth.currentUser;
      if (client == null || user == null) {
        return app_errors.Result.failure('Sign in to join.');
      }

      final profile = await client
          .from('user_profiles')
          .select('display_name, avatar_emoji')
          .eq('user_id', user.id)
          .maybeSingle();

      final row = await client.from('live_test_participants').upsert({
        'test_id': testId,
        'user_id': user.id,
        'display_name': profile?['display_name'] ?? 'Student',
        'avatar_emoji': profile?['avatar_emoji'] ?? '🦊',
        'status': 'active',
      }).select().single();

      return app_errors.Result.success(LiveTestParticipant.fromRow(Map<String, dynamic>.from(row as Map)));
    } catch (e, stack) {
      await app_errors.ErrorHandler.reportError(e, stack, context: 'joinTest');
      return app_errors.Result.failure('Could not join test.');
    }
  }

  Future<app_errors.Result<void>> submitAnswer({
    required String testId,
    required String questionId,
    required String selectedOptionId,
    required List<LiveTestOption> options,
  }) async {
    try {
      final client = _client;
      final user = client?.auth.currentUser;
      if (client == null || user == null) return app_errors.Result.failure('Not signed in');

      final isCorrect = options.any((o) => o.id == selectedOptionId && o.isCorrect);

      await client.from('live_test_answers').upsert({
        'test_id': testId,
        'question_id': questionId,
        'user_id': user.id,
        'selected_option_id': selectedOptionId,
        'is_correct': isCorrect,
        'answered_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (isCorrect) {
        final participant = await client
            .from('live_test_participants')
            .select('score, correct_count')
            .eq('test_id', testId)
            .eq('user_id', user.id)
            .maybeSingle();

        await client.from('live_test_participants').update({
          'score': ((participant?['score'] as num?)?.toInt() ?? 0) + 1,
          'correct_count': ((participant?['correct_count'] as num?)?.toInt() ?? 0) + 1,
          'status': 'active',
        }).eq('test_id', testId).eq('user_id', user.id);
      }

      return app_errors.Result.success(null);
    } catch (e, stack) {
      await app_errors.ErrorHandler.reportError(e, stack, context: 'submitAnswer');
      return app_errors.Result.failure('Could not save answer.');
    }
  }

  Future<app_errors.Result<void>> submitTest(String testId) async {
    try {
      final client = _client;
      final user = client?.auth.currentUser;
      if (client == null || user == null) return app_errors.Result.failure('Not signed in');

      await client.from('live_test_participants').update({
        'status': 'submitted',
        'submitted_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('test_id', testId).eq('user_id', user.id);

      return app_errors.Result.success(null);
    } catch (e) {
      return app_errors.Result.failure('Could not submit test.');
    }
  }

  Future<app_errors.Result<LiveTestSnapshot>> fetchSnapshot(String testId) async {
    try {
      final client = _client;
      if (client == null) return app_errors.Result.failure('Not connected');

      final testResult = await fetchTest(testId);
      if (testResult.isFailure || testResult.data == null) {
        return app_errors.Result.failure(testResult.error ?? 'Test not found');
      }

      final pRows = await client.from('live_test_participants').select().eq('test_id', testId);
      final aRows = await client.from('live_test_answers').select().eq('test_id', testId);

      return app_errors.Result.success(LiveTestSnapshot(
        test: testResult.data!,
        participants: (pRows as List).map((r) => LiveTestParticipant.fromRow(Map<String, dynamic>.from(r as Map))).toList(),
        answers: (aRows as List).map((r) => LiveTestAnswer.fromRow(Map<String, dynamic>.from(r as Map))).toList(),
      ));
    } catch (e, stack) {
      await app_errors.ErrorHandler.reportError(e, stack, context: 'fetchSnapshot');
      return app_errors.Result.failure('Could not load live data.');
    }
  }

  /// Realtime stream of snapshot updates for teacher monitor.
  Stream<LiveTestSnapshot> watchSnapshot(String testId) {
    final controller = StreamController<LiveTestSnapshot>();
    RealtimeChannel? channel;
    Timer? timer;

    Future<void> refresh() async {
      final snap = await fetchSnapshot(testId);
      if (snap.isSuccess && snap.data != null && !controller.isClosed) {
        controller.add(snap.data!);
      }
    }

    refresh();

    final client = _client;
    if (client != null) {
      channel = client
          .channel('live_test_$testId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'live_test_answers',
            filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'test_id', value: testId),
            callback: (_) => refresh(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'live_test_participants',
            filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'test_id', value: testId),
            callback: (_) => refresh(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'live_tests',
            filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: testId),
            callback: (_) => refresh(),
          )
          .subscribe();

      timer = Timer.periodic(const Duration(seconds: 4), (_) => refresh());
    }

    controller.onCancel = () async {
      timer?.cancel();
      if (channel != null && client != null) await client.removeChannel(channel!);
    };

    return controller.stream;
  }

  /// Active live test for the signed-in student (banner + auto-join).
  Stream<LiveTest?> watchActiveTestForStudent() {
    final controller = StreamController<LiveTest?>();
    RealtimeChannel? channel;
    Timer? timer;

    Future<void> refresh() async {
      final r = await fetchActiveTestForStudent();
      if (!controller.isClosed) controller.add(r.data);
    }

    refresh();

    final client = _client;
    if (client != null) {
      channel = client
          .channel('student_live_tests')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'live_tests',
            callback: (_) => refresh(),
          )
          .subscribe();

      timer = Timer.periodic(const Duration(seconds: 6), (_) => refresh());
    }

    controller.onCancel = () async {
      timer?.cancel();
      if (channel != null && client != null) await client.removeChannel(channel!);
    };

    return controller.stream;
  }
}

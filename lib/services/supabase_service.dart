import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../core/error_handler.dart' as app_errors;
import '../models/models.dart';
import '../models/user_preferences.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._();
  SupabaseService._();

  SupabaseClient? _client;

  SupabaseClient get client {
    final value = _client;
    if (value == null) {
      throw app_errors.AppException('The learning service is unavailable.');
    }
    return value;
  }

  bool get isInitialized => _client != null;
  User? get currentUser => isInitialized ? client.auth.currentUser : null;
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: Env.supabasePublishableKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      _client = Supabase.instance.client;
      assert(() {
        // ignore: avoid_print
        print('Supabase client target: ${Env.supabaseUrl}');
        return true;
      }());
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'Supabase initialization failed',
      );
      rethrow;
    }
  }

  Future<void> upsertUserProfile(Map<String, dynamic> data) async {
    await client.from('user_profiles').upsert(data, onConflict: 'user_id');
  }

  Future<app_errors.Result<User>> signUp(
    String email,
    String password,
    String displayName, {
    String? gender,
    int? age,
  }) async {
    if (!isInitialized) {
      return app_errors.Result.failure(
        'Account creation is temporarily unavailable.',
      );
    }
    try {
      final response = await client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'display_name': displayName.trim(),
          'gender': ?gender,
          'age': ?age,
        },
      );
      final user = response.user;
      if (user == null) {
        return app_errors.Result.failure('Sign up failed. Please try again.');
      }
      return app_errors.Result.success(user);
    } on AuthException catch (error) {
      return app_errors.Result.failure(_parseAuthError(error));
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'Sign up error',
      );
      return app_errors.Result.failure(
        'Account creation could not be completed.',
      );
    }
  }

  Future<app_errors.Result<User>> signIn(String email, String password) async {
    if (!isInitialized) {
      return app_errors.Result.failure('Sign in is temporarily unavailable.');
    }
    try {
      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      if (user == null) {
        return app_errors.Result.failure(
          'Sign in failed. Please check your credentials.',
        );
      }
      return app_errors.Result.success(user);
    } on AuthException catch (error) {
      return app_errors.Result.failure(_parseAuthError(error));
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'Sign in error',
      );
      return app_errors.Result.failure('Sign in could not be completed.');
    }
  }

  Future<app_errors.Result<void>> signOut() async {
    try {
      await client.auth.signOut();
      return app_errors.Result.success(null);
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'Sign out error',
      );
      return app_errors.Result.failure('Failed to sign out. Please try again.');
    }
  }

  Future<app_errors.Result<void>> resetPassword(String email) async {
    try {
      await client.auth.resetPasswordForEmail(email.trim());
      return app_errors.Result.success(null);
    } on AuthException catch (error) {
      return app_errors.Result.failure(_parseAuthError(error));
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'Password reset error',
      );
      return app_errors.Result.failure(
        'The password reset email could not be sent.',
      );
    }
  }

  Future<app_errors.Result<void>> completeFoundationLesson({
    required String lessonId,
    required int score,
    required List<Map<String, dynamic>> answers,
    required int xpReward,
    int estimatedMinutes = 10,
  }) async {
    try {
      if (currentUser == null) {
        return app_errors.Result.failure('Not authenticated');
      }
      app_errors.ErrorHandler.addBreadcrumb(
        'Saving Foundation lesson completion',
        category: 'foundation.progress',
        data: {'lesson_id': lessonId, 'score': score},
      );
      final response = await client.functions.invoke(
        'foundation-complete',
        body: {
          'lessonId': lessonId,
          'score': score,
          'answers': answers,
          'minutes': estimatedMinutes,
        },
      );
      final data = response.data;
      if (response.status >= 400 || data is Map && data['error'] != null) {
        return app_errors.Result.failure(
          'Could not save your Foundation result.',
        );
      }
      app_errors.ErrorHandler.addBreadcrumb(
        'Foundation lesson completion saved',
        category: 'foundation.progress',
        data: {'lesson_id': lessonId},
      );
      return app_errors.Result.success(null);
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'Complete Foundation lesson error',
      );
      return app_errors.Result.failure(
        'Could not save your Foundation result.',
      );
    }
  }

  Future<app_errors.Result<String>> ensureTeacherClass({
    String? className,
  }) async {
    try {
      final teacherId = currentUser?.id;
      if (teacherId == null) {
        return app_errors.Result.failure('Not authenticated');
      }
      final existing = await client
          .from('classes')
          .select('id')
          .eq('teacher_id', teacherId)
          .limit(1)
          .maybeSingle();
      if (existing != null) {
        return app_errors.Result.success(existing['id'] as String);
      }
      final row = await client
          .from('classes')
          .insert({
            'name': className ?? 'My Class',
            'teacher_id': teacherId,
            'description': 'Your Mandarin Foundation class',
          })
          .select('id')
          .single();
      return app_errors.Result.success(row['id'] as String);
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'Ensure teacher class',
      );
      return app_errors.Result.failure('Could not create your class.');
    }
  }

  Future<app_errors.Result<({String id, String name, String code})>>
  fetchTeacherClassInfo() async {
    try {
      final ensured = await ensureTeacherClass();
      if (ensured.isFailure) {
        return app_errors.Result.failure(ensured.error!);
      }
      final teacherId = currentUser?.id;
      if (teacherId == null) {
        return app_errors.Result.failure('Not authenticated');
      }
      final row = await client
          .from('classes')
          .select('id, name, join_code')
          .eq('teacher_id', teacherId)
          .limit(1)
          .single();
      var code = row['join_code'] as String?;
      if (code == null || code.isEmpty) {
        final regenerated = await regenerateClassCode(row['id'] as String);
        code = regenerated.data;
      }
      return app_errors.Result.success((
        id: row['id'] as String,
        name: row['name'] as String? ?? 'My Class',
        code: code ?? '',
      ));
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'Fetch class info',
      );
      return app_errors.Result.failure('Could not load your class code.');
    }
  }

  Future<app_errors.Result<String>> regenerateClassCode(String classId) async {
    try {
      if (currentUser == null) {
        return app_errors.Result.failure('Not authenticated');
      }
      final response = await client.functions.invoke(
        'class-access',
        body: {'action': 'regenerate', 'classId': classId},
      );
      final data = response.data;
      final code = data is Map ? data['code'] as String? : null;
      if (code == null || code.isEmpty) {
        return app_errors.Result.failure('Could not generate a new code.');
      }
      return app_errors.Result.success(code);
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'Regenerate class code',
      );
      return app_errors.Result.failure('Could not generate a new code.');
    }
  }

  Future<app_errors.Result<String>> joinClassWithCode(String code) async {
    try {
      if (currentUser == null) {
        return app_errors.Result.failure('Not authenticated');
      }
      final trimmed = code.trim().toUpperCase();
      if (trimmed.isEmpty) {
        return app_errors.Result.failure('Enter a class code.');
      }
      final response = await client.functions.invoke(
        'class-access',
        body: {'action': 'join', 'code': trimmed},
      );
      final data = response.data;
      if (response.status >= 400 || data is! Map) {
        return app_errors.Result.failure('That code didn’t match a class.');
      }
      final name = data['className'] as String? ?? 'your class';
      return app_errors.Result.success(name);
    } on FunctionException {
      return app_errors.Result.failure(
        'That code didn’t match a class. Double-check with your teacher.',
      );
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'Join class',
      );
      return app_errors.Result.failure('Could not join the class.');
    }
  }

  Future<app_errors.Result<List<StudentPerformance>>> fetchClassRoster() async {
    try {
      final teacherId = currentUser?.id;
      if (teacherId == null) {
        return app_errors.Result.failure('Not authenticated');
      }
      final classRow = await client
          .from('classes')
          .select('id')
          .eq('teacher_id', teacherId)
          .limit(1)
          .maybeSingle();
      if (classRow == null) return app_errors.Result.success(const []);

      final memberRows = await client
          .from('class_members')
          .select('user_id')
          .eq('class_id', classRow['id'] as String);
      final roster = <StudentPerformance>[];
      for (final rawMember in memberRows as List) {
        final member = Map<String, dynamic>.from(rawMember as Map);
        final userId = member['user_id'] as String;
        final profile = await client
            .from('user_profiles')
            .select('display_name, avatar_emoji')
            .eq('user_id', userId)
            .maybeSingle();
        if (profile == null) continue;
        final results = await client
            .from('lesson_results')
            .select('score, completed_at')
            .eq('user_id', userId);
        final scores = [
          for (final raw in results as List)
            ((raw as Map)['score'] as num).toDouble(),
        ];
        final average = scores.isEmpty
            ? 0.0
            : scores.reduce((left, right) => left + right) /
                  scores.length /
                  100;
        roster.add(
          StudentPerformance(
            name: profile['display_name'] as String? ?? 'Student',
            avatarEmoji: profile['avatar_emoji'] as String? ?? '🦊',
            overallMastery: average,
            lessonsDone: scores.length,
            strength: 'Mandarin Foundation',
            growthArea: 'Continue the path',
            weeklyActivity: const [],
          ),
        );
      }
      return app_errors.Result.success(roster);
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'Fetch class roster',
      );
      return app_errors.Result.failure('Could not load students.');
    }
  }

  Future<app_errors.Result<UserPreferences>> fetchUserPreferences() async {
    try {
      final userId = currentUser?.id;
      if (userId == null) {
        return app_errors.Result.failure('Not authenticated');
      }
      final row = await client
          .from('user_profiles')
          .select('preferences')
          .eq('user_id', userId)
          .maybeSingle();
      final preferences = row?['preferences'];
      return app_errors.Result.success(
        UserPreferences.fromJson(
          preferences is Map ? Map<String, dynamic>.from(preferences) : null,
        ),
      );
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'Fetch preferences',
      );
      return app_errors.Result.failure('Failed to load settings.');
    }
  }

  Future<app_errors.Result<void>> saveUserPreferences(
    UserPreferences preferences,
  ) async {
    try {
      final userId = currentUser?.id;
      if (userId == null) {
        return app_errors.Result.failure('Not authenticated');
      }
      await client
          .from('user_profiles')
          .update({
            'preferences': preferences.toJson(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);
      return app_errors.Result.success(null);
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'Save preferences',
      );
      return app_errors.Result.failure('Failed to save settings.');
    }
  }

  String _parseAuthError(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (message.contains('email not confirmed')) {
      return 'Check your email to confirm your account.';
    }
    if (message.contains('already registered')) {
      return 'An account already exists for this email.';
    }
    if (message.contains('password')) {
      return 'Use a stronger password with at least 8 characters.';
    }
    return 'Authentication could not be completed.';
  }
}

import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../core/error_handler.dart' as app_errors;
import '../data/lesson_mapper.dart';
import '../models/models.dart';
import '../models/user_preferences.dart';

/// Supabase client wrapper with error handling.
class SupabaseService {
  static final SupabaseService instance = SupabaseService._();
  SupabaseService._();

  SupabaseClient? _client;
  SupabaseClient get client {
    if (_client == null) {
      throw app_errors.AppException('Supabase not initialized. Call initialize() first.');
    }
    return _client!;
  }

  bool get isInitialized => _client != null;

  /// Upsert by [user_id] — required because the table PK is `id`, not `user_id`.
  Future<void> upsertUserProfile(Map<String, dynamic> data) async {
    await client.from('user_profiles').upsert(data, onConflict: 'user_id');
  }

  /// Initialize Supabase client.
  Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        anonKey: Env.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      _client = Supabase.instance.client;
    } catch (e, stack) {
      await app_errors.ErrorHandler.reportError(
        e,
        stack,
        context: 'Supabase initialization failed',
      );
      rethrow;
    }
  }

  // ================================================================== Auth

  /// Sign up with email and password.
  Future<app_errors.Result<User>> signUp(String email, String password, String displayName) async {
    if (!isInitialized) {
      return app_errors.Result.failure(
        'Supabase is not configured. Add SUPABASE_URL and SUPABASE_ANON_KEY to .env.',
      );
    }
    try {
      final response = await client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'display_name': displayName.trim()},
      );

      if (response.user == null) {
        return app_errors.Result.failure('Sign up failed. Please try again.');
      }

      return app_errors.Result.success(response.user!);
    } on AuthException catch (e) {
      await app_errors.ErrorHandler.reportError(e, null, context: 'Sign up failed');
      return app_errors.Result.failure(_parseAuthError(e));
    } catch (e, stack) {
      await app_errors.ErrorHandler.reportError(e, stack, context: 'Sign up error');
      return app_errors.Result.failure('An unexpected error occurred. Please try again.');
    }
  }

  /// Sign in with email and password.
  Future<app_errors.Result<User>> signIn(String email, String password) async {
    if (!isInitialized) {
      return app_errors.Result.failure(
        'Supabase is not configured. Add SUPABASE_URL and SUPABASE_ANON_KEY to .env, '
        'or use Demo login.',
      );
    }
    try {
      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      if (response.user == null) {
        return app_errors.Result.failure('Sign in failed. Please check your credentials.');
      }

      return app_errors.Result.success(response.user!);
    } on AuthException catch (e) {
      await app_errors.ErrorHandler.reportError(e, null, context: 'Sign in failed');
      return app_errors.Result.failure(_parseAuthError(e));
    } catch (e, stack) {
      await app_errors.ErrorHandler.reportError(e, stack, context: 'Sign in error');
      return app_errors.Result.failure('An unexpected error occurred. Please try again.');
    }
  }

  /// Sign out current user.
  Future<app_errors.Result<void>> signOut() async {
    try {
      await client.auth.signOut();
      return app_errors.Result.success(null);
    } catch (e, stack) {
      await app_errors.ErrorHandler.reportError(e, stack, context: 'Sign out error');
      return app_errors.Result.failure('Failed to sign out. Please try again.');
    }
  }

  /// Get current user.
  User? get currentUser => client.auth.currentUser;

  /// Stream of auth state changes.
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  /// Request password reset email.
  Future<app_errors.Result<void>> resetPassword(String email) async {
    try {
      await client.auth.resetPasswordForEmail(email.trim());
      return app_errors.Result.success(null);
    } on AuthException catch (e) {
      await app_errors.ErrorHandler.reportError(e, null, context: 'Password reset failed');
      return app_errors.Result.failure(_parseAuthError(e));
    } catch (e, stack) {
      await app_errors.ErrorHandler.reportError(e, stack, context: 'Password reset error');
      return app_errors.Result.failure('An unexpected error occurred. Please try again.');
    }
  }

  // ================================================================= Lessons

  /// Fetch all published lessons with optional progress for current user.
  Future<app_errors.Result<List<Lesson>>> fetchLessons() async {
    try {
      final rows = await client
          .from('lessons')
          .select()
          .eq('status', 'published')
          .order('created_at', ascending: false);

      final progressMap = await _progressMapForCurrentUser();

      final lessons = (rows as List)
          .map((row) => LessonMapper.fromRow(
                Map<String, dynamic>.from(row as Map),
                progress: progressMap[row['id'] as String] ?? 0,
              ))
          .toList();

      return app_errors.Result.success(lessons);
    } on PostgrestException catch (e) {
      await app_errors.ErrorHandler.reportError(e, null, context: 'Fetch lessons failed');
      return app_errors.Result.failure('Failed to load lessons. Please try again.');
    } catch (e, stack) {
      await app_errors.ErrorHandler.reportError(e, stack, context: 'Fetch lessons error');
      return app_errors.Result.failure('An unexpected error occurred.');
    }
  }

  /// Lessons assigned to the current user or in progress.
  Future<app_errors.Result<List<Lesson>>> fetchAssignedLessons() async {
    try {
      if (currentUser == null) {
        return app_errors.Result.failure('Not authenticated');
      }

      final userId = currentUser!.id;
      final progressRows = await client
          .from('lesson_progress')
          .select('lesson_id, progress')
          .eq('user_id', userId)
          .gt('progress', 0);

      final assignmentRows = await client
          .from('lesson_assignments')
          .select('lesson_id')
          .eq('user_id', userId);

      final progressMap = {
        for (final row in progressRows as List)
          row['lesson_id'] as String: (row['progress'] as num).toDouble(),
      };

      final assignedIds = {
        ...progressMap.keys,
        for (final row in assignmentRows as List) row['lesson_id'] as String,
      };

      if (assignedIds.isEmpty) {
        final all = await fetchLessons();
        if (all.isSuccess && all.data!.isNotEmpty) {
          return app_errors.Result.success([all.data!.first]);
        }
        return app_errors.Result.success([]);
      }

      final lessonRows = await client.from('lessons').select().inFilter('id', assignedIds.toList());

      final lessons = (lessonRows as List)
          .map((row) => LessonMapper.fromRow(
                Map<String, dynamic>.from(row as Map),
                progress: progressMap[row['id'] as String] ?? 0,
              ))
          .toList();

      return app_errors.Result.success(lessons);
    } on PostgrestException catch (e) {
      await app_errors.ErrorHandler.reportError(e, null, context: 'Fetch assigned lessons failed');
      return app_errors.Result.failure('Failed to load your lessons. Please try again.');
    } catch (e, stack) {
      await app_errors.ErrorHandler.reportError(e, stack, context: 'Fetch assigned lessons error');
      return app_errors.Result.failure('An unexpected error occurred.');
    }
  }

  Future<Map<String, double>> _progressMapForCurrentUser() async {
    if (currentUser == null) return {};
    final rows = await client
        .from('lesson_progress')
        .select('lesson_id, progress')
        .eq('user_id', currentUser!.id);
    return {
      for (final row in rows as List)
        row['lesson_id'] as String: (row['progress'] as num).toDouble(),
    };
  }

  /// Save lesson progress (0..1).
  Future<app_errors.Result<void>> updateLessonProgress(
    String lessonId,
    double progress, {
    int? checkpointsCorrect,
    int? checkpointsTotal,
    bool completed = false,
  }) async {
    try {
      if (currentUser == null) {
        return app_errors.Result.failure('Not authenticated');
      }

      await client.from('lesson_progress').upsert({
        'user_id': currentUser!.id,
        'lesson_id': lessonId,
        'progress': progress.clamp(0, 1),
        if (checkpointsCorrect != null) 'checkpoints_correct': checkpointsCorrect,
        if (checkpointsTotal != null) 'checkpoints_total': checkpointsTotal,
        if (completed) 'completed_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      return app_errors.Result.success(null);
    } on PostgrestException catch (e) {
      await app_errors.ErrorHandler.reportError(e, null, context: 'Update progress failed');
      return app_errors.Result.failure('Failed to save your progress.');
    } catch (e, stack) {
      await app_errors.ErrorHandler.reportError(e, stack, context: 'Update progress error');
      return app_errors.Result.failure('An unexpected error occurred.');
    }
  }

  /// Complete a lesson: progress, XP, profile stats, first-badge unlock.
  Future<app_errors.Result<void>> completeLesson({
    required String lessonId,
    required int xpReward,
    required int checkpointsCorrect,
    required int checkpointsTotal,
    required int estimatedMinutes,
  }) async {
    try {
      if (currentUser == null) {
        return app_errors.Result.failure('Not authenticated');
      }

      final userId = currentUser!.id;

      await updateLessonProgress(
        lessonId,
        1,
        checkpointsCorrect: checkpointsCorrect,
        checkpointsTotal: checkpointsTotal,
        completed: true,
      );

      await client.rpc('award_xp', params: {
        'p_user_id': userId,
        'p_amount': xpReward,
        'p_reason': 'Lesson completed',
        'p_lesson_id': lessonId,
      });

      await client.rpc('update_user_streak', params: {'p_user_id': userId});

      final profile = await client
          .from('user_profiles')
          .select('lessons_completed')
          .eq('user_id', userId)
          .single();

      final completedCount = ((profile['lessons_completed'] as num?)?.toInt() ?? 0) + 1;

      await client.from('user_profiles').update({
        'lessons_completed': completedCount,
        'minutes_learned': ((await _minutesLearned(userId)) + estimatedMinutes),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);

      if (completedCount == 1) {
        await _unlockBadgeByName(userId, 'First Steps');
      }

      if (checkpointsTotal > 0 && checkpointsCorrect == checkpointsTotal) {
        await _incrementPerfectQuizCount(userId);
      }

      await _evaluateBadgeProgress(userId);

      return app_errors.Result.success(null);
    } on PostgrestException catch (e) {
      await app_errors.ErrorHandler.reportError(e, null, context: 'Complete lesson failed');
      return app_errors.Result.failure('Failed to save lesson completion.');
    } catch (e, stack) {
      await app_errors.ErrorHandler.reportError(e, stack, context: 'Complete lesson error');
      return app_errors.Result.failure('An unexpected error occurred.');
    }
  }

  Future<int> _minutesLearned(String userId) async {
    final row = await client
        .from('user_profiles')
        .select('minutes_learned')
        .eq('user_id', userId)
        .maybeSingle();
    return (row?['minutes_learned'] as num?)?.toInt() ?? 0;
  }

  Future<void> _unlockBadgeByName(String userId, String name) async {
    await client.rpc('unlock_user_badge', params: {
      'p_user_id': userId,
      'p_badge_name': name,
    });
  }

  Future<void> _incrementPerfectQuizCount(String userId) async {
    final row = await client
        .from('user_profiles')
        .select('preferences')
        .eq('user_id', userId)
        .maybeSingle();
    final prefs = Map<String, dynamic>.from((row?['preferences'] as Map?) ?? {});
    final count = (prefs['perfect_quizzes'] as num?)?.toInt() ?? 0;
    prefs['perfect_quizzes'] = count + 1;
    await client.from('user_profiles').update({
      'preferences': prefs,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('user_id', userId);
    if (count + 1 >= 5) {
      await _unlockBadgeByName(userId, 'Quiz Whiz');
    }
  }

  Future<void> _evaluateBadgeProgress(String userId) async {
    final profile = await client
        .from('user_profiles')
        .select('lessons_completed, streak_days, preferences')
        .eq('user_id', userId)
        .maybeSingle();
    if (profile == null) return;

    final lessonsCompleted = (profile['lessons_completed'] as num?)?.toInt() ?? 0;
    if (lessonsCompleted >= 10) {
      await client.rpc('unlock_user_badge', params: {
        'p_user_id': userId,
        'p_badge_name': 'Math Master',
      });
    }
  }

  Future<app_errors.Result<List<RewardBadge>>> fetchBadges() async {
    try {
      final badgeRows = await client.from('badges').select().order('name');
      final userId = currentUser?.id;
      Map<String, Map<String, dynamic>> userBadgeMap = {};

      if (userId != null) {
        final userRows = await client
            .from('user_badges')
            .select('badge_id, progress, unlocked_at')
            .eq('user_id', userId);
        for (final row in userRows as List) {
          userBadgeMap[row['badge_id'] as String] = Map<String, dynamic>.from(row as Map);
        }
      }

      final badges = (badgeRows as List).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        final ub = userBadgeMap[map['id'] as String];
        return LessonMapper.badgeFromRow(
          map,
          unlocked: ub?['unlocked_at'] != null,
          progress: (ub?['progress'] as num?)?.toDouble() ?? 0,
        );
      }).toList();

      return app_errors.Result.success(badges);
    } catch (e, stack) {
      await app_errors.ErrorHandler.reportError(e, stack, context: 'Fetch badges error');
      return app_errors.Result.failure('Failed to load badges.');
    }
  }

  Future<app_errors.Result<List<LeaderboardEntry>>> fetchLeaderboard({int limit = 10}) async {
    try {
      final rows = await client
          .from('user_profiles')
          .select('user_id, display_name, avatar_emoji, xp')
          .order('xp', ascending: false)
          .limit(limit);

      final currentId = currentUser?.id;
      final entries = <LeaderboardEntry>[];
      var rank = 1;
      for (final row in rows as List) {
        entries.add(LessonMapper.leaderboardFromProfile(
          Map<String, dynamic>.from(row as Map),
          rank: rank++,
          currentUserId: currentId,
        ));
      }
      return app_errors.Result.success(entries);
    } catch (e, stack) {
      await app_errors.ErrorHandler.reportError(e, stack, context: 'Fetch leaderboard error');
      return app_errors.Result.failure('Failed to load leaderboard.');
    }
  }

  // ============================================================== User Profile

  /// Fetch user profile.
  Future<app_errors.Result<LearnerProfile>> fetchUserProfile() async {
    try {
      if (currentUser == null) {
        return app_errors.Result.failure('Not authenticated');
      }

      final row = await client
          .from('user_profiles')
          .select()
          .eq('user_id', currentUser!.id)
          .single();

      return app_errors.Result.success(LearnerProfile(
        name: row['display_name'] as String? ?? 'Explorer',
        avatarEmoji: row['avatar_emoji'] as String? ?? '🦊',
        level: (row['level'] as num?)?.toInt() ?? 1,
        xp: (row['xp'] as num?)?.toInt() ?? 0,
        xpToNextLevel: ((row['level'] as num?)?.toInt() ?? 1) * 500,
        streakDays: (row['streak_days'] as num?)?.toInt() ?? 0,
        lessonsCompleted: (row['lessons_completed'] as num?)?.toInt() ?? 0,
        minutesLearned: (row['minutes_learned'] as num?)?.toInt() ?? 0,
      ));
    } on PostgrestException catch (e) {
      await app_errors.ErrorHandler.reportError(e, null, context: 'Fetch profile failed');
      return app_errors.Result.failure('Failed to load your profile.');
    } catch (e, stack) {
      await app_errors.ErrorHandler.reportError(e, stack, context: 'Fetch profile error');
      return app_errors.Result.failure('An unexpected error occurred.');
    }
  }

  /// Update user profile.
  Future<app_errors.Result<void>> updateUserProfile({
    String? displayName,
    String? avatarEmoji,
  }) async {
    try {
      if (currentUser == null) {
        return app_errors.Result.failure('Not authenticated');
      }

      final updates = <String, dynamic>{
        'user_id': currentUser!.id,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (displayName != null) updates['display_name'] = displayName;
      if (avatarEmoji != null) updates['avatar_emoji'] = avatarEmoji;

      await SupabaseService.instance.upsertUserProfile(updates);

      return app_errors.Result.success(null);
    } on PostgrestException catch (e) {
      await app_errors.ErrorHandler.reportError(e, null, context: 'Update profile failed');
      return app_errors.Result.failure('Failed to update your profile.');
    } catch (e, stack) {
      await app_errors.ErrorHandler.reportError(e, stack, context: 'Update profile error');
      return app_errors.Result.failure('An unexpected error occurred.');
    }
  }

  // ============================================================== File Storage

  /// Publish a new lesson to the catalog (teacher create flow).
  Future<app_errors.Result<Lesson>> publishLesson({
    required String title,
    required String subject,
    required String description,
    required ContentSource source,
    required List<LessonSlide> slides,
    required List<Checkpoint> checkpoints,
    String emoji = '📘',
    String? colorHex,
    int gradeBandLabel = 5,
    int xpReward = 120,
    int estimatedMinutes = 10,
  }) async {
    try {
      if (currentUser == null) {
        return app_errors.Result.failure('You must be signed in to publish a lesson.');
      }

      final profile = await client
          .from('user_profiles')
          .select('display_name')
          .eq('user_id', currentUser!.id)
          .maybeSingle();

      final authorName = profile?['display_name'] as String? ?? 'Teacher';

      final row = LessonMapper.lessonToInsert(
        title: title,
        subject: subject,
        description: description,
        source: source,
        authorId: currentUser!.id,
        authorName: authorName,
        slides: slides,
        checkpoints: checkpoints,
        emoji: emoji,
        colorHex: colorHex ?? '#6C5CE7',
        gradeBandLabel: gradeBandLabel,
        xpReward: xpReward,
        estimatedMinutes: estimatedMinutes,
      );

      final inserted = await client.from('lessons').insert(row).select().single();
      final lesson = LessonMapper.fromRow(Map<String, dynamic>.from(inserted as Map));
      return app_errors.Result.success(lesson);
    } on PostgrestException catch (e) {
      await app_errors.ErrorHandler.reportError(e, null, context: 'Publish lesson failed');
      return app_errors.Result.failure('Failed to publish lesson. ${e.message}');
    } catch (e, stack) {
      await app_errors.ErrorHandler.reportError(e, stack, context: 'Publish lesson error');
      return app_errors.Result.failure('An unexpected error occurred.');
    }
  }

  Future<app_errors.Result<Lesson>> fetchLessonById(String lessonId) async {
    try {
      if (currentUser == null) {
        return app_errors.Result.failure('Sign in to view this lesson.');
      }

      final row = await client.from('lessons').select().eq('id', lessonId).maybeSingle();
      if (row == null) {
        return app_errors.Result.failure('Lesson not found or you do not have access.');
      }

      final progressMap = await _progressMapForCurrentUser();
      final lesson = LessonMapper.fromRow(
        Map<String, dynamic>.from(row as Map),
        progress: progressMap[lessonId] ?? 0,
      );
      return app_errors.Result.success(lesson);
    } on PostgrestException catch (e) {
      await app_errors.ErrorHandler.reportError(e, null, context: 'Fetch lesson by id failed');
      return app_errors.Result.failure('Could not load lesson. ${e.message}');
    } catch (e, stack) {
      await app_errors.ErrorHandler.reportError(e, stack, context: 'Fetch lesson by id error');
      return app_errors.Result.failure('Could not load lesson.');
    }
  }

  /// Upload file to Supabase Storage.
  Future<app_errors.Result<String>> uploadFile(
    String bucket,
    String path,
    Uint8List bytes, {
    String? mimeType,
  }) async {
    try {
      if (currentUser == null) {
        return app_errors.Result.failure('Not authenticated');
      }

      final filePath = '${currentUser!.id}/$path';

      await client.storage.from(bucket).uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              contentType: mimeType,
              upsert: false,
            ),
          );

      final url = client.storage.from(bucket).getPublicUrl(filePath);

      return app_errors.Result.success(url);
    } on StorageException catch (e) {
      await app_errors.ErrorHandler.reportError(e, null, context: 'File upload failed');
      return app_errors.Result.failure('Failed to upload file. Please try again.');
    } catch (e, stack) {
      await app_errors.ErrorHandler.reportError(e, stack, context: 'File upload error');
      return app_errors.Result.failure('An unexpected error occurred.');
    }
  }

  // ========================================================= Teacher & class

  Future<app_errors.Result<List<Lesson>>> fetchTeacherLessons() async {
    try {
      if (currentUser == null) return app_errors.Result.failure('Not authenticated');
      final rows = await client
          .from('lessons')
          .select()
          .eq('author_id', currentUser!.id)
          .order('created_at', ascending: false);
      final lessons = (rows as List)
          .map((row) => LessonMapper.fromRow(Map<String, dynamic>.from(row as Map)))
          .toList();
      return app_errors.Result.success(lessons);
    } catch (e, stack) {
      await app_errors.ErrorHandler.reportError(e, stack, context: 'Fetch teacher lessons');
      return app_errors.Result.failure('Failed to load your lessons.');
    }
  }

  Future<app_errors.Result<TeacherMetrics>> fetchTeacherMetrics() async {
    try {
      if (currentUser == null) return app_errors.Result.failure('Not authenticated');
      final teacherId = currentUser!.id;

      final classRows = await client.from('classes').select('id').eq('teacher_id', teacherId);
      final classIds = (classRows as List).map((r) => r['id'] as String).toList();

      var studentCount = 0;
      if (classIds.isNotEmpty) {
        final members = await client.from('class_members').select('user_id').inFilter('class_id', classIds);
        studentCount = (members as List).length;
      }

      final lessonRows = await client.from('lessons').select('id').eq('author_id', teacherId);
      final lessonCount = (lessonRows as List).length;

      double avgMastery = 0;
      if (classIds.isNotEmpty && studentCount > 0) {
        final memberRows = await client.from('class_members').select('user_id').inFilter('class_id', classIds);
        final studentIds = (memberRows as List).map((r) => r['user_id'] as String).toList();
        if (studentIds.isNotEmpty) {
          final progressRows = await client
              .from('lesson_progress')
              .select('progress')
              .inFilter('user_id', studentIds);
          final values = (progressRows as List).map((r) => (r['progress'] as num).toDouble()).toList();
          if (values.isNotEmpty) {
            avgMastery = values.reduce((a, b) => a + b) / values.length;
          }
        }
      }

      return app_errors.Result.success(TeacherMetrics(
        studentCount: studentCount,
        lessonCount: lessonCount,
        avgMastery: avgMastery,
      ));
    } catch (e, stack) {
      await app_errors.ErrorHandler.reportError(e, stack, context: 'Fetch teacher metrics');
      return app_errors.Result.failure('Failed to load class metrics.');
    }
  }

  Future<app_errors.Result<List<StudentPerformance>>> fetchClassRoster() async {
    try {
      if (currentUser == null) return app_errors.Result.failure('Not authenticated');
      final teacherId = currentUser!.id;

      final classRow = await client.from('classes').select('id').eq('teacher_id', teacherId).limit(1).maybeSingle();
      if (classRow == null) return app_errors.Result.success(const []);

      final classId = classRow['id'] as String;
      final memberRows = await client
          .from('class_members')
          .select('user_id')
          .eq('class_id', classId);

      final roster = <StudentPerformance>[];
      for (final member in memberRows as List) {
        final userId = member['user_id'] as String;
        final profile = await client
            .from('user_profiles')
            .select('display_name, avatar_emoji, lessons_completed')
            .eq('user_id', userId)
            .maybeSingle();
        if (profile == null) continue;

        final progressRows = await client
            .from('lesson_progress')
            .select('progress, updated_at')
            .eq('user_id', userId);

        final progresses = (progressRows as List).map((r) => (r['progress'] as num).toDouble()).toList();
        final mastery = progresses.isEmpty ? 0.0 : progresses.reduce((a, b) => a + b) / progresses.length;

        final subjectRows = await client
            .from('lesson_progress')
            .select('lessons(subject), progress')
            .eq('user_id', userId);

        var bestSubject = 'General';
        var bestProgress = 0.0;
        for (final row in subjectRows as List) {
          final lesson = row['lessons'] as Map?;
          final subject = lesson?['subject'] as String? ?? 'General';
          final p = (row['progress'] as num?)?.toDouble() ?? 0;
          if (p > bestProgress) {
            bestProgress = p;
            bestSubject = subject;
          }
        }

        roster.add(StudentPerformance(
          name: profile['display_name'] as String? ?? 'Student',
          avatarEmoji: profile['avatar_emoji'] as String? ?? '🦊',
          overallMastery: mastery,
          lessonsDone: (profile['lessons_completed'] as num?)?.toInt() ?? 0,
          strength: bestProgress > 0.5 ? bestSubject : 'Getting started',
          growthArea: bestProgress < 0.8 ? 'Practice $bestSubject' : 'New topics',
          weeklyActivity: _weeklyActivityFromProgress(progressRows as List),
        ));
      }

      return app_errors.Result.success(roster);
    } catch (e, stack) {
      await app_errors.ErrorHandler.reportError(e, stack, context: 'Fetch class roster');
      return app_errors.Result.failure('Failed to load students.');
    }
  }

  List<double> _weeklyActivityFromProgress(List rows) {
    final now = DateTime.now();
    final activity = List.filled(7, 0.0);
    for (final row in rows) {
      final updated = row['updated_at'] as String?;
      if (updated == null) continue;
      final date = DateTime.tryParse(updated);
      if (date == null) continue;
      final diff = now.difference(date).inDays;
      if (diff >= 0 && diff < 7) {
        activity[6 - diff] = ((row['progress'] as num?)?.toDouble() ?? 0).clamp(0, 1);
      }
    }
    return activity;
  }

  Future<app_errors.Result<void>> assignLessonToClass(String lessonId) async {
    try {
      if (currentUser == null) return app_errors.Result.failure('Not authenticated');
      final teacherId = currentUser!.id;

      final classRow = await client.from('classes').select('id').eq('teacher_id', teacherId).limit(1).maybeSingle();
      if (classRow == null) {
        return app_errors.Result.failure('Create a class first by adding students in Supabase or use demo accounts.');
      }

      final classId = classRow['id'] as String;
      final members = await client.from('class_members').select('user_id').eq('class_id', classId);
      final memberList = members as List;

      if (memberList.isEmpty) {
        return app_errors.Result.failure('No students in your class yet. Open the Class tab to invite students.');
      }

      var assignedCount = 0;
      for (final member in memberList) {
        final studentId = member['user_id'] as String;
        try {
          await client.from('lesson_assignments').insert({
            'lesson_id': lessonId,
            'user_id': studentId,
            'assigned_by': teacherId,
          });
          assignedCount++;
        } on PostgrestException catch (e) {
          if (e.code == '23505') {
            assignedCount++;
            continue;
          }
          rethrow;
        }
      }

      await client.from('lessons').update({'status': 'assigned'}).eq('id', lessonId);

      if (assignedCount == 0) {
        return app_errors.Result.failure('Could not assign lesson to any students.');
      }

      return app_errors.Result.success(null);
    } catch (e, stack) {
      await app_errors.ErrorHandler.reportError(e, stack, context: 'Assign lesson');
      return app_errors.Result.failure('Failed to assign lesson to class.');
    }
  }

  Future<app_errors.Result<void>> recordUploadedFile({
    required String filename,
    required String storagePath,
    String? mimeType,
    int? fileSize,
  }) async {
    try {
      if (currentUser == null) return app_errors.Result.failure('Not authenticated');
      await client.from('uploaded_files').insert({
        'user_id': currentUser!.id,
        'filename': filename,
        'storage_path': storagePath,
        'mime_type': mimeType,
        'file_size': fileSize,
      });
      return app_errors.Result.success(null);
    } catch (e, stack) {
      await app_errors.ErrorHandler.reportError(e, stack, context: 'Record uploaded file');
      return app_errors.Result.failure('Failed to record upload metadata.');
    }
  }

  // ========================================================= Preferences & goals

  Future<app_errors.Result<UserPreferences>> fetchUserPreferences() async {
    try {
      if (currentUser == null) return app_errors.Result.failure('Not authenticated');
      final row = await client
          .from('user_profiles')
          .select('preferences')
          .eq('user_id', currentUser!.id)
          .maybeSingle();
      final prefs = UserPreferences.fromJson(
        row?['preferences'] != null ? Map<String, dynamic>.from(row!['preferences'] as Map) : null,
      );
      return app_errors.Result.success(prefs);
    } catch (e, stack) {
      await app_errors.ErrorHandler.reportError(e, stack, context: 'Fetch preferences');
      return app_errors.Result.failure('Failed to load settings.');
    }
  }

  Future<app_errors.Result<void>> saveUserPreferences(UserPreferences prefs) async {
    try {
      if (currentUser == null) return app_errors.Result.failure('Not authenticated');
      final existing = await client
          .from('user_profiles')
          .select('preferences')
          .eq('user_id', currentUser!.id)
          .maybeSingle();
      final merged = Map<String, dynamic>.from((existing?['preferences'] as Map?) ?? {});
      merged.addAll(prefs.toJson());
      await client.from('user_profiles').update({
        'preferences': merged,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', currentUser!.id);
      return app_errors.Result.success(null);
    } catch (e, stack) {
      await app_errors.ErrorHandler.reportError(e, stack, context: 'Save preferences');
      return app_errors.Result.failure('Failed to save settings.');
    }
  }

  Future<app_errors.Result<DailyGoalProgress>> fetchDailyGoal() async {
    try {
      if (currentUser == null) return app_errors.Result.failure('Not authenticated');
      final today = DateTime.now().toIso8601String().split('T').first;
      final rows = await client
          .from('lesson_progress')
          .select('slides_completed, updated_at')
          .eq('user_id', currentUser!.id)
          .gte('updated_at', today);

      var completed = 0;
      for (final row in rows as List) {
        completed += (row['slides_completed'] as num?)?.toInt() ?? 0;
      }
      return app_errors.Result.success(DailyGoalProgress(completed: completed.clamp(0, 5), target: 5));
    } catch (e, stack) {
      await app_errors.ErrorHandler.reportError(e, stack, context: 'Fetch daily goal');
      return app_errors.Result.failure('Failed to load daily goal.');
    }
  }

  Future<app_errors.Result<List<SubjectSkill>>> fetchSubjectSkills() async {
    try {
      if (currentUser == null) return app_errors.Result.failure('Not authenticated');
      final rows = await client
          .from('lesson_progress')
          .select('progress, lessons(subject)')
          .eq('user_id', currentUser!.id);

      final bySubject = <String, List<double>>{};
      for (final row in rows as List) {
        final lesson = row['lessons'] as Map?;
        final subject = lesson?['subject'] as String? ?? 'General';
        bySubject.putIfAbsent(subject, () => []).add((row['progress'] as num).toDouble());
      }

      final skills = bySubject.entries
          .map((e) => SubjectSkill(
                subject: e.key,
                mastery: e.value.reduce((a, b) => a + b) / e.value.length,
              ))
          .toList()
        ..sort((a, b) => b.mastery.compareTo(a.mastery));

      return app_errors.Result.success(skills);
    } catch (e, stack) {
      await app_errors.ErrorHandler.reportError(e, stack, context: 'Fetch subject skills');
      return app_errors.Result.failure('Failed to load skills.');
    }
  }

  Future<app_errors.Result<void>> saveSlideProgress(
    String lessonId,
    double progress, {
    required int slideIndex,
    required int totalSlides,
  }) async {
    return updateLessonProgress(
      lessonId,
      progress,
      completed: progress >= 1,
    ).then((r) async {
      if (r.isFailure || currentUser == null) return r;
      await client.from('lesson_progress').update({
        'slides_completed': slideIndex + 1,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', currentUser!.id).eq('lesson_id', lessonId);
      return r;
    });
  }

  // ================================================================= Helpers

  String _parseAuthError(AuthException e) {
    final message = e.message?.toLowerCase() ?? '';

    if (message.contains('invalid') || message.contains('wrong')) {
      return 'Invalid email or password. Please try again.';
    }
    if (message.contains('already registered') || message.contains('already exists')) {
      return 'This email is already registered. Try signing in instead.';
    }
    if (message.contains('weak password')) {
      return 'Password is too weak. Use at least 8 characters.';
    }
    if (message.contains('email')) {
      return 'Please enter a valid email address.';
    }
    if (message.contains('network')) {
      return 'Network error. Please check your connection.';
    }

    return e.message ?? 'Authentication error occurred.';
  }
}

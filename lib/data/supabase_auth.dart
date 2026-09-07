import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../models/models.dart';
import '../models/user_preferences.dart';
import '../services/supabase_service.dart';

/// Real auth backed by Supabase Auth + `user_profiles`.
class SupabaseAuthController extends ChangeNotifier {
  static const _minimumSplashDuration = Duration(milliseconds: 900);
  static const _bootstrapTimeout = Duration(seconds: 3);
  static const _sessionRecoveryTimeout = Duration(seconds: 2);

  bool isLoading = true;
  /// True only for the first launch settle. Sign-in uses [isLoading] without
  /// remounting splash or sending the router back to `/splash`.
  bool isBootstrapping = true;
  bool isAuthenticated = false;
  bool onboardingComplete = false;
  bool profileReady = false;
  String email = '';
  String displayName = '';
  String avatarEmoji = '🦊';
  UserRole? role;
  int level = 1;
  int xp = 0;
  int streakDays = 0;
  int lessonsCompleted = 0;
  int minutesLearned = 0;
  String? lastError;
  StreamSubscription<AuthState>? _authSub;

  SupabaseClient? get _client =>
      SupabaseService.instance.isInitialized ? Supabase.instance.client : null;

  Future<void> bootstrap() async {
    final splashStartedAt = DateTime.now();
    isLoading = true;
    isBootstrapping = true;
    notifyListeners();

    try {
      await _authSub?.cancel();
      _authSub = null;

      final client = _client;
      if (client == null) {
        debugPrint('Auth bootstrap: Supabase client missing');
        _resetSession(keepLoading: true);
        return;
      }

      await _settleSession(client).timeout(_bootstrapTimeout);
    } on TimeoutException {
      debugPrint('Auth bootstrap timed out; continuing as guest if needed');
      if (!isAuthenticated) _resetSession(keepLoading: true);
    } finally {
      if (_authSub == null && _client != null) {
        _authSub = _client!.auth.onAuthStateChange.listen(_onAuthStateChange);
      }
      final elapsed = DateTime.now().difference(splashStartedAt);
      final remaining = _minimumSplashDuration - elapsed;
      if (remaining > Duration.zero) {
        await Future<void>.delayed(remaining);
      }
      isBootstrapping = false;
      isLoading = false;
      debugPrint(
        'Auth bootstrap done: authenticated=$isAuthenticated '
        'onboardingComplete=$onboardingComplete profileReady=$profileReady '
        'role=$role',
      );
      notifyListeners();
    }
  }

  Future<void> _settleSession(SupabaseClient client) async {
    await _awaitSessionRecovery(client);
    final user = client.auth.currentSession?.user ?? client.auth.currentUser;
    if (user != null) {
      try {
        await _applyUser(user);
      } catch (e) {
        debugPrint('Auth bootstrap profile apply failed: $e');
      }
    } else {
      _resetSession(keepLoading: true);
    }
  }

  Future<void> _awaitSessionRecovery(SupabaseClient client) async {
    if (client.auth.currentSession != null) {
      debugPrint('Auth recovery: session already present');
      return;
    }

    final hasPersisted = await _hasPersistedSession();
    debugPrint('Auth recovery: persistedSession=$hasPersisted');
    if (!hasPersisted) return;

    final settled = Completer<void>();
    final sub = client.auth.onAuthStateChange.listen((state) {
      debugPrint(
        'Auth recovery event=${state.event} '
        'hasUser=${state.session?.user != null}',
      );
      if (state.session?.user != null ||
          state.event == AuthChangeEvent.signedOut) {
        if (!settled.isCompleted) settled.complete();
      }
    });

    try {
      if (client.auth.currentSession != null) return;
      await settled.future.timeout(_sessionRecoveryTimeout);
    } on TimeoutException {
      debugPrint(
        'Auth recovery timed out; currentUser=${client.auth.currentUser != null}',
      );
    } finally {
      await sub.cancel();
    }
  }

  Future<bool> _hasPersistedSession() async {
    final url = Env.supabaseUrl;
    if (url.isEmpty) return false;
    try {
      final host = Uri.parse(url).host.split('.').first;
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString('sb-$host-auth-token');
      return value != null && value.isNotEmpty;
    } catch (e) {
      debugPrint('Auth persist check failed: $e');
      return false;
    }
  }

  Future<void> _onAuthStateChange(AuthState state) async {
    debugPrint(
      'Auth event=${state.event} bootstrapping=$isBootstrapping '
      'hasUser=${state.session?.user != null}',
    );

    final user = state.session?.user;
    if (user != null &&
        (state.event == AuthChangeEvent.signedIn ||
            state.event == AuthChangeEvent.initialSession ||
            state.event == AuthChangeEvent.tokenRefreshed ||
            state.event == AuthChangeEvent.userUpdated)) {
      await _applyUser(user);
    } else if (state.event == AuthChangeEvent.signedOut) {
      _resetSession(keepLoading: isBootstrapping);
    }
    if (!isBootstrapping) notifyListeners();
  }

  Future<void> _applyUser(User user) async {
    isAuthenticated = true;
    email = user.email ?? '';
    displayName = user.userMetadata?['display_name'] as String? ?? displayName;
    avatarEmoji = user.userMetadata?['avatar_emoji'] as String? ?? avatarEmoji;
    await _loadProfile(user.id);
  }

  Future<void> _loadProfile(String userId) async {
    final client = _client;
    if (client == null) return;

    try {
      final row = await client
          .from('user_profiles')
          .select(
            'display_name, avatar_emoji, onboarding_complete, role, '
            'level, xp, streak_days, lessons_completed, minutes_learned',
          )
          .eq('user_id', userId)
          .maybeSingle();

      if (row == null) {
        await _ensureProfile(userId);
        return;
      }

      displayName = row['display_name'] as String? ?? displayName;
      avatarEmoji = row['avatar_emoji'] as String? ?? '🦊';
      onboardingComplete = row['onboarding_complete'] as bool? ?? false;
      role = _roleFromDb(row['role'] as String?);
      level = (row['level'] as num?)?.toInt() ?? level;
      xp = (row['xp'] as num?)?.toInt() ?? xp;
      streakDays = (row['streak_days'] as num?)?.toInt() ?? streakDays;
      lessonsCompleted =
          (row['lessons_completed'] as num?)?.toInt() ?? lessonsCompleted;
      minutesLearned =
          (row['minutes_learned'] as num?)?.toInt() ?? minutesLearned;
      profileReady = true;
    } catch (e) {
      profileReady = false;
      debugPrint('Profile load failed: $e');
    }
  }

  Future<void> _ensureProfile(String userId) async {
    final client = _client;
    if (client == null) return;

    final user = client.auth.currentUser;
    final name =
        user?.userMetadata?['display_name'] as String? ??
        (email.isNotEmpty ? email.split('@').first : 'Explorer');

    await SupabaseService.instance.upsertUserProfile({
      'user_id': userId,
      'display_name': name,
      'avatar_emoji': avatarEmoji,
      'onboarding_complete': false,
    });
    onboardingComplete = false;
    profileReady = true;

    // Trigger may have created the row first — reload to pick up DB values.
    final row = await client
        .from('user_profiles')
        .select(
          'display_name, avatar_emoji, onboarding_complete, role, '
          'level, xp, streak_days, lessons_completed, minutes_learned',
        )
        .eq('user_id', userId)
        .maybeSingle();

    if (row != null) {
      displayName = row['display_name'] as String? ?? displayName;
      avatarEmoji = row['avatar_emoji'] as String? ?? avatarEmoji;
      onboardingComplete = row['onboarding_complete'] as bool? ?? false;
      role = _roleFromDb(row['role'] as String?);
      level = (row['level'] as num?)?.toInt() ?? level;
      xp = (row['xp'] as num?)?.toInt() ?? xp;
      streakDays = (row['streak_days'] as num?)?.toInt() ?? streakDays;
      lessonsCompleted =
          (row['lessons_completed'] as num?)?.toInt() ?? lessonsCompleted;
      minutesLearned =
          (row['minutes_learned'] as num?)?.toInt() ?? minutesLearned;
      profileReady = true;
    }
  }

  Future<void> signInWithEmail(String emailInput, String password) async {
    lastError = null;
    isLoading = true;
    notifyListeners();

    final result = await SupabaseService.instance.signIn(emailInput, password);
    isLoading = false;

    if (result.isFailure) {
      lastError = result.error;
      notifyListeners();
      throw Exception(result.error);
    }

    final user = result.data;
    if (user != null) await _applyUser(user);
    notifyListeners();
  }

  Future<void> signUpWithEmail(
    String emailInput,
    String password,
    String name, {
    String? gender,
    int? age,
  }) async {
    lastError = null;
    isLoading = true;
    notifyListeners();

    final result = await SupabaseService.instance.signUp(
      emailInput,
      password,
      name,
      gender: gender,
      age: age,
    );
    isLoading = false;

    if (result.isFailure) {
      lastError = result.error;
      notifyListeners();
      throw Exception(result.error);
    }

    final user = result.data;
    if (user == null) {
      lastError = 'Sign up failed. Please try again.';
      notifyListeners();
      throw Exception(lastError);
    }

    onboardingComplete = false;
    isAuthenticated = true;

    if (_client?.auth.currentSession == null) {
      final signInResult = await SupabaseService.instance.signIn(
        emailInput,
        password,
      );
      if (signInResult.isSuccess && signInResult.data != null) {
        await _applyUser(signInResult.data!);
        await _saveRegistrationDetails(gender: gender, age: age);
        notifyListeners();
        return;
      }
    }

    try {
      await _applyUser(user);
      await _saveRegistrationDetails(gender: gender, age: age);
    } catch (e) {
      debugPrint('Post-signup profile write failed: $e');
    }
    notifyListeners();
  }

  Future<void> _saveRegistrationDetails({String? gender, int? age}) async {
    if (gender == null && age == null) return;
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return;

    Map<String, dynamic>? existingPrefs;
    try {
      final row = await client
          .from('user_profiles')
          .select('preferences')
          .eq('user_id', userId)
          .maybeSingle();
      existingPrefs = row?['preferences'] as Map<String, dynamic>?;
    } catch (_) {}

    final merged = UserPreferences.fromJson(
      existingPrefs,
    ).copyWith(gender: gender, age: age);

    await SupabaseService.instance.upsertUserProfile({
      'user_id': userId,
      'preferences': merged.toJson(),
    });
  }

  Future<void> completeOnboarding({
    required String name,
    required String emoji,
    UserRole? selectedRole,
    bool notify = true,
  }) async {
    displayName = name;
    avatarEmoji = emoji;
    if (selectedRole != null) role = selectedRole;
    onboardingComplete = true;
    profileReady = true;

    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      if (notify) notifyListeners();
      return;
    }

    await SupabaseService.instance.upsertUserProfile({
      'user_id': userId,
      'display_name': name,
      'avatar_emoji': emoji,
      'role': selectedRole?.name,
      'onboarding_complete': true,
      'updated_at': DateTime.now().toIso8601String(),
    });

    if (selectedRole == UserRole.teacher) {
      await SupabaseService.instance.ensureTeacherClass(
        className: '$name\'s Class',
      );
    }

    await client.auth.updateUser(
      UserAttributes(
        data: {
          'display_name': name,
          'avatar_emoji': emoji,
          if (selectedRole != null) 'role': selectedRole.name,
        },
      ),
    );

    if (notify) notifyListeners();
  }

  Future<void> signOut() async {
    isLoading = true;
    notifyListeners();

    if (SupabaseService.instance.isInitialized) {
      await SupabaseService.instance.signOut();
    }

    _resetSession();
    isLoading = false;
    notifyListeners();
  }

  void syncAuth() => notifyListeners();

  Future<void> reloadProfile() async {
    final user = _client?.auth.currentUser;
    if (user != null) await _applyUser(user);
    notifyListeners();
  }

  void _resetSession({bool keepLoading = false}) {
    isAuthenticated = false;
    onboardingComplete = false;
    profileReady = false;
    email = '';
    displayName = '';
    avatarEmoji = '🦊';
    role = null;
    level = 1;
    xp = 0;
    streakDays = 0;
    lessonsCompleted = 0;
    minutesLearned = 0;
    if (!keepLoading) isLoading = false;
  }

  UserRole? _roleFromDb(String? value) {
    if (value == 'teacher') return UserRole.teacher;
    if (value == 'student') return UserRole.student;
    if (value == 'reviewer') return UserRole.reviewer;
    return null;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

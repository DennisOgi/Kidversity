import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';
import 'demo_accounts.dart';

/// Real auth backed by Supabase Auth + `user_profiles`.
class SupabaseAuthController extends ChangeNotifier {
  bool isLoading = true;
  bool isAuthenticated = false;
  bool onboardingComplete = false;
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
  bool _localDemo = false;

  bool get isLocalDemo => _localDemo;

  StreamSubscription<AuthState>? _authSub;

  SupabaseClient? get _client =>
      SupabaseService.instance.isInitialized ? Supabase.instance.client : null;

  Future<void> bootstrap() async {
    isLoading = true;
    notifyListeners();

    try {
      await _authSub?.cancel();
      _authSub = null;

      final client = _client;
      if (client == null) {
        _resetSession();
        return;
      }

      _authSub = client.auth.onAuthStateChange.listen(_onAuthStateChange);

      final user = client.auth.currentUser;
      if (user != null) {
        await _applyUser(user);
      } else {
        _resetSession(keepLoading: true);
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _onAuthStateChange(AuthState state) async {
    final user = state.session?.user;
    if (user != null &&
        (state.event == AuthChangeEvent.signedIn ||
            state.event == AuthChangeEvent.initialSession ||
            state.event == AuthChangeEvent.tokenRefreshed ||
            state.event == AuthChangeEvent.userUpdated)) {
      await _applyUser(user);
    } else if (state.event == AuthChangeEvent.signedOut) {
      _resetSession();
    }
    notifyListeners();
  }

  Future<void> _applyUser(User user) async {
    _localDemo = false;
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
      lessonsCompleted = (row['lessons_completed'] as num?)?.toInt() ?? lessonsCompleted;
      minutesLearned = (row['minutes_learned'] as num?)?.toInt() ?? minutesLearned;
    } catch (e) {
      debugPrint('Profile load failed: $e');
    }
  }

  Future<void> _ensureProfile(String userId) async {
    final client = _client;
    if (client == null) return;

    final user = client.auth.currentUser;
    final name = user?.userMetadata?['display_name'] as String? ??
        (email.isNotEmpty ? email.split('@').first : 'Explorer');

    await client.from('user_profiles').upsert({
      'user_id': userId,
      'display_name': name,
      'avatar_emoji': avatarEmoji,
      'onboarding_complete': false,
    });
    onboardingComplete = false;
  }

  Future<void> signInDemoAccount(DemoAccount account) async {
    lastError = null;

    if (_client == null) {
      _applyLocalDemoSession(account);
      notifyListeners();
      return;
    }

    isLoading = true;
    notifyListeners();

    try {
      final signedIn = await _trySupabaseDemo(account);
      if (!signedIn) {
        lastError ??= 'Demo sign-in failed. Please try again or use Sign in with the credentials below.';
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> _trySupabaseDemo(DemoAccount account) async {
    final service = SupabaseService.instance;

    var result = await service.signIn(account.email, account.password);
    if (result.isFailure) {
      result = await service.signUp(account.email, account.password, account.displayName);
      if (result.isFailure) {
        lastError = result.error;
        return false;
      }

      if (_client?.auth.currentSession == null) {
        final retry = await service.signIn(account.email, account.password);
        if (retry.isFailure) {
          lastError = retry.error ?? 'Demo account created but sign-in failed.';
          return false;
        }
      }
    }

    final user = result.data ?? _client?.auth.currentUser;
    if (user == null) {
      lastError = 'Could not establish a session. Please try again.';
      return false;
    }

    await _applyUser(user);

    if (!onboardingComplete) {
      try {
        await completeOnboarding(
          name: account.displayName,
          emoji: account.avatarEmoji,
          selectedRole: account.role,
        );
      } catch (e) {
        debugPrint('Demo onboarding failed: $e');
      }
    }

    role ??= account.role;
    await _upsertDemoStats(account);
    _applyDemoStats(account);
    _localDemo = false;
    lastError = null;
    return true;
  }

  Future<void> _upsertDemoStats(DemoAccount account) async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return;

    try {
      await client.from('user_profiles').upsert({
        'user_id': userId,
        'display_name': account.displayName,
        'avatar_emoji': account.avatarEmoji,
        'role': account.role.name,
        'onboarding_complete': true,
        'level': account.level,
        'xp': account.xp,
        'streak_days': account.streakDays,
        'lessons_completed': account.lessonsCompleted,
        'minutes_learned': account.minutesLearned,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Demo stats upsert failed: $e');
    }
  }

  void _applyLocalDemoSession(DemoAccount account) {
    _localDemo = true;
    isAuthenticated = true;
    onboardingComplete = true;
    email = account.email;
    displayName = account.displayName;
    avatarEmoji = account.avatarEmoji;
    role = account.role;
    _applyDemoStats(account);
    lastError = null;
  }

  void _applyDemoStats(DemoAccount account) {
    level = account.level;
    xp = account.xp;
    streakDays = account.streakDays;
    lessonsCompleted = account.lessonsCompleted;
    minutesLearned = account.minutesLearned;
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

  Future<void> signUpWithEmail(String emailInput, String password, String name) async {
    lastError = null;
    isLoading = true;
    notifyListeners();

    final result = await SupabaseService.instance.signUp(emailInput, password, name);
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

    // Email confirmation disabled — sign in immediately when signup returns no session.
    if (_client?.auth.currentSession == null) {
      final signInResult = await SupabaseService.instance.signIn(emailInput, password);
      if (signInResult.isSuccess && signInResult.data != null) {
        await _applyUser(signInResult.data!);
        notifyListeners();
        return;
      }

      lastError = 'Account created but sign-in failed. Please sign in manually.';
      isAuthenticated = false;
      notifyListeners();
      throw Exception(lastError);
    }

    await _applyUser(user);
    notifyListeners();
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

    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      if (notify) notifyListeners();
      return;
    }

    await client.from('user_profiles').upsert({
      'user_id': userId,
      'display_name': name,
      'avatar_emoji': emoji,
      'role': selectedRole?.name,
      'onboarding_complete': true,
      'updated_at': DateTime.now().toIso8601String(),
    });

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

    if (_localDemo) {
      _localDemo = false;
    } else if (SupabaseService.instance.isInitialized) {
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
    _localDemo = false;
    isAuthenticated = false;
    onboardingComplete = false;
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
    return null;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

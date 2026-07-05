import 'package:shared_preferences/shared_preferences.dart';

/// Persists sign-in email when the user opts in to "Remember me".
class AuthRememberMe {
  AuthRememberMe._();

  static const _rememberKey = 'auth_remember_me';
  static const _emailKey = 'auth_remember_email';

  static Future<({bool enabled, String? email})> load() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_rememberKey) ?? false;
    final email = enabled ? prefs.getString(_emailKey) : null;
    return (enabled: enabled, email: email?.trim().isEmpty == true ? null : email);
  }

  static Future<void> save({required bool enabled, required String email}) async {
    final prefs = await SharedPreferences.getInstance();
    if (enabled) {
      await prefs.setBool(_rememberKey, true);
      await prefs.setString(_emailKey, email.trim());
    } else {
      await clear();
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rememberKey);
    await prefs.remove(_emailKey);
  }
}

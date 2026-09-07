import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration — reads `.env` (dev) or `--dart-define` (CI/prod).
class Env {
  static bool _dotenvLoaded = false;

  // Compile-time fallbacks (--dart-define). Must be const.
  static const _defineSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _defineSupabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const _defineSupabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
  static const _defineSentryDsn = String.fromEnvironment('SENTRY_DSN');
  static const _defineEnvironment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );
  static const _defineRelease = String.fromEnvironment(
    'APP_RELEASE',
    defaultValue: 'local',
  );
  static const _defineApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );
  static const _defineApiTimeoutSeconds = String.fromEnvironment(
    'API_TIMEOUT_SECONDS',
    defaultValue: '30',
  );

  /// Load `.env` from assets. Safe to call multiple times.
  static Future<void> load() async {
    if (_dotenvLoaded) return;
    try {
      await dotenv.load(fileName: '.env');
      _dotenvLoaded = true;
    } catch (_) {
      // .env is optional when using --dart-define.
    }
  }

  static String _read(String key, String compileTimeFallback) {
    final fromDotenv = dotenv.maybeGet(key);
    if (fromDotenv != null && fromDotenv.isNotEmpty) return fromDotenv;
    if (compileTimeFallback.isNotEmpty) return compileTimeFallback;
    return '';
  }

  static String get supabaseUrl => _read('SUPABASE_URL', _defineSupabaseUrl);
  static String get supabasePublishableKey {
    final modern = _read(
      'SUPABASE_PUBLISHABLE_KEY',
      _defineSupabasePublishableKey,
    );
    if (modern.isNotEmpty) return modern;
    return _read('SUPABASE_ANON_KEY', _defineSupabaseAnonKey);
  }

  static String get sentryDsn => _read('SENTRY_DSN', _defineSentryDsn);
  static String get environment => _read('ENVIRONMENT', _defineEnvironment);
  static String get release => _read('APP_RELEASE', _defineRelease);
  static String get apiBaseUrl => _read('API_BASE_URL', _defineApiBaseUrl);
  static int get apiTimeoutSeconds =>
      int.tryParse(_read('API_TIMEOUT_SECONDS', _defineApiTimeoutSeconds)) ??
      30;

  static bool get isDevelopment => environment == 'development';
  static bool get isProduction => environment == 'production';
  static bool get isStaging => environment == 'staging';

  static bool get hasSupabase {
    final url = supabaseUrl.trim();
    final key = supabasePublishableKey.trim();
    if (url.isEmpty || key.isEmpty) {
      return false;
    }
    if (url.contains('YOUR_PROJECT') || url.contains('your_supabase')) {
      return false;
    }
    if (key.contains('your_publishable') || key.contains('your_supabase')) {
      return false;
    }
    return true;
  }

  static void validate() {
    final missing = <String>[];
    if (supabaseUrl.isEmpty) {
      missing.add('SUPABASE_URL');
    }
    if (supabasePublishableKey.isEmpty) {
      missing.add('SUPABASE_PUBLISHABLE_KEY');
    }

    if (missing.isNotEmpty) {
      throw Exception(
        'Missing required environment variables: ${missing.join(', ')}\n'
        'Copy .env.example to .env and fill in your Supabase project URL and publishable key,\n'
        'or pass --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...',
      );
    }

    if (sentryDsn.isEmpty && isProduction) {
      // ignore: avoid_print
      print('WARNING: SENTRY_DSN not set. Error tracking disabled.');
    }
  }
}

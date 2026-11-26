/// Build-time settings. Pass real values with --dart-define in CI:
///   flutter build web --base-href /ace/ \
///     --dart-define=ACE_SUPABASE_URL=... --dart-define=ACE_SUPABASE_KEY=...
/// The defaults point at the ACE staging project. The key is the publishable
/// (browser-safe) key; it only grants what the database's own rules allow.
abstract final class AceConfig {
  static const supabaseUrl = String.fromEnvironment(
    'ACE_SUPABASE_URL',
    defaultValue: 'https://nzcmezjhgcdhfxqbnhgv.supabase.co',
  );
  static const supabaseKey = String.fromEnvironment(
    'ACE_SUPABASE_KEY',
    defaultValue: 'sb_publishable_ect3TqTeatStHpvMRyF7Iw_xR9dyaMy',
  );

  /// 'staging' shows a banner so nobody mistakes draft content for released.
  static const environment = String.fromEnvironment(
    'ACE_ENV',
    defaultValue: 'staging',
  );
}

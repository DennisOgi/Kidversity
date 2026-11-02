/// Product switches. Flip at build time, e.g.
/// `flutter build web --dart-define=PAYMENTS_ENABLED=true`.
abstract final class Features {
  /// Lesson packs, prices, and checkout. While this is off every lesson is
  /// open, nothing mentions prices, and the server does not enforce packs
  /// (see `private.app_settings.payments_enabled`).
  static const payments = bool.fromEnvironment('PAYMENTS_ENABLED');
}

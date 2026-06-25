import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'supabase_auth.dart';

/// Supabase-backed auth session — drives router redirects and auth UI.
final authControllerProvider = ChangeNotifierProvider<SupabaseAuthController>((ref) {
  final c = SupabaseAuthController();
  c.bootstrap();
  return c;
});

extension AuthControllerRef on WidgetRef {
  SupabaseAuthController get auth => read(authControllerProvider);
}

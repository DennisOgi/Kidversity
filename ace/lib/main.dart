import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'screens/channel_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lesson_screen.dart';
import 'screens/sign_in_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Clean URLs under the /ace/ base href (e.g. /ace/c/as-mathematics).
  usePathUrlStrategy();
  await Supabase.initialize(
    url: AceConfig.supabaseUrl,
    publishableKey: AceConfig.supabaseKey,
  );
  runApp(const AceApp());
}

/// Rebuilds routing when the user signs in or out.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable() {
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen(
      (_) => notifyListeners(),
    );
  }

  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final _auth = _AuthListenable();

final _router = GoRouter(
  refreshListenable: _auth,
  redirect: (context, state) {
    final signedIn = Supabase.instance.client.auth.currentSession != null;
    final atSignIn = state.matchedLocation == '/sign-in';
    if (!signedIn && !atSignIn) return '/sign-in';
    if (signedIn && atSignIn) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
    GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
    GoRoute(
      path: '/c/:id',
      builder: (_, s) => ChannelScreen(
        key: ValueKey(s.pathParameters['id']),
        channelId: s.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/l/:id',
      builder: (_, s) => LessonScreen(
        key: ValueKey(s.pathParameters['id']),
        lessonId: s.pathParameters['id']!,
      ),
    ),
  ],
);

class AceApp extends StatelessWidget {
  const AceApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      SystemChrome.setApplicationSwitcherDescription(
        const ApplicationSwitcherDescription(
          label: 'ACE · Advance. Conquer. Excel.',
        ),
      );
    }
    return MaterialApp.router(
      title: 'ACE',
      debugShowCheckedModeBanner: false,
      theme: Ace.theme(),
      routerConfig: _router,
    );
  }
}

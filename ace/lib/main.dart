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
import 'screens/landing_screen.dart';
import 'screens/lesson_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Clean URLs under the /ace/ base href (e.g. /ace/c/as-mathematics).
  usePathUrlStrategy();
  // Keep the address bar in step with pushed pages, so links are shareable
  // and the browser back button walks back through the pages you opened.
  GoRouter.optionURLReflectsImperativeAPIs = true;
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

const _public = {'/welcome', '/sign-in'};

final _router = GoRouter(
  refreshListenable: _auth,
  redirect: (context, state) {
    final signedIn = Supabase.instance.client.auth.currentSession != null;
    final path = state.matchedLocation;
    if (!signedIn && !_public.contains(path)) return '/welcome';
    if (signedIn && _public.contains(path)) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
    GoRoute(path: '/welcome', builder: (_, _) => const LandingScreen()),
    GoRoute(
      path: '/sign-in',
      builder: (_, s) => SignInScreen(
        key: ValueKey(s.uri.queryParameters['create']),
        startCreate: s.uri.queryParameters['create'] == '1',
      ),
    ),
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

class AceApp extends StatefulWidget {
  const AceApp({super.key});

  @override
  State<AceApp> createState() => _AceAppState();
}

class _AceAppState extends State<AceApp> {
  bool _splash = true;

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
      builder: (context, child) => Stack(
        children: [
          ?child,
          if (_splash)
            Positioned.fill(
              child: SplashOverlay(
                onDone: () => setState(() => _splash = false),
              ),
            ),
        ],
      ),
    );
  }
}

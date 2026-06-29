import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'config/env.dart';
import 'core/error_handler.dart';
import 'router/app_router.dart';
import 'services/supabase_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await Env.load();
      usePathUrlStrategy();
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      );

    await _initializeApp();

    if (kDebugMode) {
      debugPrint(Env.hasSupabase
          ? '✅ Supabase credentials loaded from .env / dart-define'
          : '⚠️ Supabase credentials missing — check .env is in pubspec assets');
    }

    FlutterError.onError = (details) {
        FlutterError.presentError(details);
        ErrorHandler.reportError(
          details.exception,
          details.stack,
          context: 'Flutter framework error',
        );
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        ErrorHandler.reportError(error, stack, context: 'Platform error');
        return true;
      };

      ErrorWidget.builder = (details) {
        return Material(
          color: AppColors.background,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                details.exceptionAsString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger, fontSize: 14),
              ),
            ),
          ),
        );
      };

      runApp(const ProviderScope(child: KidversityApp()));
    },
    (error, stack) {
      ErrorHandler.reportError(error, stack, context: 'Uncaught error');
    },
  );
}

Future<void> _initializeApp() async {
  try {
    if (!Env.hasSupabase) {
      if (kDebugMode) {
        debugPrint('⚠️ Supabase credentials missing. Auth will not work until .env is configured.');
      } else {
        Env.validate();
      }
      return;
    }

    Env.validate();
    await ErrorHandler.initialize();
    await SupabaseService.instance.initialize();
    debugPrint('✅ Supabase initialized');
  } catch (e, stack) {
    debugPrint('❌ App initialization failed: $e');
    await ErrorHandler.reportError(e, stack, context: 'App initialization error');
  }
}

class KidversityApp extends ConsumerWidget {
  const KidversityApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Kidversity',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}

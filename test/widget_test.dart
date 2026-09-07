import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kidversity/data/auth_state.dart';
import 'package:kidversity/data/supabase_auth.dart';
import 'package:kidversity/features/auth/auth_screen.dart';
import 'package:kidversity/features/onboarding/onboarding_screen.dart';
import 'package:kidversity/features/shell/app_shell.dart';
import 'package:kidversity/features/splash/splash_screen.dart';
import 'package:kidversity/theme/app_theme.dart';

void main() {
  testWidgets('Plan B splash presents Mandarin Foundation identity', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SplashScreen())),
    );
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('MANDARIN FOUNDATION'), findsOneWidget);
    expect(find.text('A clear first path into Mandarin'), findsOneWidget);
  });

  testWidgets('Onboarding presents animated Mandarin journey setup', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) {
            final controller = SupabaseAuthController();
            controller.isLoading = false;
            return controller;
          }),
        ],
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to the path'), findsOneWidget);
    expect(find.text('MANDARIN FOUNDATION'), findsWidgets);
    expect(find.text('Continue'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Amina');
    await tester.pump();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text("I'm a Student"), findsOneWidget);
    expect(find.text("I'm a Teacher or Parent"), findsOneWidget);
    expect(find.text("I'm a Reviewer"), findsNothing);
  });

  testWidgets('Auth screen shows sign-in tabs', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) {
            final c = SupabaseAuthController();
            c.isLoading = false;
            return c;
          }),
        ],
        child: const MaterialApp(home: AuthScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text('Try the demo'), findsNothing);
  });

  testWidgets('AppShell bottom nav renders rounded pill container', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) {
            final c = SupabaseAuthController();
            c.isLoading = false;
            c.isAuthenticated = true;
            c.onboardingComplete = true;
            c.displayName = 'Chioma';
            return c;
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const AppShell(
            currentPath: '/student/path',
            items: [
              NavItem(
                Icons.route_outlined,
                Icons.route_rounded,
                'Path',
                '/student/path',
              ),
              NavItem(
                Icons.school_outlined,
                Icons.school_rounded,
                'Practice',
                '/student/practice',
              ),
            ],
            child: SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pump();

    final pill = tester.renderObject<RenderBox>(
      find.byKey(const Key('bottomNavPill')),
    );
    expect(pill.size.width, greaterThan(200));
    expect(pill.size.height, greaterThan(40));

    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}

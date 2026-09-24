import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kidversity/data/auth_state.dart';
import 'package:kidversity/data/supabase_auth.dart';
import 'package:kidversity/features/auth/auth_screen.dart';
import 'package:kidversity/features/onboarding/onboarding_screen.dart';
import 'package:kidversity/features/teacher/teacher_live_compose_screen.dart';
import 'package:kidversity/features/shell/app_shell.dart';
import 'package:kidversity/features/splash/splash_screen.dart';
import 'package:kidversity/theme/app_theme.dart';
import 'package:kidversity/widgets/common.dart';

void main() {
  testWidgets('Splash presents the Kidversity doorway mark', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light, home: const SplashScreen()),
      ),
    );
    await tester.pump();

    expect(find.bySemanticsLabel('Kidversity'), findsOneWidget);
    expect(find.byType(KidversityMark), findsOneWidget);
    expect(find.text('Opening your learning home'), findsNothing);
  });

  testWidgets('Onboarding presents animated Kidversity journey setup', (
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

    expect(find.text('Welcome to Kidversity'), findsOneWidget);
    expect(find.text('KIDVERSITY'), findsWidgets);
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
    expect(find.text('Mandarin, exams, labs, maths, and Rope Pull'), findsOneWidget);
    expect(find.text("I'm a Teacher or Parent"), findsOneWidget);
    expect(
      find.text('Set work, follow the class, and run a live quiz'),
      findsOneWidget,
    );
    expect(find.text("I'm a Reviewer"), findsNothing);

    await tester.tap(find.text("I'm a Student"));
    await tester.pump();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('How learning works here'), findsOneWidget);
    expect(find.text('Labs and mental maths'), findsOneWidget);
    expect(find.text('Rope Pull and word review'), findsOneWidget);
  });

  testWidgets('teacher onboarding explains a quiz of any length', (
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

    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.pump();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text("I'm a Teacher or Parent"));
    await tester.tap(find.text("I'm a Teacher or Parent"));
    await tester.pump();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Your class workspace'), findsOneWidget);
    expect(find.text('Live quiz'), findsOneWidget);
    expect(find.textContaining('as many questions as you want'), findsOneWidget);
    expect(find.text('Assign'), findsOneWidget);
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
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

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
  });

  testWidgets('a live quiz can grow past a fixed question count', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: TeacherLiveComposeScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('1 question'), findsOneWidget);
    expect(find.text('Write the questions'), findsOneWidget);

    for (var i = 0; i < 11; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, 4000));
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Add question'));
      await tester.pump();
    }

    expect(find.text('12 questions'), findsOneWidget);

    final goLive = find.text('Go live');
    for (var i = 0; goLive.hitTestable().evaluate().isEmpty && i < 40; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();
    }
    await tester.tap(goLive);
    await tester.pump();
    expect(find.text('Give the quiz a title.'), findsOneWidget);
  });
}
